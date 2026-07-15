// Catalyst can import AppKit but marks NSColorList unavailable, so exclude it too.
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

public extension UTType {
    /// The `.clr` NSColorList file type.
    static var colorList: UTType { UTType(filenameExtension: "clr") ?? .data }
}

public extension Palette {

    /// Loads a palette from an `NSColorList`, interpreting each color in the given color space.
    init(_ colorList: NSColorList, name: String, colorSpace: ColorSpace) {
        let colors = colorList.allKeys.compactMap { key in
            colorList.color(withKey: key).flatMap { PaletteColor($0, colorSpace: colorSpace) }
        }
        self.init(name: name, colors: colors, source: .imported)
    }

    /// Loads a palette from a `.clr` file, named after the file, or `nil` if it can't be read as a color list.
    init?(clrFile url: URL, colorSpace: ColorSpace) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        let name = url.deletingPathExtension().lastPathComponent
        guard let colorList = NSColorList(name: name, fromFile: url.path) else { return nil }
        self.init(colorList, name: name, colorSpace: colorSpace)
    }

    /// This palette realized as an ordered `NSColorList` — keys are zero-padded indices, so the
    /// color list preserves the palette's order rather than sorting by name.
    func colorList(colorSpace: ColorSpace) -> NSColorList {
        let colorList = NSColorList(name: name)
        for (index, color) in colors.enumerated() {
            colorList.setColor(color.systemColor(colorSpace: colorSpace), forKey: String(format: "%04d", index))
        }
        return colorList
    }

    /// Writes the palette to a `.clr` file, realized in the given color space.
    func writeCLR(to url: URL, colorSpace: ColorSpace) throws {
        try colorList(colorSpace: colorSpace).write(to: url)
    }
}

/// A palette dragged out (e.g. to Finder) as a re-importable `.clr` file, or as CSS text.
/// macOS-only, matching `NSColorList`.
public struct PaletteColorListExport: Transferable {

    public let palette: Palette
    public let colorSpace: ColorSpace

    public init(palette: Palette, colorSpace: ColorSpace) {
        self.palette = palette
        self.colorSpace = colorSpace
    }

    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .colorList) { export in
            let url = export.palette.temporaryFileURL(pathExtension: "clr")
            try export.palette.writeCLR(to: url, colorSpace: export.colorSpace)
            return SentTransferredFile(url)
        }
        ProxyRepresentation { export in
            PaletteColor.cssText(export.palette.colors, colorSpace: export.colorSpace, convertedToP3: false)
        }
    }
}
#endif
