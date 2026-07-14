import Foundation

/// A named, ordered list of ``PaletteColor``s — the neutral, storage-agnostic palette shared by every app.
///
/// This is a plain value type on purpose: **no SwiftData**. Each consuming app maps it to its own
/// persistence (Palette 3D's `@Model`, Sprite Catalog's Codable file store, Sprite Pencil's PNG files).
/// Generation parameters are deliberately *not* stored here — that recipe lives with the app that
/// persists it — so this type stays a de-normalized snapshot of "these colors, in this order".
public struct Palette: Codable, Hashable, Identifiable, Sendable {

    public var id: UUID
    public var name: String
    public var colors: [PaletteColor]

    /// Optional contiguous sub-group sizes partitioning `colors` (e.g. Sprite Pencil's handpicked
    /// palettes that show a default block of N swatches, then the rest). `nil` treats the whole
    /// palette as one group. When present, the lengths should sum to `colors.count`.
    public var groupLengths: [Int]?

    /// Where this palette came from.
    public var source: Source

    /// The origin of a palette.
    public enum Source: String, Codable, Hashable, Sendable, CaseIterable {
        /// Bundled / handpicked content shipped with an app.
        case premade
        /// Produced by the Lab/LCH generator.
        case generated
        /// Read from an external file or URL (.gpl, .clr, palette image, lospec).
        case imported
        /// Created or edited by the user.
        case user
    }

    public init(
        id: UUID = UUID(),
        name: String,
        colors: [PaletteColor],
        groupLengths: [Int]? = nil,
        source: Source = .user
    ) {
        self.id = id
        self.name = name
        self.colors = colors
        self.groupLengths = groupLengths
        self.source = source
    }
}
