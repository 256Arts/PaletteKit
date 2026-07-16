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
        // Color-space engine shared by every consumer of PaletteKit.
        .package(url: "https://github.com/256Arts/ChromaKit.git", from: "1.1.0"),
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
