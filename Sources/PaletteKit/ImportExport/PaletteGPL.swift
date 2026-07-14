import SwiftUI
import UniformTypeIdentifiers

public extension UTType {
    /// The GIMP palette (`.gpl`) file type.
    static var gimpPalette: UTType { UTType(filenameExtension: "gpl") ?? .plainText }
}

public extension Palette {

    /// Parses GIMP Palette (v1 or v2) text, realizing each color in the given color space.
    /// Returns `nil` if the required `GIMP Palette` magic header is missing.
    /// - Parameter name: The palette name to fall back on when the file declares none.
    init?(gpl text: String, name: String, colorSpace: ColorSpace) {
        // Split on any newline, not just "\n": Swift reads a CRLF as one grapheme cluster, so
        // splitting on "\n" alone would never break a Windows-authored file into lines at all.
        var lines = text.split(whereSeparator: \.isNewline).map(String.init)

        guard lines.first?.trimmingCharacters(in: .whitespaces) == "GIMP Palette" else { return nil }
        lines.removeFirst()

        var declaredName: String?
        var colors: [PaletteColor] = []

        for line in lines {
            if line.isEmpty || line.hasPrefix("#") {
                continue // Blank lines and comments are ignored anywhere in the file.
            } else if let value = line.headerValue(prefix: "Name:") {
                declaredName = value
            } else if line.headerValue(prefix: "Columns:") != nil {
                continue // Column count only affects GIMP's own layout; we don't use it.
            } else if let color = PaletteColor(gplColorLine: line, colorSpace: colorSpace) {
                colors.append(color)
            }
        }

        self.init(
            name: declaredName?.isEmpty == false ? declaredName! : name,
            colors: colors,
            source: .imported)
    }

    /// Reads a palette from a `.gpl` file, or `nil` if it isn't a GIMP palette.
    /// Falls back to the file name when the file declares no name of its own.
    init?(gplFile url: URL, colorSpace: ColorSpace) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        self.init(gpl: text, name: url.deletingPathExtension().lastPathComponent, colorSpace: colorSpace)
    }

    /// This palette as GIMP Palette v2 text, realized in sRGB.
    /// - Parameter columns: GIMP's preferred display column count; `0` means flowing (variable).
    func gplString(colorSpace: ColorSpace, columns: Int = 0) -> String {
        var lines = ["GIMP Palette", "Name: \(name)", "Columns: \(columns)", "#"]
        lines += colors.map { $0.gplLine(colorSpace: colorSpace) }
        return lines.joined(separator: "\n") + "\n"
    }
}

private extension StringProtocol {
    /// The trimmed value following a header `prefix` (e.g. `Name:`), or `nil` if the line isn't that header.
    func headerValue(prefix: String) -> String? {
        guard hasPrefix(prefix) else { return nil }
        return String(dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }
}

public extension PaletteColor {

    /// Parses one GIMP color line (`r g b optional name`), or `nil` if it doesn't start with three integers.
    init?(gplColorLine line: String, colorSpace: ColorSpace) {
        let scanner = Scanner(string: line)
        guard let r = scanner.scanInt(), let g = scanner.scanInt(), let b = scanner.scanInt() else { return nil }
        let name = String(line[scanner.currentIndex...]).trimmingCharacters(in: .whitespaces)
        self.init(sRGB8BitRed: r, green: g, blue: b, name: name.isEmpty ? nil : name, colorSpace: colorSpace)
    }

    /// This color as a GIMP color line (`r g b [name]`), realized and clamped to 8-bit sRGB.
    func gplLine(colorSpace: ColorSpace) -> String {
        let (r, g, b) = srgb8Bit(colorSpace: colorSpace)
        let components = String(format: "%3d %3d %3d", r, g, b)
        return name.map { "\(components) \($0)" } ?? components
    }
}

/// A palette shared out as a `.gpl` file. Cross-platform (plain text).
public struct GIMPPaletteExport: Transferable {

    public let palette: Palette
    public let colorSpace: ColorSpace

    public init(palette: Palette, colorSpace: ColorSpace) {
        self.palette = palette
        self.colorSpace = colorSpace
    }

    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .gimpPalette) { export in
            let text = export.palette.gplString(colorSpace: export.colorSpace)
            return SentTransferredFile(try export.palette.writeTemporaryFile(Data(text.utf8), pathExtension: "gpl"))
        }
    }
}
