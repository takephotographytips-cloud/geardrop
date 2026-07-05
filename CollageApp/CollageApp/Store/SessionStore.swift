import Foundation

/// 編集途中の状態復元（Phase 3、アプリ再起動時）。
/// Application Support/EditSession に写真の元データとメタデータ（設定・変形）を保存する。
/// 写真データは選択時に一度だけ書き、メタデータは編集画面を離れるとき・バックグラウンド移行時に書く。
enum SessionStore {

    /// 復元に必要な編集状態。transforms は写真の表示順。
    struct Snapshot: Codable, Equatable {
        var spec: CanvasSpec
        var layoutIndex: Int
        var transforms: [CellTransform]
        var photoCount: Int
    }

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appending(path: "EditSession", directoryHint: .isDirectory)
    }

    private static var metadataURL: URL {
        directory.appending(path: "session.json")
    }

    private static func photoURL(at index: Int) -> URL {
        directory.appending(path: "photo_\(index).dat")
    }

    static func hasSession() -> Bool {
        FileManager.default.fileExists(atPath: metadataURL.path)
    }

    static func saveMetadata(_ snapshot: Snapshot) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: metadataURL, options: .atomic)
    }

    /// 写真の元データを保存する（古いセッションの写真は削除して置き換え）。
    static func savePhotoDatas(_ datas: [Data]) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var index = 0
        while FileManager.default.fileExists(atPath: photoURL(at: index).path) {
            try? FileManager.default.removeItem(at: photoURL(at: index))
            index += 1
        }
        for (offset, data) in datas.enumerated() {
            try? data.write(to: photoURL(at: offset), options: .atomic)
        }
    }

    /// メタデータと写真データを読み込む。揃っていなければ nil。
    static func load() -> (snapshot: Snapshot, photoDatas: [Data])? {
        guard let metadata = try? Data(contentsOf: metadataURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: metadata),
              snapshot.photoCount > 0 else { return nil }
        var datas: [Data] = []
        for index in 0..<snapshot.photoCount {
            guard let data = try? Data(contentsOf: photoURL(at: index)) else { return nil }
            datas.append(data)
        }
        return (snapshot, datas)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: directory)
    }
}
