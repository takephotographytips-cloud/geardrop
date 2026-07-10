import XCTest
@testable import CollageApp

/// チュートリアル（Coach Marks）進行ロジックのテスト。
@MainActor
final class CoachMarksTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "CoachMarksTests")
        defaults.removePersistentDomain(forName: "CoachMarksTests")
    }

    private func makeController() -> CoachMarksController {
        CoachMarksController(steps: CoachMarkStep.stackTutorial, defaults: defaults)
    }

    func testTutorialHasEightSteps() {
        XCTAssertEqual(CoachMarkStep.stackTutorial.count, 8)
        XCTAssertEqual(CoachMarkStep.stackTutorial.first?.id, "welcome")
        XCTAssertEqual(CoachMarkStep.stackTutorial.last?.id, "done")
    }

    func testStartIfNeeded_firstLaunchOnly() {
        let controller = makeController()
        XCTAssertFalse(controller.hasSeen)
        controller.startIfNeeded()
        XCTAssertTrue(controller.isActive)

        controller.skip()
        XCTAssertFalse(controller.isActive)
        XCTAssertTrue(controller.hasSeen)

        // 2回目は自動では始まらないが、明示的な start では始まる（設定からの再表示）
        let second = makeController()
        second.startIfNeeded()
        XCTAssertFalse(second.isActive)
        second.start()
        XCTAssertTrue(second.isActive)
        XCTAssertEqual(second.stepIndex, 0)
    }

    func testAdvanceBackAndFinish() {
        let controller = makeController()
        controller.start()
        controller.advance()
        XCTAssertEqual(controller.stepIndex, 1)
        controller.goBack()
        XCTAssertEqual(controller.stepIndex, 0)
        controller.goBack()
        XCTAssertEqual(controller.stepIndex, 0, "先頭より前へは戻らない")

        // 最終ステップで advance すると終了し、既読フラグが立つ
        for _ in 0..<(controller.steps.count) {
            controller.advance()
        }
        XCTAssertFalse(controller.isActive)
        XCTAssertTrue(controller.hasSeen)
    }

    func testNoteAction_advancesOnlyOnMatchingStep() {
        let controller = makeController()
        controller.start()

        // welcome ステップでは操作トリガーは無効
        controller.noteAction(.photoDragged)
        XCTAssertEqual(controller.stepIndex, 0)

        // addPhotos ステップ: 一致するアクションだけで進む
        controller.advance()
        XCTAssertEqual(controller.currentStep?.action, .photosAdded)
        controller.noteAction(.photoPinched)
        XCTAssertEqual(controller.stepIndex, 1)
        controller.noteAction(.photosAdded)
        XCTAssertEqual(controller.stepIndex, 2)

        // 非アクティブ時は無視される
        controller.skip()
        controller.noteAction(.photoDragged)
        XCTAssertFalse(controller.isActive)
    }
}
