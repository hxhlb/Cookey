import Combine
import Foundation

@MainActor
final class HealthCheckModel: ObservableObject {
    enum Status {
        case idle
        case checking
        case healthy(HealthCheckResult)
        case failed(String)
    }

    private let client: RelayClient

    init() {
        client = RelayClient(baseURL: AppEnvironment.effectiveAPIBaseURL)
    }

    init(client: RelayClient) {
        self.client = client
    }

    @Published var status: Status = .idle

    func refresh() async {
        status = .checking

        do {
            status = try await .healthy(client.healthCheck())
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}
