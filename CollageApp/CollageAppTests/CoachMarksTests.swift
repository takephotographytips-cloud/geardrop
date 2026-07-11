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

    /// 実操作必須ステップ（写真追加）を通過したら「戻る」で戻れない。
    /// 通過前は welcome へ戻れる。
    func testBackBarrier_afterRequiresActionStep() {
        let controller = makeController()
        controller.start()
        controller.advance() // → addPhotos
        XCTAssertTrue(controller.steps[controller.stepIndex].requiresAction)
        XCTAssertTrue(controller.canGoBack, "通過前は welcome へ戻れる")

        controller.noteAction(.photosAdded) // 実操作で通過 → drag
        XCTAssertEqual(controller.stepIndex, 2)
        XCTAssertFalse(controller.canGoBack, "写真追加より前へは戻れない")

        controller.advance() // → pinch
        XCTAssertTrue(controller.canGoBack)
        controller.goBack() // → drag
        XCTAssertEqual(controller.stepIndex, 2)
        controller.goBack() // バリアで止まる
        XCTAssertEqual(controller.stepIndex, 2)
    }
}
