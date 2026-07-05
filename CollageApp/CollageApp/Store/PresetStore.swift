import Foundation
import Observation
import StoreKit

/// プリセットの永続化（JSON、仕様 3.1）と StoreKit 2 によるプリセットパック課金。
/// - ユーザー保存プリセット: Documents/presets.json
/// - パック: 非消耗型 IAP。購入状態は Transaction.currentEntitlements から復元
@Observable
@MainActor
final class PresetStore {

    enum StoreError: LocalizedError {
        case productUnavailable

        var errorDescription: String? {
            "ストア情報を取得できませんでした。通信環境を確認してもう一度お試しください。"
        }
    }

    // MARK: - 状態

    /// ユーザーが保存したプリセット
    private(set) var presets: [Preset] = []
    /// 読み込み済みの App Store 商品（productID キー）
    private(set) var products: [String: Product] = [:]
    /// 購入済みパックの productID
    private(set) var purchasedPackIDs: Set<String> = []

    private let fileURL: URL
    private var transactionListener: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.documentsDirectory.appending(path: "presets.json")
        loadPresets()
        // アプリ外での購入・返金（Ask to Buy 承認など）を反映する常駐リスナー
        transactionListener = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handle(transactionResult: result)
            }
        }
        Task { await self.refreshStore() }
    }

    // MARK: - ユーザープリセット

    func add(_ preset: Preset) {
        presets.append(preset)
        savePresets()
    }

    func remove(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
        savePresets()
    }

    /// ユーザー自身が保存したプリセットか（削除メニューの出し分けに使用）
    func isUserPreset(_ preset: Preset) -> Bool {
        presets.contains { $0.id == preset.id }
    }

    private func loadPresets() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        presets = (try? JSONDecoder().decode([Preset].self, from: data)) ?? []
    }

    private func savePresets() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - プリセットパック（StoreKit 2）

    var packs: [PresetPack] { PresetPack.all }

    func isUnlocked(_ pack: PresetPack) -> Bool {
        purchasedPackIDs.contains(pack.productID)
    }

    var allPacksUnlocked: Bool {
        PresetPack.all.allSatisfy(isUnlocked)
    }

    /// 購入済みパックのプリセット（ホームの一覧に合流させる）
    var unlockedPackPresets: [Preset] {
        PresetPack.all.filter(isUnlocked).flatMap(\.presets)
    }

    /// 表示価格。商品未取得時はプレースホルダ
    func displayPrice(for pack: PresetPack) -> String {
        products[pack.productID]?.displayPrice ?? "¥480"
    }

    func refreshStore() async {
        if let loaded = try? await Product.products(for: PresetPack.all.map(\.productID)) {
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        }
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                purchased.insert(transaction.productID)
            }
        }
        purchasedPackIDs = purchased
    }

    func purchase(_ pack: PresetPack) async throws {
        guard let product = products[pack.productID] else {
            // 商品未取得なら一度だけ再取得を試みる
            await refreshStore()
            guard products[pack.productID] != nil else { throw StoreError.productUnavailable }
            try await purchase(pack)
            return
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                purchasedPackIDs.insert(transaction.productID)
                await transaction.finish()
            }
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    private func handle(transactionResult: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = transactionResult else { return }
        if transaction.revocationDate == nil {
            purchasedPackIDs.insert(transaction.productID)
        } else {
            purchasedPackIDs.remove(transaction.productID)
        }
        await transaction.finish()
    }
}
