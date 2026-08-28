import XCTest
@testable import MiniVocab

final class ExampleDatabaseTests: XCTestCase {

    func testBundledExampleDatabaseLoadsAndLooksUpWords() {
        guard let database = ExampleDatabase.load() else {
            return XCTFail("The bundled examples.sqlite resource should be available to tests")
        }

        XCTAssertNotNil(database.lookup(for: "abandon"))
        XCTAssertNotNil(database.lookup(for: " ABANDON "))
    }
}
