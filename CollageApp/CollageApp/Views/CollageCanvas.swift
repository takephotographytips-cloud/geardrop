import SwiftUI

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

/// キャンバスプレビュー（Instagram / Canva 型）。
/// セル（枠）は固定で、各セル内の写真だけをドラッグ移動・ピンチ拡大縮小できる。
struct CollageCanvasView: View {
    @Bindable var viewModel: EditorViewModel

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
                            onGestureBegan: { viewModel.registerUndoSnapshot() }
                        )
                        .frame(width: cell.width, height: cell.height)
                        .position(x: cell.midX, y: cell.midY)
                    }
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

    /// セルごとの変形状態への Binding（未編集セルはデフォルト = カバー・中央）
    private func transformBinding(for id: UUID) -> Binding<CellTransform> {
        Binding {
            viewModel.transforms[id] ?? CellTransform()
        } set: { newValue in
            viewModel.transforms[id] = newValue
        }
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
    var onGestureBegan: () -> Void

    /// ジェスチャー開始時点の変形状態（ドラッグとピンチで独立に保持）
    @State private var dragStart: CellTransform?
    @State private var pinchStart: CellTransform?

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
                .position(x: imageRect.midX, y: imageRect.midY)
        }
        .frame(width: cellSize.width, height: cellSize.height)
        .clipped()
        .contentShape(Rectangle())
        .gesture(dragGesture.simultaneously(with: magnifyGesture))
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
