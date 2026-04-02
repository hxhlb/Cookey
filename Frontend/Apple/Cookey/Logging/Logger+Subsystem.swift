@_exported import Foundation
@_exported import OSLog

nonisolated extension Logger {
    nonisolated static let loggingSubsystem: String = {
        if let identifier = Bundle.main.bundleIdentifier, !identifier.isEmpty {
            return identifier
        }
        return ProcessInfo.processInfo.processName
    }()

    nonisolated static let app = Logger(subsystem: loggingSubsystem, category: "App")
    nonisolated static let ui = Logger(subsystem: loggingSubsystem, category: "UI")
    nonisolated static let network = Logger(subsystem: loggingSubsystem, category: "Network")
    nonisolated static let model = Logger(subsystem: loggingSubsystem, category: "Model")
    nonisolated static let push = Logger(subsystem: loggingSubsystem, category: "Push")
    nonisolated static let browser = Logger(subsystem: loggingSubsystem, category: "Browser")
    nonisolated static let crypto = Logger(subsystem: loggingSubsystem, category: "Crypto")
}
