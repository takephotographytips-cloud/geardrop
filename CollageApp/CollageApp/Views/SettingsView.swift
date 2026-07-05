import SwiftUI

/// 設定（仕様 2.2: 書き出し画質・EXIF 保持 ON/OFF のみの最小構成）。
struct SettingsView: View {
    @AppStorage(ExportRenderer.Options.formatKey)
    private var formatRaw = ExportRenderer.Format.heic.rawValue
    @AppStorage(ExportRenderer.Options.preserveEXIFKey)
    private var preserveEXIF = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("書き出し形式", selection: $formatRaw) {
                        Text("HEIC（推奨）").tag(ExportRenderer.Format.heic.rawValue)
                        Text("JPEG 最高画質").tag(ExportRenderer.Format.jpeg.rawValue)
                    }
                } footer: {
                    Text("HEIC は高画質のままファイルサイズを抑えられます。他アプリとの互換性を重視する場合は JPEG を選んでください。")
                }

                Section {
                    Toggle("EXIF情報を保持", isOn: $preserveEXIF)
                } footer: {
                    Text("1枚目の写真の撮影日時・カメラ・レンズ情報を、書き出した画像にコピーします。")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
