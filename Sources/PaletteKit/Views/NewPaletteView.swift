import SwiftUI

/// The "save a custom palette" flow: name it, pick where its colors come from, see it, save it.
///
/// The three sources match the three ways a lightweight host can obtain colors — a generated basic
/// palette, an imported file, or colors the host already had (a sampled sprite, an edited swatch
/// list). Apps with a full editor of their own (Palette 3D, Sprite Pencil) don't need this; it
/// exists so a host can gain palettes without building any palette UI.
///
/// Present it inside a `NavigationStack` — it puts its Cancel/Save buttons in the toolbar.
public struct NewPaletteView: View {

    /// Where a new palette's colors come from.
    private enum Source: Hashable {
        case generated(PaletteGenerator.Parameters.Preset)
        case imported
        /// Colors the host supplied up front.
        case provided
    }

    @Environment(\.paletteColorSpace) private var colorSpace
    @Environment(\.dismiss) private var dismiss

    private let providedColors: [PaletteColor]
    private let onSave: (Palette) -> Void

    @State private var name = ""
    @State private var source: Source
    @State private var importedColors: [PaletteColor] = []
    @State private var isImporting = false
    @State private var importFailed = false

    /// - Parameters:
    ///   - colors: Colors the host already has (e.g. sampled from a sprite). When non-empty they're
    ///     the initial source; otherwise the palette starts from a generated preset.
    ///   - onSave: Called with the finished palette. The view dismisses itself afterwards.
    public init(colors: [PaletteColor] = [], onSave: @escaping (Palette) -> Void) {
        self.providedColors = colors
        self.onSave = onSave
        self._source = State(initialValue: colors.isEmpty ? .generated(.vivid) : .provided)
    }

    /// The colors the current source produces.
    private var colors: [PaletteColor] {
        switch source {
        case let .generated(preset): PaletteGenerator(preset.parameters).generate()
        case .imported: importedColors
        case .provided: providedColors
        }
    }

    private var palette: Palette {
        Palette(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            colors: colors,
            source: source == .imported ? .imported : (providedColors.isEmpty ? .generated : .user))
    }

    private var canSave: Bool {
        !palette.name.isEmpty && !colors.isEmpty
    }

    public var body: some View {
        Form {
            Section {
                TextField(text: $name) {
                    Text("Name", bundle: #bundle, comment: "Text field label for a new palette's name.")
                }
            }

            Section {
                Picker(selection: $source) {
                    if !providedColors.isEmpty {
                        Text("Current Colors", bundle: #bundle, comment: "Palette source: the colors the app already had.")
                            .tag(Source.provided)
                    }
                    ForEach(PaletteGenerator.Parameters.Preset.allCases) { preset in
                        Text(preset.name).tag(Source.generated(preset))
                    }
                    Text("Imported File", bundle: #bundle, comment: "Palette source: colors read from a file the user picked.")
                        .tag(Source.imported)
                } label: {
                    Text("Colors", bundle: #bundle, comment: "Picker label for where a new palette's colors come from.")
                }

                if source == .imported {
                    Button {
                        isImporting = true
                    } label: {
                        Text("Choose File…", bundle: #bundle, comment: "Button that opens the file importer.")
                    }
                }
            }

            Section {
                PaletteStrip(colors, limit: nil)
                    .frame(height: 44)
                    .clipShape(.rect(cornerRadius: 8))
                    .listRowInsets(EdgeInsets())
            } footer: {
                Text("\(colors.count) colors", bundle: #bundle, comment: "Footer under the new palette's preview. The parameter is the number of colors.")
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) {
                    onSave(palette)
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: Palette.importableContentTypes) { result in
            guard let url = try? result.get(), let imported = Palette(file: url, colorSpace: colorSpace) else {
                importFailed = true
                return
            }
            importedColors = imported.colors
            if name.isEmpty {
                name = imported.name
            }
        }
        .alert(
            Text("Couldn't Read Palette", bundle: #bundle, comment: "Alert title when a palette file can't be imported."),
            isPresented: $importFailed) {
                Button {
                    importFailed = false
                } label: {
                    Text("OK", bundle: #bundle, comment: "Alert dismiss button.")
                }
            } message: {
                Text("The file isn't a GIMP palette, a color list, or a palette image.", bundle: #bundle, comment: "Alert message when a palette file can't be imported.")
            }
    }
}

#Preview("Generate") {
    NavigationStack {
        NewPaletteView { _ in }
    }
}

#Preview("From colors") {
    NavigationStack {
        NewPaletteView(colors: Palette.defaultPremadePalette(colorSpace: .okLch)!.colors) { _ in }
    }
}
