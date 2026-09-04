/// A perceptual color space in which a ``PaletteColor``'s normalized fractions are realized.
///
/// `lab`/`lch` use CIELAB (lightness 0–100), while `okLab`/`okLch` use the perceptually uniform
/// Oklab family (lightness 0–1). The `*Lch` variants express chroma/hue polarly; the `*Lab`
/// variants express the same color via cartesian a/b axes.
public enum ColorSpace: String, CaseIterable, Identifiable, Codable, Sendable {
    case lab, lch, okLab, okLch

    public var id: Self { self }

    public var name: String {
        switch self {
        case .lab: "Lab"
        case .lch: "Lch"
        case .okLab: "Oklab (Perceptual)"
        case .okLch: "Oklch (Perceptual)"
        }
    }

    /// The absolute lightness value at `lightnessFraction == 1`.
    public var lightnessScale: Double {
        switch self {
        case .lab, .lch: 100
        case .okLab, .okLch: 1
        }
    }

    /// The absolute chroma value at `chromaFraction == 1`.
    ///
    /// This is the chroma the 3D view's sphere surface stands for: the widest Display P3 reaches
    /// once each lightness layer is shrunk to the sphere (`max C · sqrt(1 - (2L-1)²)` over the
    /// gamut). P3 therefore fills the sphere's diameter, and wider gamuts plot outside it.
    public var chromaScale: Double {
        switch self {
        case .lab, .lch: 132.9
        case .okLab, .okLch: 0.3227
        }
    }
}
