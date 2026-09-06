import SwiftUI

// MARK: - Redesigned Template Manager View
// Matches the aesthetic of other redesigned views

struct TemplateManagerViewRedesigned: View {
    @ObservedObject var viewModel: DeadlineViewModel
    
    @State private var showingTemplateEditor = false
    @State private var templateToEdit: Template? = nil
    @State private var templateToDelete: Template?
    @State private var showingDeleteAlert = false
    @State private var searchText = ""
    @State private var isSearching = false
    
    // Filtered templates
    private var filteredTemplates: [Template] {
        if searchText.isEmpty {
            return viewModel.templates
        } else {
            return viewModel.templates.filter { template in
                template.name.localizedCaseInsensitiveContains(searchText) ||
                template.subDeadlines.contains { $0.title.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Navigation Header
                    VStack(spacing: 0) {
                        HStack {
                            // Placeholder for symmetry
                            Color.clear
                                .frame(width: 22, height: 22)
                            
                            Spacer()
                            
                            // Title
                            VStack(spacing: DesignSystem.Spacing.xxxSmall) {
                                Text("Templates")
                                    .font(DesignSystem.Typography.title2)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                
                                Text("\(filteredTemplates.count) template\(filteredTemplates.count == 1 ? "" : "s")")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                            }
                            
                            Spacer()
                            
                            // Placeholder for symmetry
                            Color.clear
                                .frame(width: 22, height: 22)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.medium)
                        .padding(.vertical, DesignSystem.Spacing.small)
                        .background(DesignSystem.Colors.background)
                    }
                    
                    // Content with pull-to-refresh search
                    ScrollView {
                        // Search Bar (shown when pulled down)
                        if isSearching {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                                
                                TextField("Search templates...", text: $searchText)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                
                                Button("Cancel") {
                                    withAnimation {
                                        isSearching = false
                                        searchText = ""
                                    }
                                }
                                .foregroundColor(DesignSystem.Colors.primary)
                            }
                            .padding(DesignSystem.Spacing.small)
                            .background(DesignSystem.Colors.secondaryBackground)
                            .cornerRadius(DesignSystem.Radii.medium)
                            .padding(.horizontal, DesignSystem.Spacing.medium)
                            .padding(.bottom, DesignSystem.Spacing.small)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        VStack(spacing: DesignSystem.Spacing.large) {
                            // Empty State
                            if filteredTemplates.isEmpty {
                                EmptyStateView(
                                    icon: "doc.badge.plus",
                                    title: "No Templates",
                                    message: "Create templates to quickly add recurring projects with predefined deadlines."
                                )
                                .padding(.top, DesignSystem.Spacing.xxxLarge)
                            } else {
                                // Template Cards
                                VStack(spacing: DesignSystem.Spacing.small) {
                                    ForEach(filteredTemplates) { template in
                                        templateCard(for: template)
                                            .contextMenu {
                                                Button {
                                                    templateToEdit = template
                                                    showingTemplateEditor = true
                                                } label: {
                                                    Label("Edit Template", systemImage: "pencil")
                                                }
                                                
                                                Button(role: .destructive) {
                                                    templateToDelete = template
                                                    showingDeleteAlert = true
                                                } label: {
                                                    Label("Delete Template", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                                .padding(.horizontal, DesignSystem.Spacing.medium)
                                .padding(.top, DesignSystem.Spacing.small)
                            }
                        }
                        .padding(.bottom, 100) // Space for FAB
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height > 50 && !isSearching {
                                    withAnimation {
                                        isSearching = true
                                    }
                                }
                            }
                    )
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        FloatingActionButton(iconName: "plus") {
                            templateToEdit = nil
                            showingTemplateEditor = true
                        }
                        .padding(DesignSystem.Spacing.large)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .appStyle()
        // Sheets and Alerts
        .sheet(isPresented: $showingTemplateEditor) {
            TemplateEditorView(viewModel: viewModel, templateToEdit: $templateToEdit)
        }
        .alert("Delete Template", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let template = templateToDelete {
                    deleteTemplate(template)
                }
            }
        } message: {
            if let template = templateToDelete {
                Text("Are you sure you want to delete the template '\(template.name)'? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func templateCard(for template: Template) -> some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                    Text(template.name)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(1)
                    
                }
                
                Spacer()
                
                // Task count indicator
                VStack(spacing: 0) {
                    Text("\(template.subDeadlines.count)")
                        .font(DesignSystem.Typography.title3)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    
                    Text("Tasks")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }
            
            // Sub-deadline preview
            if !template.subDeadlines.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxSmall) {
                    ForEach(template.subDeadlines.prefix(3)) { subDeadline in
                        HStack {
                            Circle()
                                .fill(DesignSystem.Colors.tertiaryText)
                                .frame(width: 4, height: 4)
                            
                            Text(subDeadline.title)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(formatOffset(subDeadline.offset))
                                .font(DesignSystem.Typography.caption2)
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }
                    }
                    
                    if template.subDeadlines.count > 3 {
                        Text("+ \(template.subDeadlines.count - 3) more")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                            .padding(.leading, DesignSystem.Spacing.xSmall)
                    }
                }
                .padding(.top, DesignSystem.Spacing.xSmall)
            }
            
            // Triggers indicator
            if !template.templateTriggers.isEmpty {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: DesignSystem.Layout.smallIconSize))
                        .foregroundColor(DesignSystem.Colors.info)
                    
                    Text("\(template.templateTriggers.count) trigger\(template.templateTriggers.count == 1 ? "" : "s")")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    
                    Spacer()
                }
            }
            
            // Action buttons
            HStack(spacing: DesignSystem.Spacing.small) {
                Button {
                    templateToEdit = template
                    showingTemplateEditor = true
                } label: {
                    HStack {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                        Text("Edit")
                    }
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .padding(.horizontal, DesignSystem.Spacing.small)
                    .padding(.vertical, DesignSystem.Spacing.xxSmall)
                    .background(DesignSystem.Colors.primary.opacity(0.1))
                    .cornerRadius(DesignSystem.Radii.small)
                }
                
                Spacer()
                
                Button {
                    // Create new project from template
                    // This could open AddProjectView with the template pre-selected
                    // For now, just show the edit view
                    templateToEdit = template
                    showingTemplateEditor = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                        Text("Use Template")
                    }
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.success)
                    .padding(.horizontal, DesignSystem.Spacing.small)
                    .padding(.vertical, DesignSystem.Spacing.xxSmall)
                    .background(DesignSystem.Colors.success.opacity(0.1))
                    .cornerRadius(DesignSystem.Radii.small)
                }
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.Radii.card)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radii.card)
                .stroke(DesignSystem.Colors.border.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Helper Functions
    
    private func formatOffset(_ offset: TimeOffset) -> String {
        let prefix = offset.before ? "before" : "after"
        switch offset.unit {
        case .days:
            return "\(offset.value)d \(prefix)"
        case .weeks:
            return "\(offset.value)w \(prefix)"
        case .months:
            return "\(offset.value)mo \(prefix)"
        }
    }
    
    private func deleteTemplate(_ template: Template) {
        withAnimation {
            viewModel.deleteTemplate(template)
        }
    }
}

// MARK: - Preview
struct TemplateManagerViewRedesigned_Previews: PreviewProvider {
    static var previews: some View {
        TemplateManagerViewRedesigned(viewModel: DeadlineViewModel())
    }
}