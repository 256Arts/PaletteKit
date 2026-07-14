#if canImport(UIKit)
import UIKit

/// The platform's concrete color type. `UIColor` on iOS / Mac Catalyst / visionOS, `NSColor` on macOS.
public typealias SystemColor = UIColor
#elseif canImport(AppKit)
import AppKit

/// The platform's concrete color type. `UIColor` on iOS / Mac Catalyst / visionOS, `NSColor` on macOS.
public typealias SystemColor = NSColor
#endif
