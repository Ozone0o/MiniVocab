import XCTest
@testable import MiniVocab

final class SimpleSpacedRepetitionSchedulerTests: XCTestCase {

    private var scheduler: SimpleSpacedRepetitionScheduler!

    override func setUp() {
        super.setUp()
        scheduler = SimpleSpacedRepetitionScheduler()
    }

    func testAgainProducesShortestInterval() {
        var state = LearningState(wordId: "test")
        let interval = scheduler.nextReviewInterval(for: state, rating: .again)

        state = LearningState(wordId: "test")
        _ = scheduler.nextReviewInterval(for: state, rating: .good)
        let goodInterval = scheduler.nextReviewInterval(for: state, rating: .good)

        XCTAssertLessThan(interval, goodInterval, "Again interval should be shorter than Good")
    }

    func testHardIntervalLessThanGood() {
        var state = LearningState(wordId: "test")
        state.stability = 100.0
        let hardInterval = scheduler.nextReviewInterval(for: state, rating: .hard)

        state.stability = 100.0
        let goodInterval = scheduler.nextReviewInterval(for: state, rating: .good)

        XCTAssertLessThan(hardInterval, goodInterval, "Hard interval should be shorter than Good")
    }

    func testGoodIntervalLessThanEasy() {
        var state = LearningState(wordId: "test")
        state.stability = 100.0
        let goodInterval = scheduler.nextReviewInterval(for: state, rating: .good)

        state.stability = 100.0
        let easyInterval = scheduler.nextReviewInterval(for: state, rating: .easy)

        XCTAssertLessThan(goodInterval, easyInterval, "Good interval should be shorter than Easy")
    }

    func testFirstTimeAgainIs60Seconds() {
        var state = LearningState(wordId: "test")
        XCTAssertEqual(state.stability, 0.0)
        let interval = scheduler.nextReviewInterval(for: state, rating: .again)
        XCTAssertEqual(interval, 60.0, accuracy: 0.01, "First-time Again should be 60s")
    }

    func testFirstTimeGoodIs20Minutes() {
        var state = LearningState(wordId: "test")
        let interval = scheduler.nextReviewInterval(for: state, rating: .good)
        XCTAssertEqual(interval, 1200.0, accuracy: 0.01, "First-time Good should be 1200s (20 min)")
    }

    func testFirstTimeEasyIsOneDay() {
        var state = LearningState(wordId: "test")
        let interval = scheduler.nextReviewInterval(for: state, rating: .easy)
        XCTAssertEqual(interval, 86400.0, accuracy: 0.01, "First-time Easy should be 86400s (1 day)")
    }

    func testForgetCountIncreasesDifficulty() {
        var state = LearningState(wordId: "test")
        scheduler.updateState(&state, rating: .again)
        XCTAssertGreaterThan(state.difficulty, 0.0, "Difficulty should increase after Again")
        XCTAssertGreaterThan(state.forgetCount, 0, "ForgetCount should increase after Again")
    }

    func testEasyReducesDifficulty() {
        var state = LearningState(wordId: "test")
        state.difficulty = 5.0
        scheduler.updateState(&state, rating: .easy)
        XCTAssertLessThan(state.difficulty, 5.0, "Difficulty should decrease after Easy")
    }

    func testDifficultStateDetected() {
        var state = LearningState(wordId: "test")
        // Simulate 5 reviews, 3 forgets
        for _ in 0..<2 {
            scheduler.updateState(&state, rating: .again)
        }
        scheduler.updateState(&state, rating: .good)
        for _ in 0..<2 {
            scheduler.updateState(&state, rating: .again)
        }

        let computed = scheduler.computeState(for: state)
        XCTAssertEqual(computed, "Difficult", "Should be marked as Difficult")
    }

    func testReviewCountIncrements() {
        var state = LearningState(wordId: "test")
        XCTAssertEqual(state.reviewCount, 0)
        scheduler.updateState(&state, rating: .good)
        XCTAssertEqual(state.reviewCount, 1)
        scheduler.updateState(&state, rating: .hard)
        XCTAssertEqual(state.reviewCount, 2)
    }

    func testNextReviewAtIsSet() {
        var state = LearningState(wordId: "test")
        scheduler.updateState(&state, rating: .good)
        XCTAssertNotNil(state.nextReviewAt, "nextReviewAt should be set after review")
        XCTAssertNotNil(state.lastReviewedAt, "lastReviewedAt should be set after review")
    }
}
