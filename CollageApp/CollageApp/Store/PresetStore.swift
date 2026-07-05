import Foundation
import Observation

/// プリセットの JSON ファイル永続化（仕様 3.1: 軽量なので JSON で可）。
/// StoreKit 2 のプリセットパック課金は Phase 3 で追加する。
@Observable
final class PresetStore {
    private(set) var presets: [Preset] = []

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.documentsDirectory.appending(path: "presets.json")
        load()
    }

    func add(_ preset: Preset) {
        presets.append(preset)
        save()
    }

    func remove(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        presets = (try? JSONDecoder().decode([Preset].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
