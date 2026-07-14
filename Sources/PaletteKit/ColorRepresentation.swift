/// A user-selectable way to express a color as text, spanning the CSS color-space notations,
/// sRGB-derived RGB/Hex/HSL/HSV/HWB, and ready-to-paste code snippets for common UI frameworks.
/// Used both for the color detail rows and for choosing an export format.
public enum ColorRepresentation: String, CaseIterable, Identifiable, Sendable {
    case oklch, oklab, lch, lab, displayP3, rgb, hex, hsl, hsb, hwb, swiftUI, uiKit, appKit, java, android

    public var id: Self { self }

    public var name: String {
        switch self {
        case .oklch: "Oklch"
        case .oklab: "Oklab"
        case .lch: "Lch"
        case .lab: "Lab"
        case .displayP3: "Display P3"
        case .rgb: "RGB"
        case .hex: "Hex"
        case .hsl: "HSL"
        case .hsb: "HSV/HSB"
        case .hwb: "HWB"
        case .swiftUI: "SwiftUI"
        case .uiKit: "UIKit"
        case .appKit: "AppKit"
        case .java: "Java"
        case .android: "Android"
        }
    }
}
