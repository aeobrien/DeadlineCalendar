import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "AppBackground" asset catalog color resource.
    static let appBackground = DeveloperToolsSupport.ColorResource(name: "AppBackground", bundle: resourceBundle)

    /// The "AppPrimaryText" asset catalog color resource.
    static let appPrimaryText = DeveloperToolsSupport.ColorResource(name: "AppPrimaryText", bundle: resourceBundle)

    /// The "AppSecondaryText" asset catalog color resource.
    static let appSecondaryText = DeveloperToolsSupport.ColorResource(name: "AppSecondaryText", bundle: resourceBundle)

    /// The "WidgetBackground" asset catalog color resource.
    static let widgetBackground = DeveloperToolsSupport.ColorResource(name: "WidgetBackground", bundle: resourceBundle)

    /// The "WidgetPrimaryText" asset catalog color resource.
    static let widgetPrimaryText = DeveloperToolsSupport.ColorResource(name: "WidgetPrimaryText", bundle: resourceBundle)

    /// The "WidgetSecondaryText" asset catalog color resource.
    static let widgetSecondaryText = DeveloperToolsSupport.ColorResource(name: "WidgetSecondaryText", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// The "AppBackground" asset catalog color.
    static var appBackground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .appBackground)
#else
        .init()
#endif
    }

    /// The "AppPrimaryText" asset catalog color.
    static var appPrimaryText: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .appPrimaryText)
#else
        .init()
#endif
    }

    /// The "AppSecondaryText" asset catalog color.
    static var appSecondaryText: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .appSecondaryText)
#else
        .init()
#endif
    }

    /// The "WidgetBackground" asset catalog color.
    static var widgetBackground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .widgetBackground)
#else
        .init()
#endif
    }

    /// The "WidgetPrimaryText" asset catalog color.
    static var widgetPrimaryText: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .widgetPrimaryText)
#else
        .init()
#endif
    }

    /// The "WidgetSecondaryText" asset catalog color.
    static var widgetSecondaryText: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .widgetSecondaryText)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// The "AppBackground" asset catalog color.
    static var appBackground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .appBackground)
#else
        .init()
#endif
    }

    /// The "AppPrimaryText" asset catalog color.
    static var appPrimaryText: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .appPrimaryText)
#else
        .init()
#endif
    }

    /// The "AppSecondaryText" asset catalog color.
    static var appSecondaryText: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .appSecondaryText)
#else
        .init()
#endif
    }

    /// The "WidgetBackground" asset catalog color.
    static var widgetBackground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .widgetBackground)
#else
        .init()
#endif
    }

    /// The "WidgetPrimaryText" asset catalog color.
    static var widgetPrimaryText: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .widgetPrimaryText)
#else
        .init()
#endif
    }

    /// The "WidgetSecondaryText" asset catalog color.
    static var widgetSecondaryText: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .widgetSecondaryText)
#else
        .init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    /// The "AppBackground" asset catalog color.
    static var appBackground: SwiftUI.Color { .init(.appBackground) }

    /// The "AppPrimaryText" asset catalog color.
    static var appPrimaryText: SwiftUI.Color { .init(.appPrimaryText) }

    /// The "AppSecondaryText" asset catalog color.
    static var appSecondaryText: SwiftUI.Color { .init(.appSecondaryText) }

    /// The "WidgetBackground" asset catalog color.
    static var widgetBackground: SwiftUI.Color { .init(.widgetBackground) }

    /// The "WidgetPrimaryText" asset catalog color.
    static var widgetPrimaryText: SwiftUI.Color { .init(.widgetPrimaryText) }

    /// The "WidgetSecondaryText" asset catalog color.
    static var widgetSecondaryText: SwiftUI.Color { .init(.widgetSecondaryText) }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    /// The "AppBackground" asset catalog color.
    static var appBackground: SwiftUI.Color { .init(.appBackground) }

    /// The "AppPrimaryText" asset catalog color.
    static var appPrimaryText: SwiftUI.Color { .init(.appPrimaryText) }

    /// The "AppSecondaryText" asset catalog color.
    static var appSecondaryText: SwiftUI.Color { .init(.appSecondaryText) }

    /// The "WidgetBackground" asset catalog color.
    static var widgetBackground: SwiftUI.Color { .init(.widgetBackground) }

    /// The "WidgetPrimaryText" asset catalog color.
    static var widgetPrimaryText: SwiftUI.Color { .init(.widgetPrimaryText) }

    /// The "WidgetSecondaryText" asset catalog color.
    static var widgetSecondaryText: SwiftUI.Color { .init(.widgetSecondaryText) }

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

