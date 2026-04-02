@testable import Cookey
import Foundation
import Testing

struct LogStoreTests {
    @Test("LogStore appends readable lines")
    func appendsReadableLines() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = LogStore(
            directory: directory,
            fileManager: .default,
            maxFileSize: 1024,
            maxFiles: 2,
            fileName: "CookeyTests.log"
        )

        store.append(level: .info, category: "Test", message: "hello")
        store.flush()

        let text = store.readTail()
        #expect(text.contains("[INFO] [Test] hello"))
    }

    @Test("LogStore clear removes current log contents")
    func clearRemovesLogContents() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = LogStore(
            directory: directory,
            fileManager: .default,
            maxFileSize: 1024,
            maxFiles: 2,
            fileName: "CookeyTests.log"
        )

        store.append(level: .error, category: "Test", message: "boom")
        store.flush()
        #expect(!store.readTail().isEmpty)

        store.clear()
        #expect(store.readTail().isEmpty)
    }
}
