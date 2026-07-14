import Testing
import SwiftUI
@testable import PaletteKit

/// A spread of safely in-gamut sRGB colors used across the round-trip tests.
private let sampleColors: [SRGB8] = [
    SRGB8(red: 0, green: 0, blue: 0),
    SRGB8(red: 255, green: 255, blue: 255),
    SRGB8(red: 128, green: 128, blue: 128),
    SRGB8(red: 26, green: 43, blue: 60),
    SRGB8(red: 200, green: 64, blue: 128),
    SRGB8(red: 34, green: 177, blue: 76),
    SRGB8(red: 255, green: 140, blue: 0),
]

@Suite("SRGB8 hex round-trips")
struct SRGB8HexTests {

    @Test("Hex string round-trips exactly", arguments: sampleColors)
    func hexRoundTrip(color: SRGB8) {
        let hex = color.hexString
        #expect(SRGB8(hex: hex) == color)
    }

    @Test("Parsing accepts leading '#', a bare string, and is case-insensitive")
    func hexParsingForms() {
        #expect(SRGB8(hex: "#1A2B3C") == SRGB8(red: 0x1A, green: 0x2B, blue: 0x3C))
        #expect(SRGB8(hex: "1a2b3c") == SRGB8(red: 0x1A, green: 0x2B, blue: 0x3C))
        #expect(SRGB8(hex: "#1a2b3c")?.hexString == "#1A2B3C")
    }

    @Test("Malformed hex strings fail to parse", arguments: ["", "#12", "GGGGGG", "1234567", "#12345"])
    func rejectsBadHex(input: String) {
        #expect(SRGB8(hex: input) == nil)
    }
}

@Suite("PaletteColor sRGB round-trips")
struct PaletteColorSRGBTests {

    /// sRGB → perceptual fractions → sRGB should return within a single 8-bit step in every color space.
    @Test(arguments: sampleColors, ColorSpace.allCases)
    func srgb8RoundTrip(color: SRGB8, colorSpace: ColorSpace) {
        let round = PaletteColor(color, colorSpace: colorSpace).srgb8(colorSpace: colorSpace)
        #expect(abs(Int(round.red) - Int(color.red)) <= 1)
        #expect(abs(Int(round.green) - Int(color.green)) <= 1)
        #expect(abs(Int(round.blue) - Int(color.blue)) <= 1)
    }

    @Test("Hex init matches the SRGB8 bridge", arguments: ColorSpace.allCases)
    func hexInitMatchesBridge(colorSpace: ColorSpace) throws {
        let fromHex = try #require(PaletteColor(hex: "#C84080", colorSpace: colorSpace))
        let fromSRGB = PaletteColor(SRGB8(hex: "#C84080")!, colorSpace: colorSpace)
        #expect(fromHex == fromSRGB)
    }

    @Test("hexString clamps and round-trips an in-gamut color", arguments: sampleColors)
    func hexStringRoundTrip(color: SRGB8) {
        let paletteColor = PaletteColor(color, colorSpace: .lab)
        #expect(SRGB8(hex: paletteColor.hexString(colorSpace: .lab)) == paletteColor.srgb8(colorSpace: .lab))
    }
}

@Suite("PaletteColor Lab/Lch round-trips")
struct PaletteColorPerceptualTests {

    /// Realizing a color to P3 and re-deriving its fractions in the same space must reproduce the fractions.
    @Test(arguments: ColorSpace.allCases)
    func fractionsRoundTripThroughP3(colorSpace: ColorSpace) {
        let original = PaletteColor(SRGB8(red: 200, green: 64, blue: 128), colorSpace: colorSpace)
        let rebuilt = PaletteColor(original.p3(colorSpace: colorSpace), colorSpace: colorSpace)
        #expect(abs(original.lightnessFraction - rebuilt.lightnessFraction) < 1e-6)
        #expect(abs(original.chromaFraction - rebuilt.chromaFraction) < 1e-6)
        // Compare hue as a point on the unit circle so 359.9° ≈ 0° doesn't spuriously fail.
        #expect(abs(original.normalizedA - rebuilt.normalizedA) < 1e-6)
        #expect(abs(original.normalizedB - rebuilt.normalizedB) < 1e-6)
    }

    /// lch()/oklch() CSS text parses back into an equivalent color (lab/oklab are output-only).
    @Test("CSS lch round-trips through init(css:)")
    func cssLchRoundTrip() throws {
        for colorSpace in [ColorSpace.lch, .okLch] {
            let original = PaletteColor(SRGB8(red: 90, green: 160, blue: 210), colorSpace: colorSpace)
            let css = original.cssString(colorSpace: colorSpace, convertedToP3: false)
            let parsed = try #require(PaletteColor(css: css))
            #expect(abs(parsed.lightnessFraction - original.lightnessFraction) < 1e-3)
            #expect(abs(parsed.chromaFraction - original.chromaFraction) < 1e-3)
            #expect(abs(parsed.normalizedA - original.normalizedA) < 1e-3)
            #expect(abs(parsed.normalizedB - original.normalizedB) < 1e-3)
        }
    }
}

@Suite("Palette value semantics")
struct PaletteTests {

    @Test("Palette round-trips through Codable")
    func codableRoundTrip() throws {
        let palette = Palette(
            name: "Test",
            colors: [
                PaletteColor(SRGB8(hex: "#FF0000")!, name: "Red", colorSpace: .okLch),
                PaletteColor(SRGB8(hex: "#00FF00")!, colorSpace: .okLch),
            ],
            groupLengths: [1, 1],
            source: .premade
        )
        let data = try JSONEncoder().encode(palette)
        let decoded = try JSONDecoder().decode(Palette.self, from: data)
        #expect(decoded == palette)
    }

    @Test("Identity distinguishes palettes with matching contents")
    func distinctIdentity() {
        let colors = [PaletteColor(SRGB8(hex: "#123456")!, colorSpace: .lab)]
        let a = Palette(name: "A", colors: colors)
        let b = Palette(name: "A", colors: colors)
        #expect(a.id != b.id)
        #expect(a != b)
    }
}
