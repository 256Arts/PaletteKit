import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// A failure encoding a palette to a palette image.
public enum PaletteImageError: LocalizedError {
    case empty
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .empty: "The palette has no colors to export."
        case .encodingFailed: "Could not encode the palette image."
        }
    }
}

public extension Array where Element == PaletteColor {

    /// Loads colors from an image encoding one color per pixel. Returns `nil` unless the
    /// image is 1px tall with no clear pixels — the palette-image rules.
    init?(paletteImage image: CGImage, colorSpace: ColorSpace) {
        guard image.height == 1, 0 < image.width else { return nil }

        // Redraw into a known sRGB RGBA8 buffer so any source pixel format reads uniformly.
        var pixels = [UInt8](repeating: 0, count: image.width * 4)
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB),
              let context = pixels.withUnsafeMutableBytes({ raw in
                  CGContext(
                    data: raw.baseAddress,
                    width: image.width,
                    height: 1,
                    bitsPerComponent: 8,
                    bytesPerRow: image.width * 4,
                    space: srgb,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
              }) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: 1))

        var colors: [PaletteColor] = []
        for x in 0 ..< image.width {
            let i = x * 4
            guard pixels[i + 3] == 255, // A clear pixel invalidates the whole image.
                  let color = PaletteColor(sRGB8BitRed: Int(pixels[i]), green: Int(pixels[i + 1]), blue: Int(pixels[i + 2]), colorSpace: colorSpace) else { return nil }
            colors.append(color)
        }
        self = colors
    }

    /// Renders the colors as a 1px-tall image, one fully-opaque sRGB pixel each — the
    /// palette-image interchange format, re-importable by `init?(paletteImage:colorSpace:)`.
    func paletteImage(colorSpace: ColorSpace) -> CGImage? {
        guard !isEmpty else { return nil }

        var pixels = [UInt8](repeating: 0, count: count * 4)
        for (x, color) in enumerated() {
            let (r, g, b) = color.srgb8Bit(colorSpace: colorSpace) // Already gamut-clamped to 0–255.
            let i = x * 4
            pixels[i] = UInt8(r)
            pixels[i + 1] = UInt8(g)
            pixels[i + 2] = UInt8(b)
            pixels[i + 3] = 255
        }

        return CGColorSpace(name: CGColorSpace.sRGB).flatMap { srgb in
            pixels.withUnsafeMutableBytes { raw in
                CGContext(
                    data: raw.baseAddress,
                    width: count,
                    height: 1,
                    bitsPerComponent: 8,
                    bytesPerRow: count * 4,
                    space: srgb,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?
                    .makeImage()
            }
        }
    }
}

public extension Palette {

    /// Loads a palette from a palette-image file, named after the file, or `nil` if it isn't a valid
    /// palette image. Decodes the exact pixels (no downsampling), since every pixel is one entry.
    init?(paletteImageFile url: URL, colorSpace: ColorSpace) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let colors = [PaletteColor](paletteImage: image, colorSpace: colorSpace) else { return nil }
        self.init(name: url.deletingPathExtension().lastPathComponent, colors: colors, source: .imported)
    }

    /// Loads a palette from an image encoding one color per pixel (1px tall, no clear pixels).
    init?(name: String, paletteImage image: CGImage, colorSpace: ColorSpace, source: Source = .imported) {
        guard let colors = [PaletteColor](paletteImage: image, colorSpace: colorSpace) else { return nil }
        self.init(name: name, colors: colors, source: source)
    }

    /// This palette as a 1px-tall image, one fully-opaque sRGB pixel per color.
    func paletteImage(colorSpace: ColorSpace) -> CGImage? {
        colors.paletteImage(colorSpace: colorSpace)
    }

    /// Encodes the palette as PNG palette-image data. Throws if the palette is empty or can't be encoded.
    func paletteImagePNGData(colorSpace: ColorSpace) throws -> Data {
        guard let image = paletteImage(colorSpace: colorSpace) else { throw PaletteImageError.empty }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw PaletteImageError.encodingFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw PaletteImageError.encodingFailed }
        return data as Data
    }
}

/// A palette shared out as a 1px-tall PNG palette image. Cross-platform, and re-importable
/// by every app that reads this format (Palette 3D, Sprite Pencil, Sprite Catalog).
public struct PaletteImageExport: Transferable {

    public let palette: Palette
    public let colorSpace: ColorSpace

    public init(palette: Palette, colorSpace: ColorSpace) {
        self.palette = palette
        self.colorSpace = colorSpace
    }

    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .png) { export in
            let data = try export.palette.paletteImagePNGData(colorSpace: export.colorSpace)
            return SentTransferredFile(try export.palette.writeTemporaryFile(data, pathExtension: "png"))
        }
    }
}
