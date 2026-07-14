import SwiftUI

/// One palette in a list: its colors as a strip, with the name and color count beneath.
///
/// Rendering is host-agnostic — the row draws itself on the platform's grouped-background material
/// and takes its selection tint from `.tint`, so an app can restyle it without forking the view.
public struct PaletteRow: View {

    private let palette: Palette
    private let isSelected: Bool

    public init(_ palette: Palette, isSelected: Bool = false) {
        self.palette = palette
        self.isSelected = isSelected
    }

    public var body: some View {
        VStack(spacing: 0) {
            PaletteStrip(palette)
                .frame(height: 16)
            HStack {
                Text(palette.name)
                Spacer()
                Text(palette.colors.count, format: .number)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.background.secondary))
        .clipShape(.rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    let palettes = Palette.handpickedPalettes(colorSpace: .okLch)
    ScrollView {
        LazyVStack(spacing: 12) {
            ForEach(palettes) { palette in
                PaletteRow(palette, isSelected: palette.name == Palette.defaultPremadeName)
            }
        }
        .padding()
    }
}
