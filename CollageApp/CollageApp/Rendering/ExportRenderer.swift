import ImageIO
import Photos
import UIKit
import UniformTypeIdentifiers

/// フル解像度書き出し（Phase 2、仕様 3.2 レンダリングパイプライン）。
///
/// - 元画像フル解像度を CGContext で合成。メモリ対策として1枚ずつ順次デコード・描画する
/// - 元画像に 10bit 以上のものがあれば 16bit コンテキストで合成（空グラデのバンディング防止）
/// - Display P3 の素材があれば P3 のまま合成（カラースペース維持）
/// - 1枚目の写真の EXIF（撮影日時・カメラ・レンズ）を書き出しへコピー（設定で ON/OFF）
/// - 出力: HEIC（デフォルト）/ JPEG 最高画質（設定で切替）
enum ExportRenderer {

    enum Format: String {
        case heic
        case jpeg

        var utType: UTType { self == .heic ? .heic : .jpeg }
        /// JPEG は仕様どおり最高画質。HEIC は視覚的劣化のない高品質。
        var quality: Double { self == .heic ? 0.9 : 1.0 }
    }

    struct Options {
        var format: Format = .heic
        var preserveEXIF: Bool = true

        static let formatKey = "exportFormat"
        static let preserveEXIFKey = "preserveEXIF"

        /// 設定画面（UserDefaults）から現在値を読む
        static func fromUserDefaults() -> Options {
            let rawFormat = UserDefaults.standard.string(forKey: formatKey) ?? ""
            return Options(
                format: Format(rawValue: rawFormat) ?? .heic,
                preserveEXIF: UserDefaults.standard.object(forKey: preserveEXIFKey) as? Bool ?? true
            )
        }
    }

    enum ExportError: LocalizedError {
        case photoLibraryAccessDenied
        case invalidSource
        case renderingFailed
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .photoLibraryAccessDenied:
                return "フォトライブラリへのアクセスが許可されていません。設定から追加のみのアクセスを許可してください。"
            case .invalidSource:
                return "写真データを読み込めませんでした。"
            case .renderingFailed:
                return "画像の合成に失敗しました。"
            case .encodingFailed:
                return "画像の書き出しに失敗しました。"
            }
        }
    }

    /// 出力長辺の許容範囲。上限はメモリとの兼ね合い
    /// （16bit は 1px あたり 8 バイトのため 8bit より低く抑える）。
    static let minLongSide: CGFloat = 2048
    static let maxLongSide8Bit: CGFloat = 8192
    static let maxLongSide16Bit: CGFloat = 5120

    // MARK: - 書き出し

    /// フル解像度で合成・エンコードし、フォトライブラリに追加する
    /// （追加のみの権限を要求、全権限は要求しない）。
    static func export(
        photoDatas: [Data],
        transforms: [CellTransform],
        layout: CollageLayout,
        spec: CanvasSpec,
        options: Options
    ) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ExportError.photoLibraryAccessDenied
        }

        // 重い合成処理はメインアクター外で実行
        let encoded = try await Task.detached(priority: .userInitiated) {
            try renderEncodedData(
                photoDatas: photoDatas,
                transforms: transforms,
                layout: layout,
                spec: spec,
                options: options
            )
        }.value

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: encoded, options: nil)
        }
    }

    /// 合成してエンコード済みデータ（HEIC / JPEG）を返す。
    static func renderEncodedData(
        photoDatas: [Data],
        transforms: [CellTransform],
        layout: CollageLayout,
        spec: CanvasSpec,
        options: Options
    ) throws -> Data {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        let sources: [CGImageSource] = try photoDatas.map { data in
            guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
                throw ExportError.invalidSource
            }
            return source
        }
        let infos = sources.map(SourceInfo.init)

        // 10bit 以上の素材があれば 16bit で合成（バンディング防止）
        let use16Bit = infos.contains { $0.bitDepth > 8 }
        let longSideRange = minLongSide...(use16Bit ? maxLongSide16Bit : maxLongSide8Bit)
        let longSide = requiredLongSide(
            orientedPixelSizes: infos.map(\.orientedPixelSize),
            transforms: transforms,
            layout: layout,
            spec: spec,
            clampedTo: longSideRange
        )
        let canvasSize = spec.ratio.size(longSide: longSide)
        let width = Int(canvasSize.width.rounded())
        let height = Int(canvasSize.height.rounded())

        // カラースペース維持: P3 素材があれば Display P3 で合成
        let wideGamut = infos.contains(where: \.isWideGamut)
        guard let colorSpace = CGColorSpace(name: wideGamut ? CGColorSpace.displayP3 : CGColorSpace.sRGB) else {
            throw ExportError.renderingFailed
        }

        var contextOrNil = createContext(width: width, height: height, colorSpace: colorSpace, sixteenBit: use16Bit)
        if contextOrNil == nil, use16Bit {
            contextOrNil = createContext(width: width, height: height, colorSpace: colorSpace, sixteenBit: false)
        }
        guard let context = contextOrNil else { throw ExportError.renderingFailed }
        context.interpolationQuality = .high

        // 背景
        let background = spec.background
        context.setFillColor(CGColor(
            srgbRed: background.red,
            green: background.green,
            blue: background.blue,
            alpha: 1
        ))
        context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))

        // 以降はプレビューと同じ「左上原点」座標で扱えるよう反転しておく
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        let cells = layout.cellRects(
            canvasSize: CGSize(width: CGFloat(width), height: CGFloat(height)),
            spec: spec,
            count: photoDatas.count
        )

        // 1枚ずつ順次デコード・描画（フル解像度の同時展開を避ける）
        for (index, source) in sources.enumerated() {
            guard cells.indices.contains(index) else { break }
            try autoreleasepool {
                let info = infos[index]
                let cell = cells[index]
                let transform = transforms.indices.contains(index) ? transforms[index] : CellTransform()
                let pixelSize = info.orientedPixelSize
                guard pixelSize.width > 0, pixelSize.height > 0 else { return }
                let drawRect = CellGeometry.imageRect(
                    imageRatio: pixelSize.width / pixelSize.height,
                    cell: cell,
                    transform: transform
                )
                let decoded = try decode(
                    source: source,
                    info: info,
                    preserveDepth: use16Bit,
                    maxPixelSize: max(drawRect.width, drawRect.height)
                )
                context.saveGState()
                context.clip(to: cell)
                draw(decoded.image, orientation: decoded.orientation, in: drawRect, context: context)
                context.restoreGState()
            }
        }

        guard let outputImage = context.makeImage() else { throw ExportError.renderingFailed }
        return try encode(outputImage, options: options, firstSource: sources.first)
    }

    // MARK: - 出力解像度

    /// 「どの写真も元解像度を超えて引き伸ばされない」出力長辺を求める。
    /// 単位キャンバス（長辺=1）上の描画矩形幅と元画像ピクセル幅の比が
    /// そのままピクセル密度になることを利用する（レイアウト計算は相似）。
    static func requiredLongSide(
        orientedPixelSizes: [CGSize],
        transforms: [CellTransform],
        layout: CollageLayout,
        spec: CanvasSpec,
        clampedTo range: ClosedRange<CGFloat>
    ) -> CGFloat {
        let unitCanvas = spec.ratio.size(longSide: 1)
        let cells = layout.cellRects(canvasSize: unitCanvas, spec: spec, count: orientedPixelSizes.count)
        var required = range.lowerBound
        for (index, pixelSize) in orientedPixelSizes.enumerated() {
            guard cells.indices.contains(index), pixelSize.width > 0, pixelSize.height > 0 else { continue }
            let transform = transforms.indices.contains(index) ? transforms[index] : CellTransform()
            let drawRect = CellGeometry.imageRect(
                imageRatio: pixelSize.width / pixelSize.height,
                cell: cells[index],
                transform: transform
            )
            guard drawRect.width > 0 else { continue }
            required = max(required, pixelSize.width / drawRect.width)
        }
        return min(max(required, range.lowerBound), range.upperBound)
    }

    // MARK: - デコード・描画・エンコード

    private static func createContext(width: Int, height: Int, colorSpace: CGColorSpace, sixteenBit: Bool) -> CGContext? {
        let bitmapInfo: UInt32 = sixteenBit
            ? CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder16Little.rawValue
            : CGImageAlphaInfo.premultipliedLast.rawValue
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: sixteenBit ? 16 : 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )
    }

    /// 写真を1枚デコードする。
    /// - 16bit 合成時（かつ高ビット深度の素材）: ビット深度を保つためフルデコード。
    ///   EXIF 回転は適用されないため、描画時に向きを補正する。
    /// - それ以外: 必要ピクセル数までのダウンサンプルデコード（回転適用済み・省メモリ）。
    private static func decode(
        source: CGImageSource,
        info: SourceInfo,
        preserveDepth: Bool,
        maxPixelSize: CGFloat
    ) throws -> (image: CGImage, orientation: CGImagePropertyOrientation) {
        if preserveDepth, info.bitDepth > 8 {
            let options = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let image = CGImageSourceCreateImageAtIndex(source, 0, options) else {
                throw ExportError.invalidSource
            }
            return (image, info.orientation)
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: ceil(maxPixelSize),
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            throw ExportError.invalidSource
        }
        return (image, .up)
    }

    /// 左上原点に反転済みのコンテキストへ、EXIF 向きを補正しつつ rect に描画する。
    private static func draw(
        _ image: CGImage,
        orientation: CGImagePropertyOrientation,
        in rect: CGRect,
        context: CGContext
    ) {
        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)
        // コンテキスト全体の上下反転を打ち消し、CG 標準の向きで画像を描く
        context.scaleBy(x: 1, y: -1)
        switch orientation {
        case .up:
            break
        case .upMirrored:
            context.scaleBy(x: -1, y: 1)
        case .down:
            context.rotate(by: .pi)
        case .downMirrored:
            context.scaleBy(x: 1, y: -1)
        case .right:
            context.rotate(by: -.pi / 2)
        case .left:
            context.rotate(by: .pi / 2)
        case .leftMirrored:
            context.scaleBy(x: 1, y: -1)
            context.rotate(by: -.pi / 2)
        case .rightMirrored:
            context.scaleBy(x: 1, y: -1)
            context.rotate(by: .pi / 2)
        }
        let swapsDimensions: Bool
        switch orientation {
        case .left, .right, .leftMirrored, .rightMirrored: swapsDimensions = true
        default: swapsDimensions = false
        }
        let drawSize = swapsDimensions
            ? CGSize(width: rect.height, height: rect.width)
            : rect.size
        context.draw(image, in: CGRect(
            x: -drawSize.width / 2,
            y: -drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        ))
        context.restoreGState()
    }

    /// HEIC / JPEG にエンコードし、設定に応じて1枚目の EXIF・TIFF 情報をコピーする。
    private static func encode(
        _ image: CGImage,
        options: Options,
        firstSource: CGImageSource?
    ) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            options.format.utType.identifier as CFString,
            1,
            nil
        ) else {
            throw ExportError.encodingFailed
        }

        var properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: options.format.quality,
        ]
        if options.preserveEXIF,
           let source = firstSource,
           let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            if let exif = sourceProperties[kCGImagePropertyExifDictionary] {
                properties[kCGImagePropertyExifDictionary] = exif
            }
            if var tiff = sourceProperties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
                // キャンバスは常に正立なので向きだけは引き継がない
                tiff.removeValue(forKey: kCGImagePropertyTIFFOrientation)
                properties[kCGImagePropertyTIFFDictionary] = tiff
            }
        }

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ExportError.encodingFailed }
        return data as Data
    }

    // MARK: - ソース情報

    /// デコードせずに ImageIO のプロパティから読み取る元画像の情報。
    private struct SourceInfo {
        let pixelWidth: CGFloat
        let pixelHeight: CGFloat
        let orientation: CGImagePropertyOrientation
        let bitDepth: Int
        let isWideGamut: Bool

        init(source: CGImageSource) {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
            pixelWidth = properties[kCGImagePropertyPixelWidth] as? CGFloat ?? 0
            pixelHeight = properties[kCGImagePropertyPixelHeight] as? CGFloat ?? 0
            orientation = (properties[kCGImagePropertyOrientation] as? UInt32)
                .flatMap(CGImagePropertyOrientation.init) ?? .up
            bitDepth = properties[kCGImagePropertyDepth] as? Int ?? 8
            let profileName = properties[kCGImagePropertyProfileName] as? String ?? ""
            isWideGamut = profileName.contains("P3") || profileName.contains("2020")
        }

        /// EXIF 回転適用後のピクセルサイズ（表示上の縦横）
        var orientedPixelSize: CGSize {
            switch orientation {
            case .left, .right, .leftMirrored, .rightMirrored:
                return CGSize(width: pixelHeight, height: pixelWidth)
            default:
                return CGSize(width: pixelWidth, height: pixelHeight)
            }
        }
    }
}
