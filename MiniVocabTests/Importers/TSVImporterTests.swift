import XCTest
@testable import MiniVocab

final class TSVImporterTests: XCTestCase {

    private var tempDir: URL!
    private var importer: TSVImporter!

    override func setUp() {
        super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("MiniVocab TSV Tests")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        importer = TSVImporter()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func writeTestFile(name: String, content: String) throws {
        let url = tempDir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func testCanImportTSV() {
        XCTAssertTrue(importer.canImport(fileURL: URL(fileURLWithPath: "data.tsv")))
        XCTAssertFalse(importer.canImport(fileURL: URL(fileURLWithPath: "data.csv")))
    }

    func testNormalTSVImport() throws {
        let parts = ["word\tmeaning", "abandon\t放弃；抛弃", "ability\t能力"]
        let content = parts.joined(separator: "\n")
        try writeTestFile(name: "test.tsv", content: content)
        let url = tempDir.appendingPathComponent("test.tsv")

        let words = try importer.importWords(fileURL: url)
        XCTAssertEqual(words.count, 2)
        XCTAssertEqual(words[0].word, "abandon")
        XCTAssertEqual(words[0].meaning, "放弃；抛弃")
    }

    func testTSVDamagedFileDoesNotCrash() throws {
        try writeTestFile(name: "damaged.tsv", content: "garbage")
        let url = tempDir.appendingPathComponent("damaged.tsv")

        let words = try importer.importWords(fileURL: url)
        XCTAssertGreaterThanOrEqual(words.count, 0)
    }
}
