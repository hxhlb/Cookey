import Foundation
import OSLog

private enum LogCategoryResolver {
    static func resolve(category: String?, fileID: String) -> String {
        if let category, !category.isEmpty { return category }

        let lowercased = fileID.lowercased()
        if lowercased.contains("network") || lowercased.contains("relayclient") {
            return "Network"
        }
        if lowercased.contains("push") || lowercased.contains("notification") {
            return "Push"
        }
        if lowercased.contains("browser") {
            return "Browser"
        }
        if lowercased.contains("model") || lowercased.contains("deeplink") {
            return "Model"
        }
        if lowercased.contains("view") || lowercased.contains("controller") || lowercased.contains("scene") {
            return "UI"
        }
        return "App"
    }
}

extension Logger {
    func debugFile(_ message: String, category: String? = nil, fileID: String = #fileID) {
        logToFile(.debug, message, category: category, fileID: fileID)
    }

    func infoFile(_ message: String, category: String? = nil, fileID: String = #fileID) {
        logToFile(.info, message, category: category, fileID: fileID)
    }

    func errorFile(_ message: String, category: String? = nil, fileID: String = #fileID) {
        logToFile(.error, message, category: category, fileID: fileID)
    }

    private func logToFile(_ level: LogLevel, _ message: String, category: String?, fileID: String) {
        log(level: level.osLogType, "\(message, privacy: .public)")
        let resolvedCategory = LogCategoryResolver.resolve(category: category, fileID: fileID)
        LogStore.shared.append(level: level, category: resolvedCategory, message: message)
    }
}

private extension LogLevel {
    var osLogType: OSLogType {
        switch self {
        case .debug:
            .debug
        case .info:
            .info
        case .error:
            .error
        }
    }
}
