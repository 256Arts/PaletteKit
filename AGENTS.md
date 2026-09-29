# PaletteKit

A shared, storage-agnostic perceptual color engine for Jayden's palette apps (Palette 3D,
Sprite Pencil, Sprite Catalog). Consumers each own persistence; this package owns the color
model, conversions, generation, text formats, and premade content. See README.md for the full
feature rundown.

## Build

Swift package, no Xcode project. Targets: `PaletteKit` (library) and `PaletteKitTests`.
Platforms: iOS / Mac Catalyst / visionOS / macOS 26. Swift tools version 6.0.

Verify: `swift build`. Tests: `swift test`.

## Structure

- `Sources/PaletteKit/` — model and engine, one type per file: `PaletteColor` (the
  resolution-independent color), `ColorSpace`, `ColorRepresentation`, `Gamut`, `SRGB8`,
  `Palette`, `PaletteGenerator` (Lab/LCH sphere-model generation), `ColorMetrics` (ΔE₀₀, WCAG
  contrast), `PremadePalettes`, `SystemColor`.
- `Sources/PaletteKit/ImportExport/` — one file per format: `.gpl`, palette images (1px-tall
  PNG), Lospec URLs, `.clr` (`NSColorList`, macOS only). `PaletteFile.swift` dispatches by
  extension.
- `Sources/PaletteKit/Views/` — shared SwiftUI, host-agnostic (safe in app extensions). All
  color realization flows through the `\.paletteColorSpace` environment key
  (`PaletteColorSpace.swift`).
- `Sources/PaletteKit/Resources/Palette Images/` — the bundled premade palettes, processed
  into `Bundle.module`.
- `Tests/PaletteKitTests/` — one test file per major area (metrics, import/export, color,
  generator, premade palettes).

## Conventions

- Colors are stored as resolution-independent fractions (`PaletteColor`) and only realized to
  concrete values when given a `ColorSpace`; don't bake in a color space earlier than needed.
- `PaletteGenerator` is deterministic — apps should persist its `Parameters` recipe, not the
  generated colors.
- Depends on [ChromaKit](https://github.com/256Arts/ChromaKit) (via its git URL) for
  color-space math (`Lab`, `Lch`, `Oklab`, `Oklch`, `P3`, `XYZConvertable`).
