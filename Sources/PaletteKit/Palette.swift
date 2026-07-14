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

    /// How many colors the palette's author meant to sit together when nothing more specific is
    /// given — a repeating group size, where `1` means no grouping. Sprite Pencil lays its swatch
    /// grid out in these chunks, so a palette built from 4-color ramps still reads as ramps.
    public var defaultGroupLength: Int

    /// Explicit contiguous sub-group sizes partitioning `colors`, for palettes whose groups aren't
    /// uniform. `nil` falls back to ``defaultGroupLength``. When present, these should sum to
    /// `colors.count`.
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
        defaultGroupLength: Int = 1,
        groupLengths: [Int]? = nil,
        source: Source = .user
    ) {
        self.id = id
        self.name = name
        self.colors = colors
        self.defaultGroupLength = defaultGroupLength
        self.groupLengths = groupLengths
        self.source = source
    }

    /// The palette's colors split into groups: `groupLengths` when the palette defines them,
    /// otherwise uniform chunks of ``defaultGroupLength``. A trailing partial group is kept.
    public var colorGroups: [[PaletteColor]] {
        guard let groupLengths else {
            return colors.chunks(of: Swift.max(1, defaultGroupLength))
        }
        var groups: [[PaletteColor]] = []
        var index = 0
        for length in groupLengths where index < colors.count {
            let end = Swift.min(index + Swift.max(1, length), colors.count)
            groups.append(Array(colors[index ..< end]))
            index = end
        }
        if index < colors.count { // A palette whose lengths don't cover every color keeps the rest.
            groups.append(Array(colors[index...]))
        }
        return groups
    }
}

private extension Array {
    /// The array split into consecutive chunks of `size`, the last possibly shorter.
    func chunks(of size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0 ..< Swift.min($0 + size, count)]) }
    }
}
