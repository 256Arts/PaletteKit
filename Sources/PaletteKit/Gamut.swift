/// A standard color gamut, used both to label a palette and to group the color-format rows in a detail view.
public enum Gamut: String, CaseIterable, Identifiable, Sendable {
    case wide = "Wide"
    case displayP3 = "P3"
    case sRGB = "sRGB"

    public var id: String { rawValue }

    /// The export-menu title for this gamut's formats.
    public var shareMenuTitle: String {
        self == .wide ? "Wide Gamut" : rawValue
    }

    /// The color representations to list under this gamut, in display order. The framework snippets
    /// (SwiftUI/UIKit/AppKit) appear under both P3 and sRGB — realized in that gamut's RGB space.
    public var representations: [ColorRepresentation] {
        switch self {
        case .wide: [.oklch, .oklab, .lch, .lab]
        case .displayP3: [.displayP3, .swiftUI, .uiKit, .appKit]
        case .sRGB: [.rgb, .hex, .hsl, .hsb, .hwb, .swiftUI, .uiKit, .appKit, .java, .android]
        }
    }

    /// Whether `color` falls outside this gamut, so its values in this gamut's formats are clamped.
    public func clamps(_ color: PaletteColor, colorSpace: ColorSpace) -> Bool {
        switch self {
        case .wide: false
        case .displayP3: color.isOutsideP3Gamut(colorSpace: colorSpace)
        case .sRGB: color.isOutsideSRGBGamut(colorSpace: colorSpace)
        }
    }

    /// The smallest gamut that fully contains every color in `colors`.
    public static func containing(_ colors: [PaletteColor], colorSpace: ColorSpace) -> Gamut {
        if colors.allSatisfy({ !$0.isOutsideSRGBGamut(colorSpace: colorSpace) }) {
            .sRGB
        } else if colors.allSatisfy({ !$0.isOutsideP3Gamut(colorSpace: colorSpace) }) {
            .displayP3
        } else {
            .wide
        }
    }
}
