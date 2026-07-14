import CoreGraphics
import Foundation
import Testing
@testable import PaletteKit

@Suite("GIMP palette (.gpl)")
struct PaletteGPLTests {

    static let text = """
    GIMP Palette
    Name: Sweetie 16
    Columns: 4
    # Written by a palette editor

      26  28  44 Black
      93  39  93 Purple
     177  62  83
     239 125  87 Orange
    """

    @Test("Parses the name, colors, and per-color names, skipping comments")
    func parse() throws {
        let palette = try #require(Palette(gpl: Self.text, name: "Fallback", colorSpace: .okLch))

        #expect(palette.name == "Sweetie 16")
        #expect(palette.source == .imported)
        #expect(palette.colors.count == 4)
        #expect(palette.colors.map(\.name) == ["Black", "Purple", nil, "Orange"])
        #expect(palette.colors[0].hexString(colorSpace: .okLch) == "#1A1C2C")
        #expect(palette.colors[3].hexString(colorSpace: .okLch) == "#EF7D57")
    }

    @Test("A file with no Name: header falls back to the name it was given")
    func fallbackName() throws {
        let palette = try #require(Palette(gpl: "GIMP Palette\n255 0 0\n", name: "Untitled", colorSpace: .okLch))
        #expect(palette.name == "Untitled")
    }

    @Test("CRLF line endings parse the same as LF")
    func carriageReturns() throws {
        let crlf = Self.text.replacingOccurrences(of: "\n", with: "\r\n")
        let palette = try #require(Palette(gpl: crlf, name: "Fallback", colorSpace: .okLch))

        #expect(palette.name == "Sweetie 16")
        #expect(palette.colors.count == 4)
    }

    @Test("Text without the magic header isn't a GIMP palette", arguments: ["", "255 0 0", "Not A Palette\n255 0 0"])
    func rejectsNonGPL(text: String) {
        #expect(Palette(gpl: text, name: "X", colorSpace: .okLch) == nil)
    }

    @Test("A palette round-trips through .gpl text")
    func roundTrip() throws {
        let original = try #require(Palette(gpl: Self.text, name: "Fallback", colorSpace: .okLch))
        let reparsed = try #require(Palette(gpl: original.gplString(colorSpace: .okLch), name: "Fallback", colorSpace: .okLch))

        #expect(reparsed.name == original.name)
        #expect(reparsed.colors.map { $0.hexString(colorSpace: .okLch) } == original.colors.map { $0.hexString(colorSpace: .okLch) })
        #expect(reparsed.colors.map(\.name) == original.colors.map(\.name))
    }
}

@Suite("Palette image (1px-tall PNG)")
struct PaletteImageTests {

    static let hexes = ["#1A1C2C", "#5D275D", "#B13E53", "#EF7D57", "#FFFFFF", "#000000"]

    static func palette(colorSpace: ColorSpace = .okLch) -> Palette {
        Palette(name: "Sweetie", colors: hexes.map { PaletteColor(hex: $0, colorSpace: colorSpace)! }, source: .premade)
    }

    @Test("Colors round-trip exactly through the 1px image, in order", arguments: ColorSpace.allCases)
    func roundTrip(colorSpace: ColorSpace) throws {
        let colors = Self.palette(colorSpace: colorSpace).colors
        let image = try #require(colors.paletteImage(colorSpace: colorSpace))

        #expect(image.width == colors.count)
        #expect(image.height == 1)

        let decoded = try #require([PaletteColor](paletteImage: image, colorSpace: colorSpace))
        #expect(decoded.map { $0.hexString(colorSpace: colorSpace) } == Self.hexes)
    }

    @Test("An empty palette has no image, and PNG encoding reports it")
    func empty() {
        #expect([PaletteColor]().paletteImage(colorSpace: .okLch) == nil)
        #expect(throws: PaletteImageError.self) {
            try Palette(name: "Empty", colors: []).paletteImagePNGData(colorSpace: .okLch)
        }
    }

    @Test("A taller image isn't a palette image")
    func rejectsTallImage() throws {
        let context = try #require(CGContext(data: nil, width: 4, height: 2, bitsPerComponent: 8, bytesPerRow: 16, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try #require(context.makeImage())

        #expect([PaletteColor](paletteImage: image, colorSpace: .okLch) == nil)
    }

    @Test("A clear pixel invalidates the whole image")
    func rejectsTransparency() throws {
        // A 2px context left fully zeroed — every pixel is clear.
        let context = try #require(CGContext(data: nil, width: 2, height: 1, bitsPerComponent: 8, bytesPerRow: 8, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try #require(context.makeImage())

        #expect([PaletteColor](paletteImage: image, colorSpace: .okLch) == nil)
    }

    @Test("A palette written as a PNG file reads back through the generic file importer")
    func fileRoundTrip() throws {
        let palette = Self.palette()
        let url = try palette.writeTemporaryFile(palette.paletteImagePNGData(colorSpace: .okLch), pathExtension: "png")
        defer { try? FileManager.default.removeItem(at: url) }

        let imported = try #require(Palette(file: url, colorSpace: .okLch))
        #expect(imported.name == "Sweetie")
        #expect(imported.source == .imported)
        #expect(imported.colors.map { $0.hexString(colorSpace: .okLch) } == Self.hexes)
    }
}

@Suite("Lospec")
struct PaletteLospecTests {

    /// The exact shape returned by `lospec.com/palette-list/<slug>.json`.
    static let json = Data("""
    {
      "name": "Sweetie 16",
      "author": "GrafxKid",
      "colors": ["1a1c2c", "5d275d", "b13e53", "ef7d57"]
    }
    """.utf8)

    @Test("Decodes the lospec JSON shape")
    func decode() throws {
        let lospec = try LospecPalette(json: Self.json)

        #expect(lospec.name == "Sweetie 16")
        #expect(lospec.author == "GrafxKid")
        #expect(lospec.colors == ["1a1c2c", "5d275d", "b13e53", "ef7d57"])
    }

    @Test("Only lospec-palette:// URLs with a slug are handled")
    func urlHandling() throws {
        let valid = try #require(URL(string: "lospec-palette://sweetie-16"))
        #expect(LospecPalette.canHandle(valid))
        #expect(LospecPalette.jsonURL(for: valid)?.absoluteString == "https://lospec.com/palette-list/sweetie-16.json")

        #expect(!LospecPalette.canHandle(try #require(URL(string: "lospec-palette://"))))
        #expect(!LospecPalette.canHandle(try #require(URL(string: "https://lospec.com/palette-list/sweetie-16"))))
    }

    @Test("A URL fetches, decodes, and realizes into a palette")
    func fetch() async throws {
        let url = try #require(URL(string: "lospec-palette://sweetie-16"))
        var requested: URL?

        let palette = try await Palette.lospec(url, colorSpace: .okLch) { jsonURL in
            requested = jsonURL
            return Self.json
        }

        #expect(requested?.absoluteString == "https://lospec.com/palette-list/sweetie-16.json")
        #expect(palette.name == "Sweetie 16")
        #expect(palette.source == .imported)
        #expect(palette.colors.map { $0.hexString(colorSpace: .okLch) } == ["#1A1C2C", "#5D275D", "#B13E53", "#EF7D57"])
    }

    @Test("A URL with no slug is a bad URL")
    func fetchBadURL() async throws {
        let url = try #require(URL(string: "lospec-palette://"))
        await #expect(throws: URLError.self) {
            try await Palette.lospec(url, colorSpace: .okLch) { _ in Self.json }
        }
    }
}

#if canImport(AppKit)
@Suite("Color list (.clr)")
struct PaletteColorListTests {

    @Test("A palette round-trips through a .clr file, preserving order")
    func roundTrip() throws {
        let hexes = ["#EF7D57", "#1A1C2C", "#B13E53"] // Deliberately not alphabetical by key.
        let palette = Palette(name: "Ordered", colors: hexes.map { PaletteColor(hex: $0, colorSpace: .okLch)! })

        let url = palette.temporaryFileURL(pathExtension: "clr")
        defer { try? FileManager.default.removeItem(at: url) }
        try palette.writeCLR(to: url, colorSpace: .okLch)

        let imported = try #require(Palette(file: url, colorSpace: .okLch))
        #expect(imported.name == "Ordered")
        #expect(imported.colors.map { $0.hexString(colorSpace: .okLch) } == hexes)
    }
}
#endif

@Suite("Palette files")
struct PaletteFileTests {

    @Test("A .gpl file mislabeled as .txt still imports")
    func mislabeledExtension() throws {
        let url = URL.temporaryDirectory.appending(component: "Mislabeled.txt")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(PaletteGPLTests.text.utf8).write(to: url)

        let palette = try #require(Palette(file: url, colorSpace: .okLch))
        #expect(palette.name == "Sweetie 16")
        #expect(palette.colors.count == 4)
    }

    @Test("A file that isn't a palette in any format fails to import")
    func rejectsGarbage() throws {
        let url = URL.temporaryDirectory.appending(component: "Garbage.gpl")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not a palette".utf8).write(to: url)

        #expect(Palette(file: url, colorSpace: .okLch) == nil)
    }

    @Test("A palette name with a path separator can't escape the temporary directory")
    func sanitizesName() {
        let url = Palette(name: "Red / Blue", colors: []).temporaryFileURL(pathExtension: "gpl")
        #expect(url.lastPathComponent == "Red - Blue.gpl")
        #expect(url.deletingLastPathComponent().path == URL.temporaryDirectory.path)
    }
}
