#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"AOTondra.Deadline-Calendar.DeadlineCalendarWidget";

/// The "AppBackground" asset catalog color resource.
static NSString * const ACColorNameAppBackground AC_SWIFT_PRIVATE = @"AppBackground";

/// The "AppPrimaryText" asset catalog color resource.
static NSString * const ACColorNameAppPrimaryText AC_SWIFT_PRIVATE = @"AppPrimaryText";

/// The "AppSecondaryText" asset catalog color resource.
static NSString * const ACColorNameAppSecondaryText AC_SWIFT_PRIVATE = @"AppSecondaryText";

/// The "WidgetBackground" asset catalog color resource.
static NSString * const ACColorNameWidgetBackground AC_SWIFT_PRIVATE = @"WidgetBackground";

/// The "WidgetPrimaryText" asset catalog color resource.
static NSString * const ACColorNameWidgetPrimaryText AC_SWIFT_PRIVATE = @"WidgetPrimaryText";

/// The "WidgetSecondaryText" asset catalog color resource.
static NSString * const ACColorNameWidgetSecondaryText AC_SWIFT_PRIVATE = @"WidgetSecondaryText";

#undef AC_SWIFT_PRIVATE
