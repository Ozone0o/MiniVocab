import XCTest
@testable import MiniVocab

final class TXTImporterTests: XCTestCase {

    private var tempDir: URL!
    private var importer: TXTImporter!

    override func setUp() {
        super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("MiniVocab TXT Tests")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        importer = TXTImporter()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func writeTestFile(name: String, content: String) throws {
        let url = tempDir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func testCanImportTXT() {
        XCTAssertTrue(importer.canImport(fileURL: URL(fileURLWithPath: "data.txt")))
        XCTAssertFalse(importer.canImport(fileURL: URL(fileURLWithPath: "data.csv")))
    }

    func testSpaceSeparated() throws {
        let content = "abandon 放弃；抛弃\nability 能力"
        try writeTestFile(name: "space.txt", content: content)
        let url = tempDir.appendingPathComponent("space.txt")

        let words = try importer.importWords(fileURL: url)
        XCTAssertEqual(words.count, 2)
        XCTAssertEqual(words[0].word, "abandon")
        XCTAssertEqual(words[0].meaning, "放弃；抛弃")
    }

    func testTabSeparated() throws {
        let parts = ["abandon\t放弃；抛弃", "ability\t能力"]
        let content = parts.joined(separator: "\n")
        try writeTestFile(name: "tab.txt", content: content)
        let url = tempDir.appendingPathComponent("tab.txt")

        let words = try importer.importWords(fileURL: url)
        XCTAssertEqual(words.count, 2)
        XCTAssertEqual(words[0].meaning, "放弃；抛弃")
    }

    func testPipeSeparated() throws {
        let content = "abandon | 放弃；抛弃\nability | 能力"
        try writeTestFile(name: "pipe.txt", content: content)
        let url = tempDir.appendingPathComponent("pipe.txt")

        let words = try importer.importWords(fileURL: url)
        XCTAssertEqual(words.count, 2)
        XCTAssertEqual(words[1].word, "ability")
    }

    func testPhoneticPrefix() throws {
        let content = "/əˈbændən/ abandon 放弃；抛弃"
        try writeTestFile(name: "phonetic.txt", content: content)
        let url = tempDir.appendingPathComponent("phonetic.txt")

        let words = try importer.importWords(fileURL: url)
        XCTAssertEqual(words.count, 1)
        XCTAssertEqual(words[0].phonetic, "/əˈbændən/")
        XCTAssertEqual(words[0].word, "abandon")
    }

    func testDamagedFileDoesNotCrash() throws {
        try writeTestFile(name: "damaged.txt", content: "")
        let url = tempDir.appendingPathComponent("damaged.txt")

        let words = try importer.importWords(fileURL: url)
        XCTAssertGreaterThanOrEqual(words.count, 0)
    }

    func testHeaderSkipped() throws {
        let content = "word meaning\nabandon 放弃"
        try writeTestFile(name: "header.txt", content: content)
        let url = tempDir.appendingPathComponent("header.txt")

        let words = try importer.importWords(fileURL: url)
        XCTAssertEqual(words.count, 1)
        XCTAssertEqual(words[0].word, "abandon")
    }
}
