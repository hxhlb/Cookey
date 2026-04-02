@_exported import Foundation
@_exported import OSLog

extension Logger {
    static let loggingSubsystem: String = {
        if let identifier = Bundle.main.bundleIdentifier, !identifier.isEmpty {
            return identifier
        }
        return ProcessInfo.processInfo.processName
    }()

    static let app = Logger(subsystem: loggingSubsystem, category: "App")
    static let ui = Logger(subsystem: loggingSubsystem, category: "UI")
    static let network = Logger(subsystem: loggingSubsystem, category: "Network")
    static let model = Logger(subsystem: loggingSubsystem, category: "Model")
    static let push = Logger(subsystem: loggingSubsystem, category: "Push")
    static let browser = Logger(subsystem: loggingSubsystem, category: "Browser")
    static let crypto = Logger(subsystem: loggingSubsystem, category: "Crypto")
}
