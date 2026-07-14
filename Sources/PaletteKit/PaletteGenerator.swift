import SwiftUI

/// Generates a palette from a small set of resolution-independent knobs.
///
/// The generator works purely in normalized fractions and is unaware of any concrete color space —
/// it models a palette as a sphere: lightness is the vertical axis, each lightness layer is a disc
/// whose radius (`sqrt(1 - (lightness * 2 - 1)^2)`) shrinks toward the poles, chroma is radial
/// distance from the axis, and hue is the angle around the disc. ``PaletteColor`` realizes the
/// result into displayable colors only when given a ``ColorSpace``.
///
/// Generation is deterministic: the same ``Parameters`` always produce the same colors, in the same
/// order. That's what lets an app persist the recipe instead of the colors, and reproduce a palette
/// exactly after the user discards their manual edits.
@Observable
public final class PaletteGenerator {

    /// The resolution-independent knobs that fully describe a "perfect" palette.
    ///
    /// `Codable` so an app can persist the recipe alongside (or instead of) the generated colors.
    public struct Parameters: Codable, Equatable, Sendable {

        /// The color space the fractions are realized in.
        public var colorSpace: ColorSpace = .okLch

        /// Number of levels of lightness.
        public var lightnessLevels: Int = 5

        /// Rotates each lightness layer.
        public var lightnessTwist = false

        /// Number of levels of chroma.
        public var chromaLevels: Int = 3

        /// Whether the 1st chroma level is just a single grayscale color.
        public var chromaStartsAtZero = true

        /// Chroma multiplier (0.5 = all colors have half the chroma).
        public var chromaMultiplier = 1.0

        /// Number of different hues at the largest chroma level.
        public var maxHueSegments: Int = 12

        /// Whether each hue should be represented in all lightness levels.
        public var continuousHues = true

        /// Rotates each chroma ring.
        public var chromaTwist = false

        /// Rotate the entire palette to pick different hues.
        public var startingHueOffset: Angle = .zero

        public init(
            colorSpace: ColorSpace = .okLch,
            lightnessLevels: Int = 5,
            lightnessTwist: Bool = false,
            chromaLevels: Int = 3,
            chromaStartsAtZero: Bool = true,
            chromaMultiplier: Double = 1.0,
            maxHueSegments: Int = 12,
            continuousHues: Bool = true,
            chromaTwist: Bool = false,
            startingHueOffset: Angle = .zero
        ) {
            self.colorSpace = colorSpace
            self.lightnessLevels = lightnessLevels
            self.lightnessTwist = lightnessTwist
            self.chromaLevels = chromaLevels
            self.chromaStartsAtZero = chromaStartsAtZero
            self.chromaMultiplier = chromaMultiplier
            self.maxHueSegments = maxHueSegments
            self.continuousHues = continuousHues
            self.chromaTwist = chromaTwist
            self.startingHueOffset = startingHueOffset
        }
    }

    public var parameters: Parameters

    public init(_ parameters: Parameters = Parameters()) {
        self.parameters = parameters
    }

    public func generate() -> [PaletteColor] {
        var colors: [PaletteColor] = []
        let lightnessRange = parameters.lightnessLevels == 1 ? [0.5] : Array(stride(from: 0.0, through: 1.0, by: 1.0 / Double(parameters.lightnessLevels-1)))
        let maxLightnessLayerRadius = 1.0
        let maxLightnessLayerCircumference = 2 * .pi * maxLightnessLayerRadius
        let targetCircumferencePerHue = maxLightnessLayerCircumference / Double(parameters.maxHueSegments)

        for lightness in lightnessRange {
            let lightnessLayerRadius = sqrt(1 - pow(lightness * 2 - 1, 2))

            switch lightness {
            case 0, 1:
                colors.append(PaletteColor(lightnessFraction: lightness, chromaFraction: 0, hueAngle: .zero))
            default:
                let chromaStep = parameters.chromaStartsAtZero ? 1 / Double(parameters.chromaLevels-1) : 1 / (Double(parameters.chromaLevels)-0.5)
                let chromaStart = parameters.chromaStartsAtZero ? 0 : chromaStep / 2

                for chroma in stride(from: 1.0, through: chromaStart, by: -chromaStep) { // Start at 1.0 to ensure single chroma level will be 1.0
                    if chroma == 0 {
                        colors.append(PaletteColor(lightnessFraction: lightness, chromaFraction: chroma, hueAngle: .zero))
                    } else {
                        let chromaLayerRadius = chroma * lightnessLayerRadius
                        let chromaLayerCircumference = 2 * .pi * chromaLayerRadius
                        let hueSegments = Int(round(parameters.continuousHues ? Double(parameters.maxHueSegments) * chroma : chromaLayerCircumference / targetCircumferencePerHue))
                        let hueStart = parameters.startingHueOffset.degrees + (parameters.chromaTwist ? (chroma * 360) / Double(hueSegments) : 0) + (parameters.lightnessTwist ? (lightness * 360) / Double(hueSegments) : 0)
                        let hueEnd = hueStart + 360
                        let hueStep = 360 / Double(hueSegments)

                        for hue in stride(from: hueStart, to: hueEnd, by: hueStep) {
                            colors.append(PaletteColor(lightnessFraction: lightness, chromaFraction: chroma * parameters.chromaMultiplier, hueAngle: .degrees(hue)))
                        }
                    }
                }
            }
        }

        return colors
    }

}

public extension PaletteGenerator.Parameters {

    /// A ready-made parameter set, for hosts that want a good palette without exposing every knob.
    ///
    /// This is the lightweight entry point: `Palette.generated(.pastel)` gives Sprite Catalog a
    /// usable palette in one line, while apps that surface the full generator (Palette 3D) keep
    /// driving ``PaletteGenerator/Parameters`` directly.
    enum Preset: String, CaseIterable, Identifiable, Sendable {

        /// Full-chroma colors across the lightness range — the default "perfect palette".
        case vivid
        /// The same shape at low chroma: soft, tinted colors.
        case pastel
        /// Mid-chroma, evenly spaced — safe for UI.
        case muted
        /// A handful of colors: 3 lightness levels, 6 hues.
        case minimal
        /// Many colors: 7 lightness levels, 4 chroma levels, 16 hues, twisted for variety.
        case rich

        public var id: Self { self }

        public var name: String {
            switch self {
            case .vivid: "Vivid"
            case .pastel: "Pastel"
            case .muted: "Muted"
            case .minimal: "Minimal"
            case .rich: "Rich"
            }
        }

        public var parameters: PaletteGenerator.Parameters {
            switch self {
            case .vivid:
                PaletteGenerator.Parameters()
            case .pastel:
                PaletteGenerator.Parameters(lightnessLevels: 5, chromaLevels: 2, chromaMultiplier: 0.4)
            case .muted:
                PaletteGenerator.Parameters(chromaMultiplier: 0.65)
            case .minimal:
                PaletteGenerator.Parameters(lightnessLevels: 3, chromaLevels: 2, maxHueSegments: 6)
            case .rich:
                PaletteGenerator.Parameters(lightnessLevels: 7, chromaLevels: 4, maxHueSegments: 16, chromaTwist: true)
            }
        }
    }
}

public extension Palette {

    /// A palette generated from `parameters`, tagged ``Palette/Source/generated``.
    static func generated(name: String, parameters: PaletteGenerator.Parameters) -> Palette {
        Palette(name: name, colors: PaletteGenerator(parameters).generate(), source: .generated)
    }

    /// A palette generated from a ready-made ``PaletteGenerator/Parameters/Preset``, named after it.
    static func generated(_ preset: PaletteGenerator.Parameters.Preset) -> Palette {
        generated(name: preset.name, parameters: preset.parameters)
    }
}
