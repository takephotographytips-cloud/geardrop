import Foundation
import Observation
import StoreKit

/// プリセットの永続化（JSON、仕様 3.1）と StoreKit 2 による「Stack Pro」課金。
/// - ユーザー保存プリセット: Documents/presets.json（無料は3つまで、Pro で無制限）
/// - Stack Pro: 非消耗型 IAP（¥980 買い切り）。プリセット無制限＋デザインフレームを解放
@Observable
@MainActor
final class PresetStore {

    static let proProductID = "com.dstudio.collageapp.pro"
    /// 無料版で保存できるプリセット数
    static let freePresetLimit = 3

    enum StoreError: LocalizedError {
        case productUnavailable

        var errorDescription: String? {
            "ストア情報を取得できませんでした。通信環境を確認してもう一度お試しください。"
        }
    }

    // MARK: - 状態

    /// ユーザーが保存したプリセット
    private(set) var presets: [Preset] = []
    /// Stack Pro の App Store 商品
    private(set) var proProduct: Product?
    /// 購入済み productID
    private(set) var purchasedProductIDs: Set<String> = []

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

    // MARK: - Pro 判定

    var isPro: Bool {
        purchasedProductIDs.contains(Self.proProductID)
    }

    /// プリセットをこれ以上保存できるか（無料3つ制限）
    var canAddPreset: Bool {
        Self.canAddPreset(currentCount: presets.count, isPro: isPro)
    }

    static func canAddPreset(currentCount: Int, isPro: Bool) -> Bool {
        isPro || currentCount < freePresetLimit
    }

    /// 表示価格。商品未取得時はプレースホルダ
    var displayPrice: String {
        proProduct?.displayPrice ?? "¥980"
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

    private func loadPresets() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        presets = (try? JSONDecoder().decode([Preset].self, from: data)) ?? []
    }

    private func savePresets() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - StoreKit 2

    func refreshStore() async {
        if let loaded = try? await Product.products(for: [Self.proProductID]) {
            proProduct = loaded.first
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
        purchasedProductIDs = purchased
    }

    func purchasePro() async throws {
        if proProduct == nil {
            await refreshStore()
        }
        guard let product = proProduct else { throw StoreError.productUnavailable }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                purchasedProductIDs.insert(transaction.productID)
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
            purchasedProductIDs.insert(transaction.productID)
        } else {
            purchasedProductIDs.remove(transaction.productID)
        }
        await transaction.finish()
    }
}
