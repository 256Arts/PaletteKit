import CoreGraphics
import Foundation
import ImageIO
import Synchronization

/// A palette bundled with PaletteKit: a 1px-tall PNG resource (or, for Building Bricks, a literal
/// color list), the group length its author intended, and the season that promotes it.
struct PremadePalette: Sendable {

    /// The window of the year during which a seasonal palette is offered, at the top of the list.
    enum Season: Sendable {
        case day(month: Int, day: Int)
        case month(Int)

        func includes(_ components: DateComponents) -> Bool {
            switch self {
            case let .day(month, day): components.month == month && components.day == day
            case let .month(month): components.month == month
            }
        }
    }

    let name: String
    let defaultGroupLength: Int
    /// `nil` for the palettes offered year-round.
    let season: Season?

    init(_ name: String, defaultGroupLength: Int, season: Season? = nil) {
        self.name = name
        self.defaultGroupLength = defaultGroupLength
        self.season = season
    }

    /// Offered year-round, in the order Sprite Pencil has always listed them.
    static let allYear = [
        PremadePalette("Island Joy 16", defaultGroupLength: 1),
        PremadePalette("PICO-8", defaultGroupLength: 1),
        PremadePalette("Zughy 32", defaultGroupLength: 5),
        PremadePalette("Endesga 32", defaultGroupLength: 4),
        PremadePalette("BLK 36", defaultGroupLength: 6),
        PremadePalette("Apollo", defaultGroupLength: 6),
        PremadePalette("Endesga 64", defaultGroupLength: 6),
        PremadePalette("SPF-80", defaultGroupLength: 1),
    ]

    /// Offered only in their season, inserted at the top of the list.
    static let seasonal = [
        PremadePalette("Hearts", defaultGroupLength: 2, season: .day(month: 2, day: 14)),
        PremadePalette("TIE Fighter", defaultGroupLength: 1, season: .day(month: 5, day: 4)),
        PremadePalette("Pride", defaultGroupLength: 1, season: .month(6)),
        PremadePalette("HallowPumpkin", defaultGroupLength: 1, season: .month(10)),
        PremadePalette("POLA5", defaultGroupLength: 1, season: .month(12)),
    ]

    /// The palette this resource decodes to, or `nil` if the bundled image is missing or malformed.
    func palette(colorSpace: ColorSpace) -> Palette? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let colors = [PaletteColor](paletteImage: image, colorSpace: colorSpace) else { return nil }
        return Palette(name: name, colors: colors, defaultGroupLength: defaultGroupLength, source: .premade)
    }
}

public extension Palette {

    /// The name of the palette offered as the default selection (Sprite Pencil's long-standing default).
    static let defaultPremadeName = "Endesga 32"

    /// Every palette bundled with PaletteKit, realized in `colorSpace` — the year-round set plus
    /// every seasonal one, regardless of the date. This is the *catalog* (what Sprite Catalog
    /// browses); for the curated, date-aware list an editor should offer, use
    /// ``handpickedPalettes(on:colorSpace:)``.
    static func premadePalettes(colorSpace: ColorSpace) -> [Palette] {
        cached(key: .allPremade, colorSpace: colorSpace) {
            let bundled = (PremadePalette.allYear + PremadePalette.seasonal).compactMap { $0.palette(colorSpace: colorSpace) }
            return bundled + [buildingBricks(colorSpace: colorSpace)]
        }
    }

    /// The palettes to offer on `date`: the year-round set, plus whichever seasonal palette the date
    /// falls in — Valentine's Day, May the 4th, Pride month, October, December — promoted to the top.
    static func handpickedPalettes(on date: Date = .now, colorSpace: ColorSpace) -> [Palette] {
        let components = Calendar.current.dateComponents([.month, .day], from: date)
        let inSeason = PremadePalette.seasonal.first { $0.season?.includes(components) == true }

        var palettes = ((inSeason.map { [$0] } ?? []) + PremadePalette.allYear).compactMap { $0.palette(colorSpace: colorSpace) }
        // Building Bricks holds slot 5 whether or not a seasonal palette leads the list — so in
        // season it lands ahead of BLK 36 rather than behind it. Odd, but it's the placement Sprite
        // Pencil has always shipped, and moving it would reshuffle everyone's palette list.
        palettes.insert(buildingBricks(colorSpace: colorSpace), at: Swift.min(5, palettes.count))
        return palettes
    }

    /// The palette an editor should select when the user has chosen none.
    static func defaultPremadePalette(colorSpace: ColorSpace) -> Palette? {
        premadePalettes(colorSpace: colorSpace).first { $0.name == defaultPremadeName }
    }

    /// The one premade palette that isn't a bundled image: the LEGO-ish brick colors, ported from
    /// Sprite Pencil's hardcoded list.
    private static func buildingBricks(colorSpace: ColorSpace) -> Palette {
        let hexes = [
            "F2F3F2", "E6E3E0", "A0A5A9", "635F61", "05131D", "F2CD37", "C91A09", "720E0F",
            "B4D2E3", "5A93DB", "0055BF", "0A3463", "4B9F4A", "237841", "184632", "582A12",
            "352100", "078BC9", "A95500", "958A73", "7DBFDD", "FA9C1C", "D09168", "E0FFB0",
            "BBE90B", "F6D7B3", "C2DAB8", "F9BA61", "FEBABD", "C9CAE2", "923978", "CC702A",
            "73DCA1", "3F3691", "C7D23C", "FFA70B", "FE8A18", "F2705E", "6074A1", "A0BCAC",
            "845E84", "E4CD9E", "008F9B", "4354A3",
        ]
        return Palette(
            name: "Building Bricks",
            colors: hexes.compactMap { PaletteColor(hex: $0, colorSpace: colorSpace) },
            defaultGroupLength: 1,
            source: .premade)
    }

    // MARK: - Caching

    private enum CacheKey: Hashable {
        case allPremade
    }

    /// Decoding 14 PNGs on every call would be wasteful, and fresh `UUID`s each time would break
    /// SwiftUI's view identity — so realized premade palettes are memoized per color space.
    private static let cache = Mutex<[CacheKey: [ColorSpace: [Palette]]]>([:])

    private static func cached(key: CacheKey, colorSpace: ColorSpace, build: () -> [Palette]) -> [Palette] {
        cache.withLock { cache in
            if let hit = cache[key]?[colorSpace] { return hit }
            let palettes = build()
            cache[key, default: [:]][colorSpace] = palettes
            return palettes
        }
    }
}
