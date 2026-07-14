# PaletteKit

A shared, storage-agnostic **perceptual color engine** for Jayden's palette apps
(Palette 3D, Sprite Pencil, Sprite Catalog). Each app maps to and from its own
8-bit / SwiftData / file types via small adapters, but the color model, conversions,
generation, text formats, and premade content live here once.

Extracted from Palette 3D and Sprite Pencil. Steps **1–4** and **7** of the nine-step
palette-package plan are landed; what remains is the three apps adopting the package
(steps 5, 6, 8, 9).

## What's in it

### Model

- **`PaletteColor`** — one color as resolution-independent, color-space-agnostic fractions
  (`lightnessFraction` / `chromaFraction` / `hueAngle`). Realizes to concrete colors, hex,
  CSS notations, and framework snippets only when given a `ColorSpace`. Parses inbound colors
  (`init(css:)`, `init(hex:colorSpace:)`, `init(sRGB8BitRed:…)`, `init(_:colorSpace:)`).
  `Codable` / `Hashable` / `Identifiable` / `Sendable`.
- **`ColorSpace`** (`lab` / `lch` / `okLab` / `okLch`), **`ColorRepresentation`** (15 text
  formats), **`Gamut`** (`wide` / `P3` / `sRGB` with clamping detection).
- **`SRGB8`** — a plain 8-bit sRGB face with hex round-tripping, the easy on-ramp for pixel
  apps. Bridge via `PaletteColor(_:colorSpace:)` and `srgb8(colorSpace:)`.
- **`Palette`** — a named, ordered `[PaletteColor]` with a `defaultGroupLength` (plus optional
  explicit `groupLengths`, read back as `colorGroups`) and a `source`. Value type, **no
  SwiftData** — each app owns its persistence.

### Generation & analysis

- **`PaletteGenerator`** — the Lab/LCH engine. An `@Observable` wrapper around a `Codable`
  `Parameters` struct; `generate()` builds the palette in normalized fractions via the sphere
  model (lightness levels, chroma levels/twist, hue segments). Deterministic, so an app can
  persist the *recipe* rather than the colors. `Parameters.Preset` (`.vivid`, `.pastel`,
  `.muted`, `.minimal`, `.rich`) is the one-line entry point for hosts that don't want to
  surface every knob: `Palette.generated(.pastel)`.
- **`ColorMetrics`** — CIEDE2000 ΔE₀₀ (conformant to the Sharma et al. reference data), WCAG 2.1
  contrast, Lab + relative luminance, and `DescriptiveStats`. Pure functions over Lab, so an
  O(n²) analysis pass converts each color only once; `PaletteColor.deltaE2000(to:colorSpace:)`
  and `.wcagContrast(to:colorSpace:)` are the readable one-off forms.

### Import / export

Every parser produces a `Palette`, realized into the caller's color space on the way in.

- **`Palette(file:colorSpace:)`** — reads any supported palette file. The extension only picks
  which parser to *try first*, so a mislabeled file still imports.
- **`.gpl`** — GIMP palette text (v1/v2), with per-color names. `GIMPPaletteExport` shares it out.
- **Palette images** — 1px-tall PNGs, one opaque pixel per color; the format Sprite Pencil has
  always used. `PaletteImageExport` shares it out.
- **Lospec** — `lospec-palette://<slug>` URLs, fetched from lospec.com's JSON API. The loader is
  injectable, so the URL → palette path is testable without the network.
- **`.clr`** — `NSColorList` read/write (macOS only). `PaletteColorListExport` drags a palette
  out to Finder.

### Premade palettes

`Palette.premadePalettes(colorSpace:)` is the full catalog — 13 bundled palette images plus
Building Bricks. `Palette.handpickedPalettes(on:colorSpace:)` is the curated, date-aware list an
editor should offer: the year-round set, with a seasonal palette promoted to the top on
Valentine's Day (Hearts), May the 4th (TIE Fighter), and throughout Pride month, October, and
December. Realized palettes are memoized per color space, so identity is stable across calls.

### Shared UI

Reusable SwiftUI, host-agnostic and safe to compile into app extensions. Every view realizes its
colors through `\.paletteColorSpace` in the environment (set it with `.paletteColorSpace(_:)`),
so a browser doesn't thread the same value through every row and swatch.

- **`PaletteStrip`** — a palette's colors as one horizontal strip; the compact stand-in for a
  palette in a row, picker, or menu.
- **`PaletteRow`** — strip + name + color count, selection-aware.
- **`PaletteBrowser`** — a scrolling browser with a selection binding. Given no palettes, it
  browses the premade catalog.
- **`NewPaletteView`** — the save-a-custom-palette flow: name it, take its colors from a generated
  preset / an imported file / colors the host already has, preview, save. For hosts that want
  palettes without building any palette UI; apps with a real editor (Palette 3D, Sprite Pencil)
  keep their own.

## Platforms

iOS / Mac Catalyst / visionOS / macOS 26. Swift 6.

## Dependencies

- [ChromaKit](https://github.com/256Arts/ChromaKit) — color-space types (`Lab`, `Lch`,
  `Oklab`, `Oklch`, `P3`, `XYZConvertable`) and gamut-mapped conversions. Referenced by
  local path (`../ChromaKit`) to match the current, unpushed API Palette 3D builds against;
  switch to the URL once upstream is tagged with it.
