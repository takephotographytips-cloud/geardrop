import SwiftUI

/// Stack Pro のペイウォール（¥980 買い切り・サブスクなし）。
/// 内容: ①プリセット無制限（無料は3つまで） ②デザインフレーム全種
struct ProPaywallView: View {
    let store: PresetStore

    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    hero

                    VStack(spacing: 20) {
                        featureRow(
                            icon: "square.stack.3d.up.fill",
                            title: "プリセット無制限",
                            subtitle: "無料版は3つまで。Pro なら好きなだけ保存できます"
                        )
                        featureRow(
                            icon: "film",
                            title: "デザインフレーム",
                            subtitle: "フィルム・イエロー・シネマ・プリントの4種を解放（グレイン付き）"
                        )
                        featureRow(
                            icon: "rectangle.split.3x1",
                            title: "センターフォーカス",
                            subtitle: "中央の写真を主役にする、雑誌風の全幅レイアウト"
                        )
                        featureRow(
                            icon: "infinity",
                            title: "買い切り",
                            subtitle: "一度きりの購入。サブスクリプションはありません"
                        )
                    }
                    .padding(.horizontal, 4)

                    priceCard

                    ctaButton

                    Button("購入を復元") {
                        Task { await store.restorePurchases() }
                    }
                    .font(.subheadline)

                    Text("お支払いは一度だけです。追加課金・自動更新はありません。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("閉じる")
                }
            }
            .alert(
                "購入できませんでした",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                ),
                actions: { Button("OK") { errorMessage = nil } },
                message: { Text(errorMessage ?? "") }
            )
        }
    }

    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(
                    colors: [Color(white: 0.16), Color(white: 0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            VStack(spacing: 10) {
                Text("STACK PRO")
                    .font(.system(size: 32, weight: .medium, design: .serif))
                    .kerning(5)
                    .foregroundStyle(.white)
                Text("クリエイティブの全機能を解放。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.vertical, 52)
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 32)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var priceCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lifetime")
                    .font(.headline)
                Text("買い切り・一度きりの購入")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(store.displayPrice)
                .font(.title2.weight(.semibold))
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.tint, lineWidth: 2)
        )
    }

    @ViewBuilder
    private var ctaButton: some View {
        if store.isPro {
            Label("購入済み — すべての機能が使えます", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)
        } else {
            Button {
                purchase()
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView()
                    } else {
                        Text("購入する — \(store.displayPrice)")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isPurchasing)
        }
    }

    private func purchase() {
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                try await store.purchasePro()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ProPaywallView(store: PresetStore())
}
