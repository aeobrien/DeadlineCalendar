import SwiftUI

// MARK: - Design System
// Centralized design system for consistent styling across the app
// Acts like CSS for SwiftUI - define once, use everywhere

public struct DesignSystem {
    
    // MARK: - Colors
    public struct Colors {
        // Primary Colors
        static let primary = Color.blue
        static let primaryDark = Color.blue.opacity(0.8)
        
        // Background Colors
        static let background = Color.black
        static let secondaryBackground = Color(white: 0.15)
        static let tertiaryBackground = Color(white: 0.2)
        static let cardBackground = Color(white: 0.12)
        
        // Text Colors
        static let primaryText = Color.white
        static let secondaryText = Color.gray
        static let tertiaryText = Color(white: 0.5)
        
        // Semantic Colors
        static let success = Color.green
        static let warning = Color.orange
        static let danger = Color.red
        static let info = Color.blue
        
        // Deadline Colors (based on urgency)
        static let deadlineUrgent = Color.red
        static let deadlineWarning = Color.orange
        static let deadlineSafe = Color.green
        static let deadlineCompleted = Color(white: 0.4)
        
        // UI Element Colors
        static let border = Color(white: 0.2)
        static let divider = Color(white: 0.15)
        static let shadow = Color.black.opacity(0.3)
        
        // Interactive States
        static let hoverBackground = Color(white: 0.2)
        static let activeBackground = Color(white: 0.25)
        static let disabledBackground = Color(white: 0.05)
        static let disabledText = Color(white: 0.3)
    }
    
    // MARK: - Typography
    public struct Typography {
        // Font Sizes with PingFang TC
        static let largeTitle = Font.custom("PingFangTC-Semibold", size: 34)
        static let title = Font.custom("PingFangTC-Semibold", size: 28)
        static let title2 = Font.custom("PingFangTC-Medium", size: 22)
        static let title3 = Font.custom("PingFangTC-Medium", size: 20)
        static let headline = Font.custom("PingFangTC-Medium", size: 17)
        static let body = Font.custom("PingFangTC-Regular", size: 17)
        static let callout = Font.custom("PingFangTC-Regular", size: 16)
        static let subheadline = Font.custom("PingFangTC-Regular", size: 15)
        static let footnote = Font.custom("PingFangTC-Regular", size: 13)
        static let caption = Font.custom("PingFangTC-Regular", size: 12)
        static let caption2 = Font.custom("PingFangTC-Light", size: 11)
        
        // Special Purpose Fonts
        static let buttonLabel = Font.custom("PingFangTC-Medium", size: 17)
        static let tabLabel = Font.custom("PingFangTC-Medium", size: 10)
        static let navigationTitle = Font.custom("PingFangTC-Medium", size: 17)
    }
    
    // MARK: - Spacing
    public struct Spacing {
        // Base unit: 8pt grid system
        static let xxxSmall: CGFloat = 2
        static let xxSmall: CGFloat = 4
        static let xSmall: CGFloat = 8
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
        static let xxLarge: CGFloat = 40
        static let xxxLarge: CGFloat = 48
        
        // Component-specific spacing
        static let listItemPadding: CGFloat = 16
        static let cardPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 24
        static let buttonPadding = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
    }
    
    // MARK: - Radii
    public struct Radii {
        static let none: CGFloat = 0
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xLarge: CGFloat = 16
        static let pill: CGFloat = 100
        static let card: CGFloat = 12
        static let button: CGFloat = 8
        static let sheet: CGFloat = 16
    }
    
    // MARK: - Shadows
    public struct Shadows {
        struct ShadowStyle {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
        
        static let small = ShadowStyle(
            color: Colors.shadow,
            radius: 2,
            x: 0,
            y: 1
        )
        
        static let medium = ShadowStyle(
            color: Colors.shadow,
            radius: 4,
            x: 0,
            y: 2
        )
        
        static let large = ShadowStyle(
            color: Colors.shadow,
            radius: 8,
            x: 0,
            y: 4
        )
        
        static let card = ShadowStyle(
            color: Colors.shadow,
            radius: 6,
            x: 0,
            y: 3
        )
    }
    
    // MARK: - Animation
    public struct Animation {
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let medium = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }
    
    // MARK: - Layout
    public struct Layout {
        static let maxContentWidth: CGFloat = 700
        static let minButtonHeight: CGFloat = 44
        static let minTouchTarget: CGFloat = 44
        static let tabBarHeight: CGFloat = 49
        static let navigationBarHeight: CGFloat = 44
        static let floatingButtonSize: CGFloat = 56
        static let iconSize: CGFloat = 24
        static let smallIconSize: CGFloat = 16
        static let largeIconSize: CGFloat = 32
    }
}

// MARK: - View Modifiers

// Card styling
struct CardStyle: ViewModifier {
    var backgroundColor: Color = DesignSystem.Colors.cardBackground
    var padding: CGFloat = DesignSystem.Spacing.cardPadding
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(DesignSystem.Radii.card)
            .shadow(
                color: DesignSystem.Shadows.card.color,
                radius: DesignSystem.Shadows.card.radius,
                x: DesignSystem.Shadows.card.x,
                y: DesignSystem.Shadows.card.y
            )
    }
}

// Primary button styling
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.buttonLabel)
            .foregroundColor(.white)
            .padding(DesignSystem.Spacing.buttonPadding)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radii.button)
                    .fill(isEnabled ? DesignSystem.Colors.primary : DesignSystem.Colors.disabledBackground)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

// Secondary button styling
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.buttonLabel)
            .foregroundColor(isEnabled ? DesignSystem.Colors.primary : DesignSystem.Colors.disabledText)
            .padding(DesignSystem.Spacing.buttonPadding)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radii.button)
                    .stroke(isEnabled ? DesignSystem.Colors.primary : DesignSystem.Colors.border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

// List row styling
struct ListRowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, DesignSystem.Spacing.small)
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .background(DesignSystem.Colors.secondaryBackground)
            .cornerRadius(DesignSystem.Radii.medium)
    }
}

// Section header styling
struct SectionHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(DesignSystem.Typography.headline)
            .foregroundColor(DesignSystem.Colors.secondaryText)
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.xSmall)
    }
}

// Empty state styling
struct EmptyStateStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(DesignSystem.Typography.body)
            .foregroundColor(DesignSystem.Colors.tertiaryText)
            .multilineTextAlignment(.center)
            .padding(DesignSystem.Spacing.xLarge)
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle(backgroundColor: Color = DesignSystem.Colors.cardBackground, padding: CGFloat = DesignSystem.Spacing.cardPadding) -> some View {
        modifier(CardStyle(backgroundColor: backgroundColor, padding: padding))
    }
    
    func listRowStyle() -> some View {
        modifier(ListRowStyle())
    }
    
    func sectionHeaderStyle() -> some View {
        modifier(SectionHeaderStyle())
    }
    
    func emptyStateStyle() -> some View {
        modifier(EmptyStateStyle())
    }
    
    // Apply consistent app-wide styling
    func appStyle() -> some View {
        self
            .preferredColorScheme(.dark)
            .accentColor(DesignSystem.Colors.primary)
            .background(DesignSystem.Colors.background)
    }
}

// MARK: - Common Components

// Floating Action Button
struct FloatingActionButton: View {
    let iconName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: DesignSystem.Layout.iconSize, weight: .medium))
                .foregroundColor(.white)
                .frame(width: DesignSystem.Layout.floatingButtonSize, height: DesignSystem.Layout.floatingButtonSize)
                .background(DesignSystem.Colors.primary)
                .clipShape(Circle())
                .shadow(
                    color: DesignSystem.Shadows.large.color,
                    radius: DesignSystem.Shadows.large.radius,
                    x: DesignSystem.Shadows.large.x,
                    y: DesignSystem.Shadows.large.y
                )
        }
    }
}

// Consistent Navigation Header
struct NavigationHeader: View {
    let title: String
    let subtitle: String?
    
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxSmall) {
            Text(title)
                .font(DesignSystem.Typography.largeTitle)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.medium)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.Colors.background.edgesIgnoringSafeArea(.top))
    }
}

// Progress Ring Component
struct ProgressRing: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    
    init(progress: Double, size: CGFloat = 40, lineWidth: CGFloat = 4) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(DesignSystem.Colors.border, lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progress < 0.33 ? DesignSystem.Colors.danger :
                    progress < 0.66 ? DesignSystem.Colors.warning :
                    DesignSystem.Colors.success,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(DesignSystem.Animation.spring, value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(width: size, height: size)
    }
}

// Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
            
            Text(title)
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            Text(message)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.xLarge)
    }
}