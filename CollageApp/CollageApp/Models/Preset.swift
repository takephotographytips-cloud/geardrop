import Foundation

/// 保存プリセット = レイアウト＋キャンバス設定の組み合わせ。
/// 無料版は3つまで保存でき、Stack Pro（買い切り）で無制限になる。
struct Preset: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var layout: CollageLayout
    var spec: CanvasSpec
    var createdAt: Date = Date()
}
