import SwiftUI

// MARK: - モデル

/// スポットライト対象の UI。対象ビューに `.coachMarkTarget(_:)` を付けると
/// PreferenceKey 経由でフレームが収集される。
enum CoachMarkTargetID: String, Hashable {
    case addPhotoButton
    case canvas
    case layoutPicker
    case marginSlider
}

/// 「ユーザーが実際に操作したら次へ進む」ためのトリガー。
/// 操作した側のビューが `controller.noteAction(_:)` を呼ぶ。
enum CoachMarkAction: Equatable {
    case photosAdded
    case photoDragged
    case photoPinched
    case layoutChanged
    case marginChanged
    case collageSaved
}

/// チュートリアルの1ステップ。配列の追加・削除・並べ替えだけで手順を変更できる。
struct CoachMarkStep: Identifiable {
    let id: String
    /// スポットライトでくり抜く対象（nil なら全画面ディム）
    var target: CoachMarkTargetID? = nil
    let title: String
    let message: String
    /// 実操作での自動前進トリガー（nil なら「次へ」ボタンのみ）
    var action: CoachMarkAction? = nil
    /// ターゲットが無いステップで吹き出しを寄せたい位置（nil なら中央）
    var anchorPoint: ((CGSize) -> CGPoint)? = nil
}

extension CoachMarkStep {
    /// Stack のチュートリアル手順（初回起動時 / 設定から再表示）
    static let stackTutorial: [CoachMarkStep] = [
        CoachMarkStep(
            id: "welcome",
            title: "Stack へようこそ",
            message: "30秒で使い方をご紹介します"
        ),
        CoachMarkStep(
            id: "addPhotos",
            target: .addPhotoButton,
            title: "写真を選ぶ",
            message: "ここをタップして写真を追加します",
            action: .photosAdded
        ),
        CoachMarkStep(
            id: "drag",
            target: .canvas,
            title: "位置の調整",
            message: "写真をドラッグすると位置を変更できます",
            action: .photoDragged
        ),
        CoachMarkStep(
            id: "pinch",
            target: .canvas,
            title: "拡大・縮小",
            message: "ピンチで拡大・縮小できます",
            action: .photoPinched
        ),
        CoachMarkStep(
            id: "layout",
            target: .layoutPicker,
            title: "レイアウト",
            message: "ここからレイアウトを変更できます",
            action: .layoutChanged
        ),
        CoachMarkStep(
            id: "margin",
            target: .marginSlider,
            title: "余白",
            message: "余白を変更すると印象が変わります",
            action: .marginChanged
        ),
        CoachMarkStep(
            id: "save",
            title: "保存",
            message: "完成したら右上の「保存」から書き出せます",
            action: .collageSaved,
            anchorPoint: { size in CGPoint(x: size.width - 72, y: 10) }
        ),
        CoachMarkStep(
            id: "done",
            title: "準備完了",
            message: "これで準備完了です！さっそく作品を作りましょう"
        ),
    ]
}

// MARK: - コントローラ

/// チュートリアルの進行状態。初回表示は UserDefaults で管理し、
/// 設定画面の「チュートリアルを見る」からいつでも再表示できる。
@Observable
@MainActor
final class CoachMarksController {

    static let seenDefaultsKey = "hasSeenTutorial"

    private(set) var isActive = false
    private(set) var stepIndex = 0

    let steps: [CoachMarkStep]
    private let defaults: UserDefaults

    init(steps: [CoachMarkStep] = CoachMarkStep.stackTutorial, defaults: UserDefaults = .standard) {
        self.steps = steps
        self.defaults = defaults
    }

    var currentStep: CoachMarkStep? {
        guard isActive, steps.indices.contains(stepIndex) else { return nil }
        return steps[stepIndex]
    }

    var isLastStep: Bool { stepIndex == steps.count - 1 }
    var canGoBack: Bool { stepIndex > 0 }

    var hasSeen: Bool { defaults.bool(forKey: Self.seenDefaultsKey) }

    /// 初回起動時のみ開始する
    func startIfNeeded() {
        guard !hasSeen, !steps.isEmpty else { return }
        start()
    }

    /// （再）開始。設定画面の「チュートリアルを見る」からも呼ばれる
    func start() {
        guard !steps.isEmpty else { return }
        stepIndex = 0
        isActive = true
    }

    func advance() {
        if stepIndex + 1 < steps.count {
            stepIndex += 1
        } else {
            finish()
        }
    }

    func goBack() {
        guard canGoBack else { return }
        stepIndex -= 1
    }

    func skip() {
        finish()
    }

    /// ユーザーの実操作を通知する。現在のステップのトリガーと一致すれば次へ進む
    func noteAction(_ action: CoachMarkAction) {
        guard isActive, currentStep?.action == action else { return }
        advance()
    }

    private func finish() {
        isActive = false
        defaults.set(true, forKey: Self.seenDefaultsKey)
    }
}

// MARK: - ターゲット収集（PreferenceKey）

struct CoachMarkAnchorKey: PreferenceKey {
    static var defaultValue: [CoachMarkTargetID: Anchor<CGRect>] { [:] }
    static func reduce(
        value: inout [CoachMarkTargetID: Anchor<CGRect>],
        nextValue: () -> [CoachMarkTargetID: Anchor<CGRect>]
    ) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// このビューをチュートリアルのスポットライト対象として登録する
    func coachMarkTarget(_ id: CoachMarkTargetID) -> some View {
        anchorPreference(key: CoachMarkAnchorKey.self, value: .bounds) { [id: $0] }
    }

    /// 画面ルートに適用する Coach Marks オーバーレイ（再利用可能コンポーネント）
    func coachMarks(_ controller: CoachMarksController) -> some View {
        modifier(CoachMarksModifier(controller: controller))
    }
}

// MARK: - オーバーレイ本体

struct CoachMarksModifier: ViewModifier {
    let controller: CoachMarksController

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(CoachMarkAnchorKey.self) { anchors in
            GeometryReader { proxy in
                ZStack {
                    if let step = controller.currentStep {
                        CoachMarkOverlay(
                            controller: controller,
                            step: step,
                            cutout: cutoutRect(for: step, anchors: anchors, proxy: proxy),
                            size: proxy.size
                        )
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: controller.isActive)
                .animation(.easeInOut(duration: 0.3), value: controller.stepIndex)
            }
        }
    }

    private func cutoutRect(
        for step: CoachMarkStep,
        anchors: [CoachMarkTargetID: Anchor<CGRect>],
        proxy: GeometryProxy
    ) -> CGRect? {
        guard let target = step.target, let anchor = anchors[target] else { return nil }
        return proxy[anchor].insetBy(dx: -8, dy: -8)
    }
}

private struct CoachMarkOverlay: View {
    let controller: CoachMarksController
    let step: CoachMarkStep
    let cutout: CGRect?
    let size: CGSize

    @State private var bubbleSize: CGSize = .zero

    private let bubbleMargin: CGFloat = 20

    var body: some View {
        ZStack {
            // 半透明ディム + スポットライトのくり抜き（見た目のみ、タッチは透過）
            SpotlightDim(cutout: cutout ?? CGRect(x: size.width / 2, y: size.height / 2, width: 0, height: 0))
                .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)

            // スポットライトの縁取り
            if let cutout {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.9), lineWidth: 2)
                    .frame(width: cutout.width, height: cutout.height)
                    .position(x: cutout.midX, y: cutout.midY)
                    .allowsHitTesting(false)
            }

            // タッチのブロック: ターゲットありは周囲4枚（対象だけ操作できる）、
            // 操作を求めないステップは全面ブロック、操作型でターゲットなしは素通し
            interactionBlockers

            // 矢印つき吹き出し
            arrowAndBubble
        }
        .accessibilityAddTraits(.isModal)
        .onAppear { announce() }
        .onChange(of: step.id) { _, _ in announce() }
    }

    // MARK: タッチブロック

    @ViewBuilder
    private var interactionBlockers: some View {
        if let cutout {
            Group {
                blocker(CGRect(x: 0, y: 0, width: size.width, height: max(cutout.minY, 0)))
                blocker(CGRect(x: 0, y: cutout.maxY, width: size.width, height: max(size.height - cutout.maxY, 0)))
                blocker(CGRect(x: 0, y: cutout.minY, width: max(cutout.minX, 0), height: cutout.height))
                blocker(CGRect(x: cutout.maxX, y: cutout.minY, width: max(size.width - cutout.maxX, 0), height: cutout.height))
            }
        } else if step.action == nil {
            blocker(CGRect(origin: .zero, size: size))
        }
    }

    private func blocker(_ rect: CGRect) -> some View {
        Color.black.opacity(0.001)
            .frame(width: max(rect.width, 0), height: max(rect.height, 0))
            .position(x: rect.midX, y: rect.midY)
            .accessibilityHidden(true)
    }

    // MARK: 吹き出し

    private var anchorTargetPoint: CGPoint? {
        if let cutout { return CGPoint(x: cutout.midX, y: cutout.midY) }
        if let point = step.anchorPoint?(size) { return point }
        return nil
    }

    /// 吹き出しを対象の下に置くか（対象が画面上半分なら下、下半分なら上）
    private var placeBelow: Bool {
        if let cutout { return cutout.midY < size.height / 2 }
        if let point = step.anchorPoint?(size) { return point.y < size.height / 2 }
        return false
    }

    private var arrowAndBubble: some View {
        let bubbleWidth = min(size.width - bubbleMargin * 2, 320)
        let anchor = anchorTargetPoint
        let below = placeBelow
        let gap: CGFloat = 16

        // 吹き出しの中心位置
        let x: CGFloat = {
            guard let anchor else { return size.width / 2 }
            return min(max(anchor.x, bubbleMargin + bubbleWidth / 2), size.width - bubbleMargin - bubbleWidth / 2)
        }()
        let y: CGFloat = {
            guard let anchor else { return size.height / 2 }
            let referenceY = cutout.map { below ? $0.maxY : $0.minY } ?? anchor.y
            let half = max(bubbleSize.height, 100) / 2
            let raw = below ? referenceY + gap + half : referenceY - gap - half
            return min(max(raw, half + bubbleMargin), size.height - half - bubbleMargin)
        }()

        return ZStack {
            if let anchor {
                ArrowTriangle(pointingUp: below)
                    .fill(bubbleBackground)
                    .frame(width: 20, height: 10)
                    .position(
                        x: min(max(anchor.x, x - bubbleWidth / 2 + 28), x + bubbleWidth / 2 - 28),
                        y: below
                            ? y - max(bubbleSize.height, 100) / 2 - 4
                            : y + max(bubbleSize.height, 100) / 2 + 4
                    )
                    .accessibilityHidden(true)
            }

            bubbleContent(width: bubbleWidth)
                .position(x: x, y: y)
        }
    }

    private var bubbleBackground: Color {
        Color(.secondarySystemBackground)
    }

    private func bubbleContent(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step.title)
                .font(.headline)
            Text(step.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button("スキップ") {
                    controller.skip()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityLabel("チュートリアルをスキップ")

                Spacer()

                if controller.canGoBack {
                    Button("戻る") {
                        controller.goBack()
                    }
                    .font(.subheadline)
                }

                Button(controller.isLastStep ? "完了" : "次へ") {
                    controller.advance()
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: width, alignment: .leading)
        .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear { bubbleSize = geometry.size }
                    .onChange(of: geometry.size) { _, newSize in bubbleSize = newSize }
            }
        )
    }

    /// VoiceOver へステップ内容を読み上げる
    private func announce() {
        UIAccessibility.post(notification: .announcement, argument: "\(step.title)。\(step.message)")
    }
}

/// ディム + くり抜き。cutout をアニメータブルにしてスポットライトが滑らかに移動する。
private struct SpotlightDim: Shape {
    var cutout: CGRect
    var cornerRadius: CGFloat = 12

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(
                AnimatablePair(cutout.origin.x, cutout.origin.y),
                AnimatablePair(cutout.size.width, cutout.size.height)
            )
        }
        set {
            cutout = CGRect(
                x: newValue.first.first,
                y: newValue.first.second,
                width: newValue.second.first,
                height: newValue.second.second
            )
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        if cutout.width > 0, cutout.height > 0 {
            path.addRoundedRect(
                in: cutout,
                cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
            )
        }
        return path
    }
}

private struct ArrowTriangle: Shape {
    let pointingUp: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if pointingUp {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }
        path.closeSubpath()
        return path
    }
}
