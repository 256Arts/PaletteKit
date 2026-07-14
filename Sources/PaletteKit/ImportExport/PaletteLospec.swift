import Foundation

/// A palette fetched from [lospec.com](https://lospec.com)'s palette-list JSON API.
///
/// The network call is injectable (`fetch(_:using:)`) so hosts can test the URL → palette path
/// without hitting the network.
public struct LospecPalette: Decodable, Hashable, Sendable {

    public let name: String
    public let author: String
    /// 6-digit hex strings, without a leading `#`.
    public let colors: [String]

    /// Loads a palette from lospec's JSON payload.
    public init(json data: Data) throws {
        self = try JSONDecoder().decode(LospecPalette.self, from: data)
    }

    /// Whether `url` is a `lospec-palette://<slug>` link this type can fetch.
    public static func canHandle(_ url: URL) -> Bool {
        url.scheme == "lospec-palette" && url.host() != nil
    }

    /// The JSON endpoint for a `lospec-palette://<slug>` URL.
    public static func jsonURL(for url: URL) -> URL? {
        url.host().flatMap { URL(string: "https://lospec.com/palette-list/\($0).json") }
    }

    /// Fetches the palette a `lospec-palette://<slug>` URL points to.
    /// - Parameter load: The data loader, injectable for tests. Defaults to `URLSession.shared`.
    public static func fetch(_ url: URL, using load: (URL) async throws -> Data = { try await URLSession.shared.data(from: $0).0 }) async throws -> LospecPalette {
        guard let jsonURL = jsonURL(for: url) else { throw URLError(.badURL) }
        return try LospecPalette(json: try await load(jsonURL))
    }

    /// The palette's colors realized in the given color space. Unparseable entries are skipped.
    public func paletteColors(colorSpace: ColorSpace) -> [PaletteColor] {
        colors.compactMap { PaletteColor(hex: $0, colorSpace: colorSpace) }
    }
}

public extension Palette {

    /// The lospec palette realized into the shared palette model.
    init(_ lospec: LospecPalette, colorSpace: ColorSpace) {
        self.init(name: lospec.name, colors: lospec.paletteColors(colorSpace: colorSpace), source: .imported)
    }

    /// Fetches and realizes the palette a `lospec-palette://<slug>` URL points to.
    /// - Parameter load: The data loader, injectable for tests. Defaults to `URLSession.shared`.
    static func lospec(_ url: URL, colorSpace: ColorSpace, using load: (URL) async throws -> Data = { try await URLSession.shared.data(from: $0).0 }) async throws -> Palette {
        Palette(try await LospecPalette.fetch(url, using: load), colorSpace: colorSpace)
    }
}
