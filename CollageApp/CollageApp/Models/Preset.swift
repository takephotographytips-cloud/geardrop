import Foundation

/// 保存プリセット = レイアウト＋キャンバス設定の組み合わせ（仕様 1.4）。
/// Phase 1 ではモデルと永続化の器のみ用意し、保存/呼び出し UI は Phase 3 で実装する。
struct Preset: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var layout: CollageLayout
    var spec: CanvasSpec
    var createdAt: Date = Date()
}
