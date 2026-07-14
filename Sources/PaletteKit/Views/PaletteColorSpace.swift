import SwiftUI

public extension EnvironmentValues {

    /// The color space PaletteKit's views realize ``PaletteColor`` fractions in.
    ///
    /// Palette 3D sets this from the palette being edited; pixel apps can leave it at the default.
    /// It lives in the environment so a whole palette browser doesn't have to thread the same value
    /// through every row and swatch.
    @Entry var paletteColorSpace: ColorSpace = .okLch
}

public extension View {

    /// Realizes every PaletteKit view below this one in `colorSpace`.
    func paletteColorSpace(_ colorSpace: ColorSpace) -> some View {
        environment(\.paletteColorSpace, colorSpace)
    }
}
