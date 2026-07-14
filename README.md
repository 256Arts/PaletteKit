# PaletteKit

A shared, storage-agnostic **perceptual color engine** for Jayden's palette apps
(Palette 3D, Sprite Pencil, Sprite Catalog). Each app maps to and from its own
8-bit / SwiftData / file types via small adapters, but the color model, conversions,
and text formats live here once.

Extracted from Palette 3D's `Shared/Model/PaletteColor.swift`. This is step **1/9** of
the palette-package plan; later steps add the Lab/LCH generator, shared import/export,
premade palettes, and reusable SwiftUI.

## What's in it

- **`PaletteColor`** — one color as resolution-independent, color-space-agnostic fractions
  (`lightnessFraction` / `chromaFraction` / `hueAngle`). Realizes to concrete colors, hex,
  CSS notations, and framework snippets only when given a `ColorSpace`. Parses inbound colors
  (`init(css:)`, `init(hex:colorSpace:)`, `init(sRGB8BitRed:…)`, `init(_:colorSpace:)`).
  `Codable` / `Hashable` / `Identifiable` / `Sendable`.
- **`ColorSpace`** (`lab` / `lch` / `okLab` / `okLch`), **`ColorRepresentation`** (15 text
  formats), **`Gamut`** (`wide` / `P3` / `sRGB` with clamping detection).
- **`SRGB8`** — a plain 8-bit sRGB face with hex round-tripping, the easy on-ramp for pixel
  apps. Bridge via `PaletteColor(_:colorSpace:)` and `srgb8(colorSpace:)`.
- **`Palette`** — a named, ordered `[PaletteColor]` with optional group lengths and a `source`.
  Value type, **no SwiftData** — each app owns its persistence.

## Platforms

iOS / Mac Catalyst / visionOS / macOS 26. Swift 6.

## Dependencies

- [ChromaKit](https://github.com/256Arts/ChromaKit) — color-space types (`Lab`, `Lch`,
  `Oklab`, `Oklch`, `P3`, `XYZConvertable`) and gamut-mapped conversions. Referenced by
  local path (`../ChromaKit`) to match the current, unpushed API Palette 3D builds against;
  switch to the URL once upstream is tagged with it.
