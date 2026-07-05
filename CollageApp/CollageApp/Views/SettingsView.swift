import SwiftUI

/// 設定（仕様 2.2 の最小構成 + Pro 導線）。
/// 書き出し設定 / Stack Pro（アップグレード・購入復元）/ バージョン
struct SettingsView: View {
    let store: PresetStore

    @AppStorage(ExportRenderer.Options.formatKey)
    private var formatRaw = ExportRenderer.Format.heic.rawValue
    @AppStorage(ExportRenderer.Options.preserveEXIFKey)
    private var preserveEXIF = true
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("書き出し形式", selection: $formatRaw) {
                        Text("HEIC（推奨）").tag(ExportRenderer.Format.heic.rawValue)
                        Text("JPEG 最高画質").tag(ExportRenderer.Format.jpeg.rawValue)
                    }
                    Toggle("EXIF情報を保持", isOn: $preserveEXIF)
                } footer: {
                    Text("EXIF: 1枚目の写真の撮影日時・カメラ・レンズ情報を書き出した画像にコピーします。")
                }

                Section {
                    if store.isPro {
                        Label("Stack Pro 購入済み", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Label("Stack Pro にアップグレード", systemImage: "sparkles")
                                Spacer()
                                Text(store.displayPrice)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button("購入を復元") {
                        Task { await store.restorePurchases() }
                    }
                } footer: {
                    Text("Stack Pro（買い切り）: プリセット無制限＋デザインフレーム。サブスクリプションはありません。")
                }

                Section {
                    LabeledContent("バージョン", value: appVersion)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                ProPaywallView(store: store)
            }
        }
    }
}

#Preview {
    SettingsView(store: PresetStore())
}
