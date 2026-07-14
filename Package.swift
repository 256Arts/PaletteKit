// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PaletteKit",
    platforms: [
        .iOS("26.0"),
        .macCatalyst("26.0"),
        .visionOS("26.0"),
        .macOS("26.0"),
    ],
    products: [
        .library(name: "PaletteKit", targets: ["PaletteKit"]),
    ],
    dependencies: [
        // Color-space engine shared by every consumer of PaletteKit. Canonical upstream is
        // github.com/256Arts/ChromaKit, but the local clone carries the current (unpushed) API
        // that Palette 3D already builds against, so we reference it by path — the same sibling
        // checkout Palette 3D uses. Swap to the URL once the upstream tag catches up.
        .package(path: "../ChromaKit"),
    ],
    targets: [
        .target(
            name: "PaletteKit",
            dependencies: ["ChromaKit"],
            // The premade palettes, as 1px-tall PNGs. `.process` flattens them into the resource
            // bundle, so `Bundle.module.url(forResource:withExtension:)` finds each by name.
            resources: [.process("Resources")]),
        .testTarget(name: "PaletteKitTests", dependencies: ["PaletteKit"]),
    ]
)
