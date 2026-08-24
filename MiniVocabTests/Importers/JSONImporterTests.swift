import XCTest
@testable import MiniVocab

final class JSONImporterTests: XCTestCase {

    private var tempDir: URL!
    private var importer: JSONImporter!

    override func setUp() {
        super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("MiniVocab JSON Tests")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        importer = JSONImporter()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func writeTestFile(name: String, content: String) throws {
        let url = tempDir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func testCanImportJSON() {
        XCTAssertTrue(importer.canImport(fileURL: URL(fileURLWithPath: "data.json")))
        XCTAssertFalse(importer.canImport(fileURL: URL(fileURLWithPath: "data.csv")))
    }

    func testNormalJSONImport() throws {
        let content = """
        [
          {"word": "abandon", "meaning": "放弃；抛弃"},
          {"word": "ability", "meaning": "能力"}
        ]
        """
        try writeTestFile(name: "test.json", content: content)
        let url = tempDir.appendingPathComponent("test.json")

        let words = try importer.importWords(fileURL: url)
        XCTAssertEqual(words.count, 2)
        XCTAssertEqual(words[0].word, "abandon")
        XCTAssertEqual(words[0].meaning, "放弃；抛弃")
    }

    func testJSONWithPhonetic() throws {
        let content = """
        [
          {"word": "ambiguous", "phonetic": "/æmˈbɪɡjuəs/", "meaning": "模棱两可的"}
        ]
        """
        try writeTestFile(name: "phonetic.json", content: content)
        let url = tempDir.appendingPathComponent("phonetic.json")

        let words = try importer.importWords(fileURL: url)
        XCTAssertEqual(words.count, 1)
        XCTAssertEqual(words[0].phonetic, "/æmˈbɪɡjuəs/")
    }

    func testJSONWithExample() throws {
        let content = """
        [
          {"word": "ambiguous", "meaning": "模棱两可的", "example": "The answer remains ambiguous."}
        ]
        """
        try writeTestFile(name: "example.json", content: content)
        let url = tempDir.appendingPathComponent("example.json")

        let words = try importer.importWords(fileURL: url)
        XCTAssertEqual(words.count, 1)
        XCTAssertEqual(words[0].example, "The answer remains ambiguous.")
    }

    func testJSONEmptyArray() throws {
        try writeTestFile(name: "empty.json", content: "[]")
        let url = tempDir.appendingPathComponent("empty.json")

        let words = try importer.importWords(fileURL: url)
        XCTAssertTrue(words.isEmpty)
    }

    func testJSONSkipsEmptyWord() throws {
        let content = """
        [
          {"meaning": "no word"},
          {"word": "", "meaning": "empty word"},
          {"word": "valid", "meaning": "有效的"}
        ]
        """
        try writeTestFile(name: "skip.json", content: content)
        let url = tempDir.appendingPathComponent("skip.json")

        let words = try importer.importWords(fileURL: url)
        XCTAssertEqual(words.count, 1)
        XCTAssertEqual(words[0].word, "valid")
    }

    func testJSONDamagedFileThrows() throws {
        try writeTestFile(name: "damaged.json", content: "{invalid json")
        let url = tempDir.appendingPathComponent("damaged.json")

        XCTAssertThrowsError(try importer.importWords(fileURL: url))
    }

    func testJSONAlternativeFieldNames() throws {
        let content = """
        [
          {"english": "abandon", "definition": "放弃", "sentence": "Goodbye."}
        ]
        """
        try writeTestFile(name: "alt.json", content: content)
        let url = tempDir.appendingPathComponent("alt.json")

        let words = try importer.importWords(fileURL: url)
        XCTAssertEqual(words.count, 1)
        XCTAssertEqual(words[0].word, "abandon")
    }
}
