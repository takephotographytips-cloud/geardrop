import SwiftUI

extension BackgroundColorChoice {
    var color: Color {
        let rgba = rgba
        return Color(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }
}

/// キャンバスプレビュー。CollageLayout の矩形計算をそのまま描画する。
struct CollageCanvasView: View {
    let photos: [EditorViewModel.Photo]
    let layout: CollageLayout
    let spec: CanvasSpec

    var body: some View {
        GeometryReader { geometry in
            let rects = layout.photoRects(
                canvasSize: geometry.size,
                spec: spec,
                aspectRatios: photos.map(\.aspectRatio)
            )
            ZStack {
                spec.background.color
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    if rects.indices.contains(index) {
                        Image(uiImage: photo.image)
                            .resizable()
                            .frame(width: rects[index].width, height: rects[index].height)
                            .position(x: rects[index].midX, y: rects[index].midY)
                    }
                }
            }
        }
        .aspectRatio(spec.ratio.value, contentMode: .fit)
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }
}

/// タップ2: レイアウト候補の横スワイプカルーセル（ドット表示、仕様 2.2）。
/// 探させず提示する — 候補をページとして横スワイプで切り替える。
struct LayoutCarousel: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        TabView(selection: $viewModel.layoutIndex) {
            ForEach(Array(viewModel.layouts.enumerated()), id: \.offset) { index, layout in
                VStack(spacing: 12) {
                    CollageCanvasView(
                        photos: viewModel.photos,
                        layout: layout,
                        spec: viewModel.spec
                    )
                    .padding(.horizontal, 24)

                    Text(layout.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 32)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}
