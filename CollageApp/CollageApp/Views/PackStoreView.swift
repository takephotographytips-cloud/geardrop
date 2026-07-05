import SwiftUI

/// プリセットパックの購入画面（StoreKit 2 非消耗型、買い切り）。
struct PackStoreView: View {
    let store: PresetStore

    @Environment(\.dismiss) private var dismiss
    @State private var purchasingID: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("買い切りのプリセットパックです。一度購入すればずっと使えます（サブスクリプションはありません）。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ForEach(store.packs) { pack in
                    Section(pack.name) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(pack.tagline)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            ForEach(pack.presets) { preset in
                                Label(
                                    "\(preset.name)（\(preset.spec.ratio.rawValue)・\(preset.layout.displayName)）",
                                    systemImage: preset.layout.symbolName
                                )
                                .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)

                        purchaseRow(for: pack)
                    }
                }

                Section {
                    Button("購入を復元") {
                        Task { await store.restorePurchases() }
                    }
                }
            }
            .navigationTitle("プリセットパック")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
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

    @ViewBuilder
    private func purchaseRow(for pack: PresetPack) -> some View {
        if store.isUnlocked(pack) {
            Label("購入済み", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Button {
                purchase(pack)
            } label: {
                HStack {
                    Text("購入する")
                    Spacer()
                    if purchasingID == pack.productID {
                        ProgressView()
                    } else {
                        Text(store.displayPrice(for: pack))
                            .fontWeight(.semibold)
                    }
                }
            }
            .disabled(purchasingID != nil)
        }
    }

    private func purchase(_ pack: PresetPack) {
        purchasingID = pack.productID
        Task {
            defer { purchasingID = nil }
            do {
                try await store.purchase(pack)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    PackStoreView(store: PresetStore())
}
