import ChromaKit
import Foundation

/// Perceptual difference and contrast math over realized colors.
///
/// These are pure functions over CIELab values, deliberately kept off ``PaletteColor``: an analysis
/// pass converts each color to Lab *once* and then compares every pair, so the O(n²) loop never pays
/// for a color-space conversion. For one-off comparisons, the `PaletteColor` conveniences below are
/// the readable form.
public enum ColorMetrics {

    /// CIELab and WCAG relative luminance (white = 1, black = 0) for a display-P3 color.
    public static func labAndLuminance(_ p3: P3) -> (lab: Lab, luminance: Double) {
        let xyz = XYZ(p3)
        return (Lab(xyz), max(0, xyz.y))
    }

    /// WCAG 2.1 contrast ratio (1–21) from two relative luminances (white = 1, black = 0).
    public static func wcagContrast(_ y1: Double, _ y2: Double) -> Double {
        (max(y1, y2) + 0.05) / (min(y1, y2) + 0.05)
    }

    /// CIEDE2000 (ΔE₀₀) perceptual color difference between two CIELab colors.
    public static func deltaE2000(_ lab1: Lab, _ lab2: Lab) -> Double {
        let (kL, kC, kH) = (1.0, 1.0, 1.0)

        let c1 = hypot(lab1.a, lab1.b)
        let c2 = hypot(lab2.a, lab2.b)
        let cBar = (c1 + c2) / 2
        let g = 0.5 * (1 - sqrt(pow(cBar, 7) / (pow(cBar, 7) + pow(25.0, 7))))

        let a1p = (1 + g) * lab1.a
        let a2p = (1 + g) * lab2.a
        let c1p = hypot(a1p, lab1.b)
        let c2p = hypot(a2p, lab2.b)

        func hue(_ b: Double, _ ap: Double) -> Double {
            if b == 0 && ap == 0 { return 0 }
            let h = atan2(b, ap) * 180 / .pi
            return h < 0 ? h + 360 : h
        }
        let h1p = hue(lab1.b, a1p)
        let h2p = hue(lab2.b, a2p)

        let dLp = lab2.l - lab1.l
        let dCp = c2p - c1p

        let dhp: Double
        if c1p * c2p == 0 {
            dhp = 0
        } else if h2p - h1p > 180 {
            dhp = h2p - h1p - 360
        } else if h2p - h1p < -180 {
            dhp = h2p - h1p + 360
        } else {
            dhp = h2p - h1p
        }
        let dHp = 2 * sqrt(c1p * c2p) * sin(dhp * .pi / 180 / 2)

        let lBarp = (lab1.l + lab2.l) / 2
        let cBarp = (c1p + c2p) / 2

        let hBarp: Double
        if c1p * c2p == 0 {
            hBarp = h1p + h2p
        } else if abs(h1p - h2p) > 180 {
            hBarp = (h1p + h2p + 360) / 2
        } else {
            hBarp = (h1p + h2p) / 2
        }

        let t = 1
            - 0.17 * cos((hBarp - 30) * .pi / 180)
            + 0.24 * cos((2 * hBarp) * .pi / 180)
            + 0.32 * cos((3 * hBarp + 6) * .pi / 180)
            - 0.20 * cos((4 * hBarp - 63) * .pi / 180)

        let dTheta = 30 * exp(-pow((hBarp - 275) / 25, 2))
        let rC = 2 * sqrt(pow(cBarp, 7) / (pow(cBarp, 7) + pow(25.0, 7)))
        let sL = 1 + (0.015 * pow(lBarp - 50, 2)) / sqrt(20 + pow(lBarp - 50, 2))
        let sC = 1 + 0.045 * cBarp
        let sH = 1 + 0.015 * cBarp * t
        let rT = -sin(2 * dTheta * .pi / 180) * rC

        let termL = dLp / (kL * sL)
        let termC = dCp / (kC * sC)
        let termH = dHp / (kH * sH)
        return sqrt(termL * termL + termC * termC + termH * termH + rT * termC * termH)
    }
}

public extension ColorMetrics {

    /// A color converted once, ready for repeated comparison.
    ///
    /// An analysis pass compares every pair of colors, so it converts each color to Lab exactly once
    /// and then works in samples — O(n) conversions for an O(n²) comparison. Hosts get the derived
    /// perceptual coordinates without importing ChromaKit or handling `Lab` themselves.
    struct Sample: Hashable, Sendable {

        /// CIELab lightness, 0 (black) – 100 (white).
        public let lightness: Double
        /// CIELab chroma — distance from the neutral axis. 0 is gray; ~130 is as saturated as real colors get.
        public let chroma: Double
        /// CIELab hue angle, 0–360°.
        public let hueDegrees: Double
        /// WCAG relative luminance (white = 1, black = 0).
        public let luminance: Double

        /// The Lab cartesian axes, kept so ΔE₀₀ doesn't have to re-derive them from chroma and hue.
        let a: Double, b: Double

        fileprivate init(lab: Lab, luminance: Double) {
            self.lightness = lab.l
            self.a = lab.a
            self.b = lab.b
            self.chroma = hypot(lab.a, lab.b)
            let degrees = atan2(lab.b, lab.a) * 180 / .pi
            self.hueDegrees = degrees < 0 ? degrees + 360 : degrees
            self.luminance = luminance
        }

        fileprivate var lab: Lab { Lab(l: lightness, a: a, b: b) }
    }

    /// Converts a palette color for comparison, realized in `colorSpace`.
    static func sample(_ color: PaletteColor, colorSpace: ColorSpace) -> Sample {
        sample(color.p3(colorSpace: colorSpace))
    }

    /// Converts a displayable color for comparison, for colors that aren't part of a palette (a
    /// color picker's value, a sampled pixel). `nil` if the color has no RGB representation.
    static func sample(_ color: SystemColor) -> Sample? {
        P3(color).map(sample)
    }

    /// Converts a display-P3 color for comparison.
    static func sample(_ p3: P3) -> Sample {
        let (lab, luminance) = labAndLuminance(p3)
        return Sample(lab: lab, luminance: luminance)
    }

    /// The CIEDE2000 (ΔE₀₀) perceptual difference between two samples.
    static func deltaE2000(_ first: Sample, _ second: Sample) -> Double {
        deltaE2000(first.lab, second.lab)
    }

    /// The WCAG 2.1 contrast ratio (1–21) between two samples.
    static func wcagContrast(_ first: Sample, _ second: Sample) -> Double {
        wcagContrast(first.luminance, second.luminance)
    }
}

public extension PaletteColor {

    /// This color's WCAG relative luminance (white = 1, black = 0), realized in `colorSpace`.
    func relativeLuminance(colorSpace: ColorSpace) -> Double {
        ColorMetrics.labAndLuminance(p3(colorSpace: colorSpace)).luminance
    }

    /// The CIEDE2000 (ΔE₀₀) perceptual difference between this color and `other`, both realized in `colorSpace`.
    func deltaE2000(to other: PaletteColor, colorSpace: ColorSpace) -> Double {
        ColorMetrics.deltaE2000(
            ColorMetrics.labAndLuminance(p3(colorSpace: colorSpace)).lab,
            ColorMetrics.labAndLuminance(other.p3(colorSpace: colorSpace)).lab)
    }

    /// The WCAG 2.1 contrast ratio (1–21) between this color and `other`, both realized in `colorSpace`.
    func wcagContrast(to other: PaletteColor, colorSpace: ColorSpace) -> Double {
        ColorMetrics.wcagContrast(relativeLuminance(colorSpace: colorSpace), other.relativeLuminance(colorSpace: colorSpace))
    }
}

/// Mean / median / mode / min / max / standard deviation over a set of samples.
public struct DescriptiveStats: Hashable, Sendable {

    public let mean: Double
    public let median: Double
    /// The most common value after rounding to `modeBin` (ΔE and contrast are continuous, so raw modes are meaningless).
    public let mode: Double
    public let min: Double
    public let max: Double
    public let standardDeviation: Double

    public init?(_ values: [Double], modeBin: Double = 1) {
        guard !values.isEmpty else { return nil }

        let sorted = values.sorted()
        let n = Double(values.count)
        let average = values.reduce(0, +) / n

        mean = average
        min = sorted.first!
        max = sorted.last!

        let mid = sorted.count / 2
        median = sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]

        var counts: [Double: Int] = [:]
        for value in values {
            counts[(value / modeBin).rounded() * modeBin, default: 0] += 1
        }
        mode = counts.max { $0.value < $1.value }!.key

        let variance = values.reduce(0) { $0 + pow($1 - average, 2) } / n
        standardDeviation = variance.squareRoot()
    }
}
