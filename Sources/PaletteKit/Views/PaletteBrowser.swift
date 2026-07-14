import SwiftUI

/// A scrolling browser over a list of palettes, selecting one by tapping it.
///
/// With no palettes supplied it browses the premade catalog, which is all Sprite Catalog needs to
/// show every bundled palette. Hosts with their own palettes (a user library, generated palettes)
/// pass them in.
public struct PaletteBrowser: View {

    @Environment(\.paletteColorSpace) private var colorSpace

    /// `nil` means "the premade catalog", which can only be realized once the color space is known.
    private let palettes: [Palette]?
    @Binding private var selection: Palette?

    /// Browses `palettes`, or the premade catalog when none are given.
    public init(_ palettes: [Palette]? = nil, selection: Binding<Palette?>) {
        self.palettes = palettes
        self._selection = selection
    }

    private var content: [Palette] {
        palettes ?? Palette.premadePalettes(colorSpace: colorSpace)
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(content) { palette in
                    Button {
                        selection = palette
                    } label: {
                        PaletteRow(palette, isSelected: palette.id == selection?.id)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .overlay {
            if content.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text("No Palettes", bundle: #bundle, comment: "Title shown when a palette list is empty.")
                    } icon: {
                        Image(systemName: "swatchpalette")
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var selection: Palette?
    PaletteBrowser(selection: $selection)
}
