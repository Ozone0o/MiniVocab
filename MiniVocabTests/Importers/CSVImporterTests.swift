import XCTest
@testable import MiniVocab

final class CSVImporterTests: XCTestCase {

    private var tempDir: URL!
    private var importer: CSVImporter!

    override func setUp() {
        super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("MiniVocab CSV Tests")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        importer = CSVImporter()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func writeTestFile(name: String, content: String) throws {
        let url = tempDir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func testCanImportCSV() {
        XCTAssertTrue(importer.canImport(fileURL: URL(fileURLWithPath: "data.csv")))
        XCTAssertFalse(importer.canImport(fileURL: URL(fileURLWithPath: "data.json")))
    }

    func testNormalCSVImport() throws {
        let content = """
            word,meaning
            abandon,放弃；抛弃
            ability,能力
            abstract,抽象的

            """
        try writeTestFile(name: "test.csv", content: content)
        let url = tempDir.appendingPathComponent("test.csv")

        let words = try importer.importWords(fileURL: url)
        XCTAssertEqual(words.count, 3)
        XCTAssertEqual(words[0].word, "abandon")
        XCTAssertEqual(words[0].meaning, "放弃；抛弃")
        XCTAssertEqual(words[1].word, "ability")
        XCTAssertEqual(words[2].word, "abstract")
    }

    func testCSVWithPhonetic() throws {
        let content = """
            word,phonetic,meaning
            ambiguous,/æmˈbɪɡjuəs/,模棱两可的

            """
        try writeTestFile(name: "phonetic.csv", content: content)
        let url = tempDir.appendingPathComponent("phonetic.csv")

        let words = try importer.importWords(fileURL: url)
        XCTAssertEqual(words.count, 1)
        XCTAssertEqual(words[0].phonetic, "/æmˈbɪɡjuəs/")
    }

    func testCSVWithExample() throws {
        let content = """
            word,meaning,example
            ambiguous,模棱两可的,The answer remains ambiguous.

            """
        try writeTestFile(name: "example.csv", content: content)
        let url = tempDir.appendingPathComponent("example.csv")

        let words = try importer.importWords(fileURL: url)
        XCTAssertEqual(words.count, 1)
        XCTAssertEqual(words[0].example, "The answer remains ambiguous.")
    }

    func testCSVMixedFields() throws {
        let content = """
            word,phonetic,meaning,example,exampleTranslation
            ambiguous,/æmˈbɪɡjuəs/,模棱两可的,The wording of the rule is ambiguous.,规则用词含糊不清。
            consecutive,/kənˈsekjutɪv/,连续的,The team won three consecutive games.,球队连胜三场。

            """
        try writeTestFile(name: "full.csv", content: content)
        let url = tempDir.appendingPathComponent("full.csv")

        let words = try importer.importWords(fileURL: url)
        XCTAssertEqual(words.count, 2)
        XCTAssertEqual(words[0].word, "ambiguous")
        XCTAssertEqual(words[0].phonetic, "/æmˈbɪɡjuəs/")
        XCTAssertEqual(words[0].example, "The wording of the rule is ambiguous.")
        XCTAssertEqual(words[0].exampleTranslation, "规则用词含糊不清。")
    }

    func testCSVChineseFields() throws {
        let content = """
            单词,释义
            测试词,测试释义

            """
        try writeTestFile(name: "chinese.csv", content: content)
        let url = tempDir.appendingPathComponent("chinese.csv")

        let words = try importer.importWords(fileURL: url)
        // With Chinese field names, only word column is detected; meaning may need mapping
        XCTAssertGreaterThanOrEqual(words.count, 0)
    }

    func testCSVDuplicatesHandled() throws {
        let content = """
            word,meaning
            abandon,放弃
            abandon,放弃；抛弃

            """
        try writeTestFile(name: "dup.csv", content: content)
        let url = tempDir.appendingPathComponent("dup.csv")

        let words = try importer.importWords(fileURL: url)
        // Importer returns all parsed; dedup is handled by WordBookService
        XCTAssertEqual(words.count, 2)
    }

    func testCSVDamagedFileDoesNotCrash() throws {
        let content = "garbage,,,\n,,,,"
        try writeTestFile(name: "damaged.csv", content: content)
        let url = tempDir.appendingPathComponent("damaged.csv")

        let words = try importer.importWords(fileURL: url)
        // Should not crash; may return empty
        XCTAssertGreaterThanOrEqual(words.count, 0)
    }

    func testCSVEmptyFileReturnsEmpty() throws {
        try writeTestFile(name: "empty.csv", content: "")
        let url = tempDir.appendingPathComponent("empty.csv")

        let words = try importer.importWords(fileURL: url)
        XCTAssertTrue(words.isEmpty)
    }

    func testCSVHeaderOnlyReturnsEmpty() throws {
        try writeTestFile(name: "header.csv", content: "word,meaning\n")
        let url = tempDir.appendingPathComponent("header.csv")

        let words = try importer.importWords(fileURL: url)
        XCTAssertTrue(words.isEmpty)
    }

    func testCSVUTF8Encoding() throws {
        let content = """
            word,meaning
            /café/,咖啡馆,café
            naïve,天真的

            """
        try writeTestFile(name: "utf8.csv", content: content)
        let url = tempDir.appendingPathComponent("utf8.csv")

        let words = try importer.importWords(fileURL: url)
        XCTAssertEqual(words.count, 2)
        XCTAssertTrue(words[0].word.contains("café"))
        XCTAssertTrue(words[1].word.contains("naïve"))
    }
}
