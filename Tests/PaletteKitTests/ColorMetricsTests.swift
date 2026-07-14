import ChromaKit
import Testing
@testable import PaletteKit

@Suite("Color metrics")
struct ColorMetricsTests {

    /// Reference pairs from Sharma, Wu & Dalal's CIEDE2000 test data — the standard conformance set.
    /// Passed as raw components because ChromaKit's `Lab` isn't `Sendable`.
    @Test("ΔE₀₀ matches the CIEDE2000 reference data", arguments: [
        (50, 2.6772, -79.7751, 50, 0.0, -82.7485, 2.0425),
        (50, 3.1571, -77.2803, 50, 0.0, -82.7485, 2.8615),
        (50, 2.4900, -0.0010, 50, -2.4900, 0.0009, 7.1792),
        (50, -1.3802, -84.2814, 50, 0.0, -82.7485, 1.0000),
        (60.2574, -34.0099, 36.2677, 60.4626, -34.1751, 39.4387, 1.2644),
    ] as [(Double, Double, Double, Double, Double, Double, Double)])
    func deltaE2000Reference(l1: Double, a1: Double, b1: Double, l2: Double, a2: Double, b2: Double, expected: Double) {
        let deltaE = ColorMetrics.deltaE2000(Lab(l: l1, a: a1, b: b1), Lab(l: l2, a: a2, b: b2))
        #expect(abs(deltaE - expected) < 0.0001)
    }

    @Test("A color has no perceptual difference from itself")
    func deltaE2000Identity() {
        let color = PaletteColor(hex: "#4A90D9", colorSpace: .okLch)!
        #expect(color.deltaE2000(to: color, colorSpace: .okLch) < 0.0001)
    }

    @Test("Black on white is WCAG's maximum 21:1 contrast")
    func contrastExtremes() {
        let white = PaletteColor(hex: "#FFFFFF", colorSpace: .okLch)!
        let black = PaletteColor(hex: "#000000", colorSpace: .okLch)!

        #expect(abs(white.wcagContrast(to: black, colorSpace: .okLch) - 21) < 0.05)
        #expect(abs(white.wcagContrast(to: white, colorSpace: .okLch) - 1) < 0.0001)
        #expect(white.relativeLuminance(colorSpace: .okLch) > black.relativeLuminance(colorSpace: .okLch))
    }

    @Test("Contrast is symmetric regardless of which color is the background")
    func contrastSymmetry() {
        #expect(ColorMetrics.wcagContrast(0.8, 0.1) == ColorMetrics.wcagContrast(0.1, 0.8))
    }

    @Test("A sample carries the color's perceptual coordinates")
    func sampleCoordinates() {
        let red = PaletteColor(hex: "#FF0000", colorSpace: .okLch)!
        let sample = ColorMetrics.sample(red, colorSpace: .okLch)

        #expect(abs(sample.lightness - 53.24) < 0.1)   // CIELab L* of sRGB red.
        #expect(sample.chroma > 100)                   // Red is about as chromatic as sRGB gets.
        #expect(abs(sample.hueDegrees - 40) < 0.1)     // Lab hue of red is ~40°.
        #expect(abs(sample.luminance - 0.2126) < 0.001) // The textbook relative luminance of red.
    }

    @Test("Sampled comparison agrees with comparing the colors directly")
    func sampleAgreesWithDirectComparison() {
        let first = PaletteColor(hex: "#1A1C2C", colorSpace: .okLch)!
        let second = PaletteColor(hex: "#EF7D57", colorSpace: .okLch)!

        let samples = [first, second].map { ColorMetrics.sample($0, colorSpace: .okLch) }

        #expect(abs(ColorMetrics.deltaE2000(samples[0], samples[1]) - first.deltaE2000(to: second, colorSpace: .okLch)) < 0.0001)
        #expect(abs(ColorMetrics.wcagContrast(samples[0], samples[1]) - first.wcagContrast(to: second, colorSpace: .okLch)) < 0.0001)
    }

    @Test("Descriptive stats summarize a sample")
    func descriptiveStats() throws {
        let stats = try #require(DescriptiveStats([2, 4, 4, 4, 5, 5, 7, 9]))

        #expect(stats.mean == 5)
        #expect(stats.median == 4.5)
        #expect(stats.mode == 4)
        #expect(stats.min == 2)
        #expect(stats.max == 9)
        #expect(stats.standardDeviation == 2)
        #expect(DescriptiveStats([]) == nil)
    }
}
