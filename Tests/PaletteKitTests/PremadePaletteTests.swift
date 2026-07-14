import Foundation
import Testing
@testable import PaletteKit

@Suite("Premade palettes")
struct PremadePaletteTests {

    static func date(month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day))!
    }

    @Test("Every bundled palette image decodes", arguments: PremadePalette.allYear + PremadePalette.seasonal)
    func bundledImagesDecode(premade: PremadePalette) throws {
        let palette = try #require(premade.palette(colorSpace: .okLch), "\(premade.name).png is missing or isn't a 1px-tall palette image")

        #expect(palette.name == premade.name)
        #expect(palette.source == .premade)
        #expect(palette.defaultGroupLength == premade.defaultGroupLength)
        #expect(!palette.colors.isEmpty)
    }

    @Test("The catalog holds every bundled palette plus Building Bricks")
    func catalog() throws {
        let palettes = Palette.premadePalettes(colorSpace: .okLch)
        let names = palettes.map(\.name)

        #expect(palettes.count == PremadePalette.allYear.count + PremadePalette.seasonal.count + 1)
        #expect(names.contains("Building Bricks"))
        #expect(names.contains("Pride")) // Seasonal palettes are in the catalog year-round.
        #expect(palettes.allSatisfy { $0.source == .premade && !$0.colors.isEmpty })
    }

    @Test("Building Bricks ports Sprite Pencil's 44 brick colors")
    func buildingBricks() throws {
        let palette = try #require(Palette.premadePalettes(colorSpace: .okLch).first { $0.name == "Building Bricks" })
        let hexes = palette.colors.map { $0.hexString(colorSpace: .okLch) }

        #expect(palette.colors.count == 44)
        #expect(hexes.first == "#F2F3F2") // White.
        #expect(hexes.last == "#4354A3")  // Medium blue.
        #expect(hexes.contains("#C91A09")) // Bright red.
        #expect(palette.defaultGroupLength == 1)
    }

    @Test("Endesga 32 is the default, and is grouped in 4-color ramps")
    func defaultPalette() throws {
        let palette = try #require(Palette.defaultPremadePalette(colorSpace: .okLch))

        #expect(palette.name == Palette.defaultPremadeName)
        #expect(palette.defaultGroupLength == 4)
        #expect(palette.colors.count == 32)
        #expect(palette.colorGroups.count == 8)
        #expect(palette.colorGroups.allSatisfy { $0.count == 4 })
    }

    @Test("Out of season, only the year-round palettes are offered — plus Building Bricks")
    func offSeason() {
        let names = Palette.handpickedPalettes(on: Self.date(month: 3, day: 20), colorSpace: .okLch).map(\.name)

        #expect(names == [
            "Island Joy 16", "PICO-8", "Zughy 32", "Endesga 32", "BLK 36",
            "Building Bricks", "Apollo", "Endesga 64", "SPF-80",
        ])
    }

    @Test("The season's palette is offered first", arguments: [
        (2, 14, "Hearts"),
        (5, 4, "TIE Fighter"),
        (6, 1, "Pride"),
        (6, 30, "Pride"),
        (10, 31, "HallowPumpkin"),
        (12, 25, "POLA5"),
    ])
    func inSeason(month: Int, day: Int, expected: String) {
        let palettes = Palette.handpickedPalettes(on: Self.date(month: month, day: day), colorSpace: .okLch)

        #expect(palettes.first?.name == expected)
        #expect(palettes.count == PremadePalette.allYear.count + 2) // The season's palette + Building Bricks.
    }

    @Test("A day-scoped season doesn't leak into the rest of its month", arguments: [(2, 13), (2, 15), (5, 3), (5, 5)])
    func seasonIsOneDay(month: Int, day: Int) {
        let names = Palette.handpickedPalettes(on: Self.date(month: month, day: day), colorSpace: .okLch).map(\.name)

        #expect(!names.contains("Hearts"))
        #expect(!names.contains("TIE Fighter"))
    }

    @Test("Realized palettes are memoized, so identity is stable across calls")
    func stableIdentity() {
        let first = Palette.premadePalettes(colorSpace: .okLch)
        let second = Palette.premadePalettes(colorSpace: .okLch)

        #expect(first.map(\.id) == second.map(\.id))
    }

    @Test("Every color space realizes the same premade colors", arguments: ColorSpace.allCases)
    func colorSpaceIndependence(colorSpace: ColorSpace) throws {
        let reference = try #require(Palette.defaultPremadePalette(colorSpace: .okLch))
        let palette = try #require(Palette.defaultPremadePalette(colorSpace: colorSpace))

        #expect(palette.colors.map { $0.hexString(colorSpace: colorSpace) } == reference.colors.map { $0.hexString(colorSpace: .okLch) })
    }
}

extension PremadePalette: CustomTestStringConvertible {
    public var testDescription: String { name }
}
