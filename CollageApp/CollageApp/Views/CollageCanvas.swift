import SwiftUI

extension View {
    /// 条件が真のときだけ modifier を適用する。
    /// （入れ替えジェスチャーを通常モードのみ付与するために使用）
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

extension CanvasColor {
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue)
    }

    /// SwiftUI Color（カラーピッカーの選択値）から生成する
    init(_ color: Color) {
        var red: CGFloat = 1, green: CGFloat = 1, blue: CGFloat = 1, alpha: CGFloat = 1
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(red: Double(red), green: Double(green), blue: Double(blue))
    }
}

/// キャンバスの操作モード。
/// - arrange: 通常。ドラッグ=移動 / ピンチ=拡大縮小 / 長押し=入れ替え。タップは無反応
/// - adjust: 「調整」ボタンで入る。タップ=調整対象の選択、ドラッグ/ピンチは移動・拡大。入れ替えは無効
enum CanvasInteraction {
    case arrange
    case adjust
}

/// キャンバスプレビュー（Instagram / Canva 型）。
/// セル（枠）は固定で、各セル内の写真だけをドラッグ移動・ピンチ拡大縮小できる。
struct CollageCanvasView: View {
    @Bindable var viewModel: EditorViewModel
    var interaction: CanvasInteraction = .arrange

    var body: some View {
        GeometryReader { geometry in
            let layout = viewModel.currentLayout ?? .verticalStack
            let spec = viewModel.spec
            let cells = layout.cellRects(
                canvasSize: geometry.size,
                spec: spec,
                count: viewModel.photos.count
            )
            ZStack {
                (spec.frame.backgroundOverride ?? spec.background).color
                ForEach(Array(viewModel.photos.enumerated()), id: \.element.id) { index, photo in
                    if cells.indices.contains(index) {
                        let cell = cells[index]
                        CollageCellView(
                            image: photo.image,
                            cellSize: cell.size,
                            transform: transformBinding(for: photo.id),
                            swapEnabled: interaction == .arrange && viewModel.photos.count > 1,
                            onGestureBegan: { viewModel.registerUndoSnapshot() },
                            onTap: {
                                guard interaction == .adjust else { return }
                                viewModel.selectedPhotoID = photo.id
                            },
                            onSwapEnded: { translation in
                                handleSwap(sourceIndex: index, translation: translation, cells: cells)
                            }
                        )
                        .frame(width: cell.width, height: cell.height)
                        .position(x: cell.midX, y: cell.midY)
                    }
                }
                // 調整中の選択セル: 三分割グリッド＋枠（水平合わせの目安）
                if interaction == .adjust,
                   let selectedIndex = viewModel.selectedPhotoIndex,
                   cells.indices.contains(selectedIndex) {
                    CellSelectionOverlay(cell: cells[selectedIndex])
                        .allowsHitTesting(false)
                }
                if spec.frame != .none {
                    FrameDecorationCanvas(
                        elements: spec.frame.decorationElements(
                            canvasSize: geometry.size,
                            spec: spec,
                            layout: layout,
                            cells: cells
                        ),
                        grainAlpha: spec.frame.grainAlpha
                    )
                    .allowsHitTesting(false)
                }
            }
        }
        .aspectRatio(viewModel.spec.ratio.value, contentMode: .fit)
    }

    /// ドロップ位置にあるセルへ入れ替える。セル外に落とした場合は何もしない。
    private func handleSwap(sourceIndex: Int, translation: CGSize, cells: [CGRect]) {
        guard cells.indices.contains(sourceIndex) else { return }
        let source = cells[sourceIndex]
        let dropPoint = CGPoint(
            x: source.midX + translation.width,
            y: source.midY + translation.height
        )
        guard let target = cells.firstIndex(where: { $0.contains(dropPoint) }),
              target != sourceIndex else { return }
        viewModel.swapPhotos(from: sourceIndex, to: target)
    }

    /// セルごとの変形状態への Binding（未編集セルはデフォルト = カバー・中央）
    private func transformBinding(for id: UUID) -> Binding<CellTransform> {
        Binding {
            viewModel.transforms[id] ?? CellTransform()
        } set: { newValue in
            viewModel.transforms[id] = newValue
        }
    }
}

/// 選択中セルのオーバーレイ: 三分割グリッド＋白枠。
/// 水平・回転補正時に地平線などを合わせやすくする。
struct CellSelectionOverlay: View {
    let cell: CGRect

    var body: some View {
        ZStack {
            Path { path in
                for fraction in [1.0 / 3.0, 2.0 / 3.0] as [CGFloat] {
                    let x = cell.minX + cell.width * fraction
                    path.move(to: CGPoint(x: x, y: cell.minY))
                    path.addLine(to: CGPoint(x: x, y: cell.maxY))
                    let y = cell.minY + cell.height * fraction
                    path.move(to: CGPoint(x: cell.minX, y: y))
                    path.addLine(to: CGPoint(x: cell.maxX, y: y))
                }
            }
            .stroke(.white.opacity(0.55), lineWidth: 1)

            Path(cell)
                .stroke(.white, lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.25), radius: 1)
    }
}

/// フレーム装飾（穴・文字・グレイン）のプレビュー描画。
/// 書き出し側（FrameElementRenderer）と同じ FrameElement・ノイズテクスチャを描くため見た目が一致する。
struct FrameDecorationCanvas: View {
    let elements: [FrameElement]
    var grainAlpha: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            for element in elements {
                switch element {
                case .roundedRect(let rect, let cornerRadius, let color):
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: cornerRadius),
                        with: .color(color.color)
                    )
                case .text(let string, let center, let height, let rotationDegrees, let color):
                    var rotated = context
                    rotated.translateBy(x: center.x, y: center.y)
                    rotated.rotate(by: .degrees(rotationDegrees))
                    rotated.draw(
                        Text(string)
                            .font(.system(size: height, weight: .semibold, design: .monospaced))
                            .foregroundColor(color.color),
                        at: .zero,
                        anchor: .center
                    )
                }
            }

            // グレイン: 書き出しと同じく短辺の 1/8 をタイルサイズにする
            if grainAlpha > 0 {
                var grain = context
                grain.opacity = grainAlpha
                grain.blendMode = .overlay
                let tile = max(min(size.width, size.height) / 8, 8)
                let image = Image(uiImage: GrainTexture.shared)
                var y: CGFloat = 0
                while y < size.height {
                    var x: CGFloat = 0
                    while x < size.width {
                        grain.draw(image, in: CGRect(x: x, y: y, width: tile, height: tile))
                        x += tile
                    }
                    y += tile
                }
            }
        }
    }
}

/// 1セル分のビュー。
/// 構成: 固定枠(frame) → クリップ(clipped) → カバーフィット＋変形適用済みの Image。
/// Flutter でいう ClipRect > InteractiveViewer > FittedBox(cover) > Image に相当し、
/// 変形状態はセルごとに独立した `CellTransform` として保持する。
struct CollageCellView: View {
    let image: UIImage
    let cellSize: CGSize
    @Binding var transform: CellTransform
    /// 長押しドラッグでの入れ替えを許可するか（通常モードかつ2枚以上のとき true）
    var swapEnabled: Bool = false
    var onGestureBegan: () -> Void
    var onTap: () -> Void = {}
    /// 入れ替えドラッグ終了時、セル中心からの移動量を通知する
    var onSwapEnded: (CGSize) -> Void = { _ in }

    /// ジェスチャー開始時点の変形状態（ドラッグとピンチで独立に保持）
    @State private var dragStart: CellTransform?
    @State private var pinchStart: CellTransform?
    /// 入れ替え中の浮き上がり移動量（長押し完了で .zero、指の移動で更新、離すと nil に戻る）
    @GestureState private var liftTranslation: CGSize? = nil

    private var isLifted: Bool { liftTranslation != nil }

    private var imageRatio: CGFloat {
        image.size.height > 0 ? image.size.width / image.size.height : 1
    }

    private var cellRect: CGRect {
        CGRect(origin: .zero, size: cellSize)
    }

    var body: some View {
        let imageRect = CellGeometry.imageRect(
            imageRatio: imageRatio,
            cell: cellRect,
            transform: transform
        )
        ZStack(alignment: .topLeading) {
            Image(uiImage: image)
                .resizable()
                .frame(width: imageRect.width, height: imageRect.height)
                .rotationEffect(.degrees(transform.rotationDegrees))
                .position(x: imageRect.midX, y: imageRect.midY)
        }
        .frame(width: cellSize.width, height: cellSize.height)
        .clipped()
        .overlay {
            if isLifted {
                Rectangle().strokeBorder(.white, lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .scaleEffect(isLifted ? 1.05 : 1)
        .shadow(color: .black.opacity(isLifted ? 0.35 : 0), radius: isLifted ? 12 : 0)
        .offset(liftTranslation ?? .zero)
        .zIndex(isLifted ? 1 : 0)
        .animation(.easeOut(duration: 0.15), value: isLifted)
        .onTapGesture { onTap() }
        .gesture(dragGesture.simultaneously(with: magnifyGesture))
        .if(swapEnabled) { view in
            view.highPriorityGesture(swapGesture)
        }
        .onChange(of: isLifted) { _, lifted in
            if lifted {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }

    /// 長押し(0.5秒)で浮かせてドラッグ → 入れ替え。
    /// 素早いドラッグは長押しが成立せず、通常のパン(dragGesture)に流れる。
    private var swapGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($liftTranslation) { value, state, _ in
                switch value {
                case .second(true, let drag):
                    state = drag?.translation ?? .zero
                default:
                    state = nil
                }
            }
            .onEnded { value in
                if case .second(true, let drag?) = value {
                    onSwapEnded(drag.translation)
                }
            }
    }

    /// ドラッグで上下左右へ移動。オフセットはセル寸法で正規化して保持する。
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = transform
                    onGestureBegan()
                }
                guard let start = dragStart, cellSize.width > 0, cellSize.height > 0 else { return }
                var next = transform
                next.offset = CGSize(
                    width: start.offset.width + value.translation.width / cellSize.width,
                    height: start.offset.height + value.translation.height / cellSize.height
                )
                transform = CellGeometry.clamped(next, imageRatio: imageRatio, cell: cellRect)
            }
            .onEnded { _ in dragStart = nil }
    }

    /// ピンチイン・アウトで拡大縮小（カバー状態が下限）。
    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if pinchStart == nil {
                    pinchStart = transform
                    onGestureBegan()
                }
                guard let start = pinchStart else { return }
                var next = transform
                next.scale = start.scale * value.magnification
                transform = CellGeometry.clamped(next, imageRatio: imageRatio, cell: cellRect)
            }
            .onEnded { _ in pinchStart = nil }
    }
}
