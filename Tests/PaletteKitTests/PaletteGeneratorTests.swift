import ChromaKit
import SwiftUI
import Testing
@testable import PaletteKit

@Suite("Palette generator")
struct PaletteGeneratorTests {

    @Test("The same parameters always generate the same colors")
    func determinism() {
        let parameters = PaletteGenerator.Parameters(lightnessLevels: 6, chromaLevels: 4, maxHueSegments: 9, chromaTwist: true, startingHueOffset: .degrees(33))
        let first = PaletteGenerator(parameters).generate()
        let second = PaletteGenerator(parameters).generate()

        #expect(first == second)
        #expect(!first.isEmpty)
    }

    @Test("The lightness poles are pure black and pure white")
    func poles() {
        let colors = PaletteGenerator().generate()

        #expect(colors.first == PaletteColor(lightnessFraction: 0, chromaFraction: 0, hueAngle: .zero))
        #expect(colors.last == PaletteColor(lightnessFraction: 1, chromaFraction: 0, hueAngle: .zero))
    }

    @Test("A single lightness level generates one mid-lightness layer")
    func singleLightnessLevel() {
        var parameters = PaletteGenerator.Parameters()
        parameters.lightnessLevels = 1
        let colors = PaletteGenerator(parameters).generate()

        #expect(colors.allSatisfy { $0.lightnessFraction == 0.5 })
        #expect(!colors.isEmpty)
    }

    @Test("The chroma multiplier scales every color's chroma")
    func chromaMultiplier() {
        let full = PaletteGenerator.Parameters()
        var half = full
        half.chromaMultiplier = 0.5

        let fullColors = PaletteGenerator(full).generate()
        let halfColors = PaletteGenerator(half).generate()

        #expect(fullColors.count == halfColors.count)
        for (whole, halved) in zip(fullColors, halfColors) {
            #expect(halved.chromaFraction.isApproximately(whole.chromaFraction / 2))
            #expect(halved.lightnessFraction == whole.lightnessFraction)
        }
    }

    @Test("The starting hue offset rotates every chromatic color", arguments: [45.0, 180.0])
    func startingHueOffset(degrees: Double) {
        var rotated = PaletteGenerator.Parameters()
        rotated.startingHueOffset = .degrees(degrees)

        let base = PaletteGenerator().generate()
        let colors = PaletteGenerator(rotated).generate()

        #expect(base.count == colors.count)
        for (original, moved) in zip(base, colors) where original.chromaFraction > 0 {
            #expect(moved.hueAngle.degrees.isApproximately(original.hueAngle.degrees + degrees))
        }
    }

    @Test("Every preset generates colors, and vivid matches the default parameters")
    func presets() {
        for preset in PaletteGenerator.Parameters.Preset.allCases {
            let palette = Palette.generated(preset)
            #expect(!palette.colors.isEmpty, "\(preset.name) generated nothing")
            #expect(palette.name == preset.name)
            #expect(palette.source == .generated)
        }
        #expect(PaletteGenerator.Parameters.Preset.vivid.parameters == PaletteGenerator.Parameters())
        #expect(Palette.generated(.minimal).colors.count < Palette.generated(.rich).colors.count)
    }

    @Test("Every generated value stays inside its normalized range")
    func valuesWithinRange() {
        let colors = PaletteGenerator().generate()

        #expect(colors.allSatisfy { (0...1).contains($0.chromaFraction) })
        #expect(colors.allSatisfy { (-1...1).contains($0.normalizedA) && (-1...1).contains($0.normalizedB) })
        // The sphere coordinates drive the 3D view; a value outside the unit sphere would place a
        // color off the model.
        #expect(colors.allSatisfy { (-1...1).contains($0.visualizedX) })
        #expect(colors.allSatisfy { (-1...1).contains($0.visualizedY) })
        #expect(colors.allSatisfy { (-1...1).contains($0.visualizedZ) })
    }

    @Test("Parameters round-trip through Codable, so an app can persist the recipe")
    func parametersCodable() throws {
        let parameters = PaletteGenerator.Parameters(colorSpace: .lch, lightnessLevels: 4, lightnessTwist: true, chromaLevels: 2, chromaStartsAtZero: false, chromaMultiplier: 0.75, maxHueSegments: 7, continuousHues: false, chromaTwist: true, startingHueOffset: .degrees(120))
        let decoded = try JSONDecoder().decode(PaletteGenerator.Parameters.self, from: JSONEncoder().encode(parameters))

        #expect(decoded == parameters)
        #expect(PaletteGenerator(decoded).generate() == PaletteGenerator(parameters).generate())
    }
}

extension Double {
    /// Floating-point equality with a tolerance, for values that survived trig and scaling.
    func isApproximately(_ other: Double, tolerance: Double = 1e-9) -> Bool {
        abs(self - other) < tolerance
    }
}
