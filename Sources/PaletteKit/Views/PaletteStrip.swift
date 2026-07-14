import SwiftUI

/// A palette's colors as a single horizontal strip of swatches — the compact preview that stands in
/// for a palette in a list row, a picker, or a menu.
public struct PaletteStrip: View {

    @Environment(\.paletteColorSpace) private var colorSpace

    private let colors: [PaletteColor]
    private let limit: Int?

    /// - Parameters:
    ///   - colors: The colors to show, in order.
    ///   - limit: The most swatches to draw, so a 256-color palette doesn't render 256 hairlines in
    ///     a list row. `nil` draws them all.
    public init(_ colors: [PaletteColor], limit: Int? = 16) {
        self.colors = colors
        self.limit = limit
    }

    public init(_ palette: Palette, limit: Int? = 16) {
        self.init(palette.colors, limit: limit)
    }

    private var shown: [PaletteColor] {
        limit.map { Array(colors.prefix($0)) } ?? colors
    }

    public var body: some View {
        HStack(spacing: 0) {
            // A swatch's identity IS its position: the strip is stateless and never reorders, and a
            // palette may legitimately repeat a color, so the content-derived `PaletteColor.id`
            // wouldn't be unique here.
            ForEach(shown.enumerated(), id: \.offset) { _, color in
                Rectangle()
                    .fill(color.color(colorSpace: colorSpace))
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("\(colors.count) colors", bundle: #bundle, comment: "Accessibility label for a palette's color strip. The parameter is the number of colors."))
    }
}

#Preview {
    VStack(spacing: 12) {
        PaletteStrip(Palette.defaultPremadePalette(colorSpace: .okLch)!)
            .frame(height: 16)
        PaletteStrip(Palette.generated(.pastel), limit: nil)
            .frame(height: 16)
    }
    .padding()
}
