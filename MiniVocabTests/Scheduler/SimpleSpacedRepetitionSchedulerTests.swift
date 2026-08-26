import XCTest
@testable import MiniVocab

final class SimpleSpacedRepetitionSchedulerTests: XCTestCase {

    private var scheduler: SimpleSpacedRepetitionScheduler!

    override func setUp() {
        super.setUp()
        scheduler = SimpleSpacedRepetitionScheduler()
    }

    // MARK: - Interval ordering

    func testIntervalOrdering() {
        var state = LearningState(wordId: "test")
        state.stability = 10.0
        state.reviewCount = 1

        let againInterval = scheduler.apply(.again, to: &state)
        var hardState = state; let hardInterval = scheduler.apply(.hard, to: &hardState)
        var goodState = state; let goodInterval = scheduler.apply(.good, to: &goodState)
        var easyState = state; let easyInterval = scheduler.apply(.easy, to: &easyState)

        XCTAssertLessThan(againInterval, hardInterval, "Again < Hard")
        XCTAssertLessThan(hardInterval, goodInterval, "Hard < Good")
        XCTAssertLessThan(goodInterval, easyInterval, "Good < Easy")
    }

    // MARK: - First review intervals

    func testFirstTimeAgainIs600Seconds() {
        var state = LearningState(wordId: "test")
        XCTAssertEqual(state.stability, 0.0)
        let interval = scheduler.apply(.again, to: &state)
        XCTAssertEqual(interval, 600.0, accuracy: 0.01, "First-time Again should be 600s (10 min)")
    }

    func testFirstTimeHardIs1800Seconds() {
        var state = LearningState(wordId: "test")
        let interval = scheduler.apply(.hard, to: &state)
        XCTAssertEqual(interval, 1800.0, accuracy: 0.01, "First-time Hard should be 1800s (30 min)")
    }

    func testFirstTimeGoodIs3600Seconds() {
        var state = LearningState(wordId: "test")
        let interval = scheduler.apply(.good, to: &state)
        XCTAssertEqual(interval, 3600.0, accuracy: 0.01, "First-time Good should be 3600s (1 hour)")
    }

    func testFirstTimeEasyIsOneDay() {
        var state = LearningState(wordId: "test")
        let interval = scheduler.apply(.easy, to: &state)
        XCTAssertEqual(interval, 86400.0, accuracy: 0.01, "First-time Easy should be 86400s (1 day)")
    }

    // MARK: - State mutations

    func testAgainIncreasesForgetCountAndDifficultyMost() {
        var state = LearningState(wordId: "test")
        state.difficulty = 3.0
        _ = scheduler.apply(.again, to: &state)

        XCTAssertEqual(state.reviewCount, 1)
        XCTAssertEqual(state.forgetCount, 1)
        XCTAssertGreaterThan(state.difficulty, 3.0)
        let difficultyIncrease = state.difficulty - 3.0
        XCTAssertGreaterThanOrEqual(difficultyIncrease, 0.9, "Again should increase difficulty by ~1.0")
    }

    func testHardDoesNotIncreaseForgetCount() {
        var state = LearningState(wordId: "test")
        state.difficulty = 3.0
        let initialForgetCount = state.forgetCount
        _ = scheduler.apply(.hard, to: &state)

        XCTAssertEqual(state.forgetCount, initialForgetCount, "Hard should not increase forgetCount")
        XCTAssertGreaterThan(state.difficulty, 3.0)
        let difficultyIncrease = state.difficulty - 3.0
        XCTAssertGreaterThanOrEqual(difficultyIncrease, 0.2, "Hard should increase difficulty by ~0.25")
    }

    func testGoodDecreasesDifficultySlightly() {
        var state = LearningState(wordId: "test")
        state.difficulty = 5.0
        _ = scheduler.apply(.good, to: &state)

        XCTAssertLessThan(state.difficulty, 5.0)
        let decrease = 5.0 - state.difficulty
        XCTAssertGreaterThanOrEqual(decrease, 0.09, "Good should decrease difficulty by ~0.1")
    }

    func testEasyDecreasesDifficultyMoreThanGood() {
        var stateGood = LearningState(wordId: "test")
        stateGood.difficulty = 5.0
        _ = scheduler.apply(.good, to: &stateGood)

        var stateEasy = LearningState(wordId: "test")
        stateEasy.difficulty = 5.0
        _ = scheduler.apply(.easy, to: &stateEasy)

        XCTAssertLessThan(stateEasy.difficulty, stateGood.difficulty, "Easy should reduce difficulty more than Good")
    }

    func testReviewCountIncrements() {
        var state = LearningState(wordId: "test")
        XCTAssertEqual(state.reviewCount, 0)
        _ = scheduler.apply(.good, to: &state)
        XCTAssertEqual(state.reviewCount, 1)
        _ = scheduler.apply(.hard, to: &state)
        XCTAssertEqual(state.reviewCount, 2)
    }

    func testNextReviewAtIsSet() {
        var state = LearningState(wordId: "test")
        _ = scheduler.apply(.good, to: &state)
        XCTAssertNotNil(state.nextReviewAt, "nextReviewAt should be set after review")
        XCTAssertNotNil(state.lastReviewedAt, "lastReviewedAt should be set after review")
    }

    func testNewStateHasZeroReviewCount() {
        let state = LearningState(wordId: "test")
        XCTAssertEqual(scheduler.computeState(for: state), "New")
    }

    func testDifficultStateDetected() {
        var state = LearningState(wordId: "test")
        for _ in 0..<2 {
            _ = scheduler.apply(.again, to: &state)
        }
        _ = scheduler.apply(.good, to: &state)
        for _ in 0..<2 {
            _ = scheduler.apply(.again, to: &state)
        }

        let computed = scheduler.computeState(for: state)
        XCTAssertEqual(computed, "Difficult", "Should be marked as Difficult")
    }

    func testMasteredStateDetected() {
        var state = LearningState(wordId: "test")
        state.stability = 25000.0
        state.difficulty = 1.0
        state.reviewCount = 10
        state.nextReviewAt = Date().addingTimeInterval(100000)

        let computed = scheduler.computeState(for: state)
        XCTAssertEqual(computed, "Mastered")
    }
}
