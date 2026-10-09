import SwiftUI

// MARK: - Design System Usage Examples
// This file shows how to use the centralized design system

struct DesignSystemExample: View {
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.large) {
                
                // MARK: - Typography Examples
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    Text("Typography Examples")
                        .font(DesignSystem.Typography.title)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    
                    Text("Large Title")
                        .font(DesignSystem.Typography.largeTitle)
                    
                    Text("Regular Title")
                        .font(DesignSystem.Typography.title)
                    
                    Text("Headline")
                        .font(DesignSystem.Typography.headline)
                    
                    Text("Body Text")
                        .font(DesignSystem.Typography.body)
                    
                    Text("Caption Text")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
                
                // MARK: - Color Examples
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    Text("Color Examples")
                        .font(DesignSystem.Typography.title2)
                    
                    HStack(spacing: DesignSystem.Spacing.small) {
                        ColorSwatch(color: DesignSystem.Colors.primary, label: "Primary")
                        ColorSwatch(color: DesignSystem.Colors.success, label: "Success")
                        ColorSwatch(color: DesignSystem.Colors.warning, label: "Warning")
                        ColorSwatch(color: DesignSystem.Colors.danger, label: "Danger")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
                
                // MARK: - Button Examples
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    Text("Button Examples")
                        .font(DesignSystem.Typography.title2)
                    
                    Button("Primary Button") {
                        // Action
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    Button("Secondary Button") {
                        // Action
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Button("Disabled Button") {
                        // Action
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
                
                // MARK: - Component Examples
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    Text("Component Examples")
                        .font(DesignSystem.Typography.title2)
                    
                    // Progress Ring
                    HStack(spacing: DesignSystem.Spacing.large) {
                        ProgressRing(progress: 0.25)
                        ProgressRing(progress: 0.5)
                        ProgressRing(progress: 0.75)
                        ProgressRing(progress: 1.0)
                    }
                    
                    // Empty State
                    EmptyStateView(
                        icon: "calendar.badge.exclamationmark",
                        title: "No Deadlines",
                        message: "You don't have any upcoming deadlines. Tap the + button to add one."
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
                
                // MARK: - List Row Example
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("List Row Examples")
                        .font(DesignSystem.Typography.title2)
                    
                    // Deadline row example
                    HStack {
                        RoundedRectangle(cornerRadius: DesignSystem.Radii.small)
                            .fill(DesignSystem.Colors.deadlineWarning)
                            .frame(width: 5)
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxSmall) {
                            Text("Submit Project Report")
                                .font(DesignSystem.Typography.headline)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                            
                            Text("Project Alpha • Due in 3 days")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: DesignSystem.Layout.smallIconSize))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                    .listRowStyle()
                }
                .cardStyle()
            }
            .padding(DesignSystem.Spacing.medium)
        }
        .appStyle()
    }
}

// Helper view for color swatches
struct ColorSwatch: View {
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xSmall) {
            RoundedRectangle(cornerRadius: DesignSystem.Radii.medium)
                .fill(color)
                .frame(width: 60, height: 60)
            
            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
    }
}

// MARK: - Usage in Existing Views

/*
 HOW TO USE THE DESIGN SYSTEM IN YOUR VIEWS:
 
 1. Replace hardcoded colors:
    OLD: .foregroundColor(.gray)
    NEW: .foregroundColor(DesignSystem.Colors.secondaryText)
 
 2. Replace hardcoded fonts:
    OLD: .font(.largeTitle).fontWeight(.bold)
    NEW: .font(DesignSystem.Typography.largeTitle)
 
 3. Replace hardcoded spacing:
    OLD: .padding(16)
    NEW: .padding(DesignSystem.Spacing.medium)
 
 4. Use consistent components:
    OLD: Custom empty state text
    NEW: EmptyStateView(icon: "...", title: "...", message: "...")
 
 5. Apply view modifiers:
    OLD: Complex custom styling
    NEW: .cardStyle() or .listRowStyle()
 
 6. Use semantic colors for deadlines:
    - DesignSystem.Colors.deadlineUrgent (red)
    - DesignSystem.Colors.deadlineWarning (orange)
    - DesignSystem.Colors.deadlineSafe (green)
 
 7. Consistent button styling:
    OLD: Custom button with background
    NEW: .buttonStyle(PrimaryButtonStyle())
 
 8. Floating Action Button:
    OLD: Custom circular button
    NEW: FloatingActionButton(iconName: "plus") { /* action */ }
 
 Example transformation:
 
 // OLD CODE:
 Text("Projects")
     .font(.largeTitle)
     .fontWeight(.bold)
     .padding(.vertical, 10)
     .background(Color.black)
 
 // NEW CODE:
 Text("Projects")
     .font(DesignSystem.Typography.largeTitle)
     .padding(.vertical, DesignSystem.Spacing.small)
     .background(DesignSystem.Colors.background)
 
 // Or even simpler with NavigationHeader:
 NavigationHeader(title: "Projects", subtitle: currentDate)
 */

struct DesignSystemExample_Previews: PreviewProvider {
    static var previews: some View {
        DesignSystemExample()
    }
}