import Foundation

struct RelayClient {
    let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let session: URLSession
    private let requestExecutor: (@Sendable (URLRequest) throws -> (Data, URLResponse))?

    init(
        baseURL: URL,
        session: URLSession = .shared,
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
        requestExecutor: @escaping @Sendable (URLRequest) throws -> (Data, URLResponse),
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
                userInfo: [NSLocalizedDescriptionKey: "Unexpected status code \(httpResponse.statusCode)"],
            )
        }

        return HealthCheckResult(
            body: String(decoding: data, as: UTF8.self),
            serverName: httpResponse.value(forHTTPHeaderField: "Server") ?? "unknown",
            checkedAt: Date(),
        )
    }

    func uploadSession(rid: String, envelope: EncryptedSessionEnvelope) async throws {
        let endpoint = baseURL.appending(path: "v1/requests/\(rid)/session")
        Logger.network.infoFile("Uploading session for rid \(rid) to \(endpoint.host() ?? endpoint.absoluteString)")
        _ = try await sendRequest(to: endpoint, method: "POST", body: envelope)
    }

    func resolvePairKey(_ pairKey: String) async throws -> PairKeyResolveResponse {
        Logger.network.infoFile("Resolving pair key \(pairKey)")
        let result: PairKeyResolveResponse = try await performGET("v1/pair/\(pairKey)")
        Logger.network.infoFile("Pair key resolve succeeded for \(pairKey)")
        return result
    }

    func fetchRequestStatus(rid: String) async throws -> RequestStatusResponse {
        Logger.network.debugFile("Fetching request status for rid \(rid)")
        let result: RequestStatusResponse = try await performGET("v1/requests/\(rid)")
        Logger.network.infoFile("Request status for rid \(rid) fetched successfully")
        return result
    }

    func fetchSeedSession(rid: String) async throws -> EncryptedSessionEnvelope? {
        Logger.network.infoFile("Fetching seed session for rid \(rid)")
        let (data, httpResponse) = try await performGETRaw("v1/requests/\(rid)/seed-session")
        Logger.network.infoFile("Seed session fetch for rid \(rid) returned HTTP \(httpResponse.statusCode) with \(data.count) bytes")

        switch httpResponse.statusCode {
        case 404:
            Logger.network.debugFile("No seed session found for rid \(rid)")
            return nil
        case 200 ..< 300:
            return try decoder.decode(EncryptedSessionEnvelope.self, from: data)
        default:
            throw relayError(httpResponse.statusCode, data: data)
        }
    }

    @discardableResult
    private func sendRequest(
        to url: URL,
        method: String,
        body: (some Encodable)?,
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
            throw relayError(httpResponse.statusCode, data: data)
        }

        return httpResponse
    }

    private func performGET<T: Decodable>(_ path: String) async throws -> T {
        let (data, httpResponse) = try await performGETRaw(path)
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw relayError(httpResponse.statusCode, data: data)
        }
        return try decoder.decode(T.self, from: data)
    }

    private func performGETRaw(_ path: String) async throws -> (Data, HTTPURLResponse) {
        let endpoint = baseURL.appending(path: path)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        let (data, response) = try await perform(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, httpResponse)
    }

    private func relayError(_ statusCode: Int, data: Data) -> NSError {
        let body = String(decoding: data, as: UTF8.self)
        return NSError(
            domain: "Cookey.RelayClient",
            code: statusCode,
            userInfo: [NSLocalizedDescriptionKey: "Unexpected status code \(statusCode): \(body)"],
        )
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
        with session: URLSession,
    ) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}
