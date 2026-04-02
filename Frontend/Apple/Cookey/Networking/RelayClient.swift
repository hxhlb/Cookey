import Foundation

struct RelayClient {
    let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let session: URLSession
    private let requestExecutor: (@Sendable (URLRequest) throws -> (Data, URLResponse))?

    init(
        baseURL: URL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        requestExecutor = nil
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    init(
        baseURL: URL,
        session: URLSession = .shared,
        requestExecutor: @escaping @Sendable (URLRequest) throws -> (Data, URLResponse)
    ) {
        self.baseURL = baseURL
        self.session = session
        self.requestExecutor = requestExecutor
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    func healthCheck() async throws -> HealthCheckResult {
        let endpoint = baseURL.appending(path: "health")
        Logger.network.debugFile("GET \(endpoint.absoluteString)")
        let (data, response) = try await session.data(from: endpoint)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        Logger.network.infoFile("Health check completed with status \(httpResponse.statusCode)")

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "Cookey.RelayClient",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Unexpected status code \(httpResponse.statusCode)"]
            )
        }

        return HealthCheckResult(
            body: String(decoding: data, as: UTF8.self),
            serverName: httpResponse.value(forHTTPHeaderField: "Server") ?? "unknown",
            checkedAt: Date()
        )
    }

    func uploadSession(rid: String, envelope: EncryptedSessionEnvelope) async throws {
        let endpoint = baseURL.appending(path: "v1/requests/\(rid)/session")
        Logger.network.infoFile("Uploading session for rid \(rid) to \(endpoint.host() ?? endpoint.absoluteString)")
        _ = try await sendRequest(to: endpoint, method: "POST", body: envelope)
    }

    func fetchRequestStatus(rid: String) async throws -> RequestStatusResponse {
        let endpoint = baseURL.appending(path: "v1/requests/\(rid)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        Logger.network.debugFile("Fetching request status for rid \(rid)")

        let (data, response) = try await perform(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        Logger.network.infoFile("Request status for rid \(rid) returned HTTP \(httpResponse.statusCode)")

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(decoding: data, as: UTF8.self)
            throw NSError(
                domain: "Cookey.RelayClient",
                code: httpResponse.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: "Unexpected status code \(httpResponse.statusCode): \(body)",
                ]
            )
        }

        return try decoder.decode(RequestStatusResponse.self, from: data)
    }

    func fetchSeedSession(rid: String) async throws -> EncryptedSessionEnvelope? {
        let endpoint = baseURL.appending(path: "v1/requests/\(rid)/seed-session")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        Logger.network.infoFile("Fetching seed session for rid \(rid)")

        let (data, response) = try await perform(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        Logger.network.infoFile("Seed session fetch for rid \(rid) returned HTTP \(httpResponse.statusCode) with \(data.count) bytes")

        switch httpResponse.statusCode {
        case 404:
            Logger.network.debugFile("No seed session found for rid \(rid)")
            return nil
        case 200 ..< 300:
            return try decoder.decode(EncryptedSessionEnvelope.self, from: data)
        default:
            let body = String(decoding: data, as: UTF8.self)
            throw NSError(
                domain: "Cookey.RelayClient",
                code: httpResponse.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: "Unexpected status code \(httpResponse.statusCode): \(body)",
                ]
            )
        }
    }

    @discardableResult
    private func sendRequest(
        to url: URL,
        method: String,
        body: (some Encodable)?
    ) async throws -> HTTPURLResponse {
        var request = URLRequest(url: url)
        request.httpMethod = method
        Logger.network.debugFile("\(method) \(url.absoluteString)")
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            Logger.network.debugFile("\(method) \(url.lastPathComponent) request body size \(request.httpBody?.count ?? 0) bytes")
        }

        let (data, response) = try await perform(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        Logger.network.infoFile("\(method) \(url.lastPathComponent) returned HTTP \(httpResponse.statusCode)")

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(decoding: data, as: UTF8.self)
            throw NSError(
                domain: "Cookey.RelayClient",
                code: httpResponse.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: "Unexpected status code \(httpResponse.statusCode): \(body)",
                ]
            )
        }

        return httpResponse
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        if let requestExecutor {
            Logger.network.debugFile("Executing request for \(request.url?.absoluteString ?? "<unknown>") via injected executor")
            return try requestExecutor(request)
        }
        Logger.network.debugFile("Executing request for \(request.url?.absoluteString ?? "<unknown>") via URLSession")
        return try await RelayClient.performRequest(request, with: session)
    }

    private static func performRequest(
        _ request: URLRequest,
        with session: URLSession
    ) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}
