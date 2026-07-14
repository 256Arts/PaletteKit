import Foundation

/// A plain 8-bit sRGB color (0–255 per channel) with hex round-tripping.
///
/// This is the easy on-ramp for pixel apps (Sprite Pencil, Sprite Catalog) that think in bytes:
/// bridge to and from the perceptual ``PaletteColor`` with `PaletteColor(_:colorSpace:)` and
/// `srgb8(colorSpace:)`, or stay entirely in 8-bit space via `hex` / `hexString`.
public struct SRGB8: Hashable, Codable, Sendable {

    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Parses a 6-digit hex string, with or without a leading `#`.
    public init?(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = Int(digits, radix: 16) else { return nil }
        self.init(red: UInt8((value >> 16) & 0xFF), green: UInt8((value >> 8) & 0xFF), blue: UInt8(value & 0xFF))
    }

    /// An uppercase `#RRGGBB` hex string.
    public var hexString: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }
}

public extension PaletteColor {

    /// Realizes this color's clamped sRGB channels as an 8-bit value.
    func srgb8(colorSpace: ColorSpace) -> SRGB8 {
        let (r, g, b) = srgb8Bit(colorSpace: colorSpace)
        return SRGB8(red: UInt8(r), green: UInt8(g), blue: UInt8(b))
    }

    /// Creates a palette color from an 8-bit sRGB value, mapped into the given color space's fraction model.
    /// sRGB always fits inside P3, so the realization never fails.
    init(_ srgb: SRGB8, name: String? = nil, colorSpace: ColorSpace) {
        self.init(sRGB8BitRed: Int(srgb.red), green: Int(srgb.green), blue: Int(srgb.blue), name: name, colorSpace: colorSpace)!
    }
}
