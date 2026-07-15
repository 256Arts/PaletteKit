import Foundation
import UniformTypeIdentifiers

public extension Palette {

    /// Every file type a palette can be imported from, for a file importer's `allowedContentTypes`.
    /// `.clr` is macOS-only, matching `NSColorList`.
    static var importableContentTypes: [UTType] {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        [.gimpPalette, .png, .colorList]
        #else
        [.gimpPalette, .png]
        #endif
    }

    /// Reads a palette from any supported file — GIMP `.gpl`, a 1px-tall palette image, or (on macOS)
    /// an `.clr` color list — returning `nil` if the file isn't a palette in any of those formats.
    ///
    /// The file extension only picks which parser to *try first*: a mislabeled file still imports if
    /// its contents parse, so a `.gpl` handed over as `.txt` (or a palette image with no extension)
    /// isn't rejected on a technicality.
    init?(file url: URL, colorSpace: ColorSpace) {
        var parsers: [(URL, ColorSpace) -> Palette?] = [
            { Palette(gplFile: $0, colorSpace: $1) },
            { Palette(paletteImageFile: $0, colorSpace: $1) },
        ]
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        parsers.append { Palette(clrFile: $0, colorSpace: $1) }
        #endif

        // Try the extension's own parser first, then fall back to the others.
        let preferred: Int? = switch url.pathExtension.lowercased() {
        case "gpl": 0
        case "png", "jpg", "jpeg", "gif", "heic": 1
        case "clr": parsers.count - 1
        default: nil
        }
        if let preferred {
            parsers.insert(parsers.remove(at: preferred), at: 0)
        }

        guard let palette = parsers.lazy.compactMap({ $0(url, colorSpace) }).first else { return nil }
        self = palette
    }

    /// A temporary file URL named after the palette, for a `FileRepresentation` export.
    /// The name is path-sanitized, so a palette called "Red / Blue" can't escape the directory.
    func temporaryFileURL(pathExtension: String) -> URL {
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        return URL.temporaryDirectory.appending(component: "\(safeName).\(pathExtension)")
    }

    /// Writes `data` to a temporary file named after the palette, and returns its URL.
    func writeTemporaryFile(_ data: Data, pathExtension: String) throws -> URL {
        let url = temporaryFileURL(pathExtension: pathExtension)
        try data.write(to: url)
        return url
    }
}
