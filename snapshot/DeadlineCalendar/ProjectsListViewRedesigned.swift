import SwiftUI

// MARK: - Redesigned Projects List View
// Modern card-based layout with visual progress indicators

struct ProjectsListViewRedesigned: View {
    @ObservedObject var viewModel: DeadlineViewModel
    
    @State private var showingAddProjectSheet = false
    @State private var showingCompletedProjectsSheet = false
    @State private var showingTemplateManagerSheet = false
    @State private var selectedProjectID: UUID? = nil
    @State private var searchText = ""
    @State private var isSearching = false
    
    // Filtered and sorted projects
    private var filteredProjects: [Project] {
        let active = viewModel.projects.filter { !$0.isFullyCompleted }
        
        let filtered = active.filter { project in
            searchText.isEmpty ||
            project.title.localizedCaseInsensitiveContains(searchText) ||
            (project.templateName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
        
        return filtered.sorted { $0.finalDeadlineDate < $1.finalDeadlineDate }
    }
    
    // Group projects by timeline
    private var groupedProjects: (thisMonth: [Project], nextMonth: [Project], later: [Project]) {
        let calendar = Calendar.current
        let now = Date()
        let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
        let endOfNextMonth = calendar.date(byAdding: .month, value: 1, to: endOfMonth) ?? now
        
        let thisMonth = filteredProjects.filter { $0.finalDeadlineDate <= endOfMonth }
        let nextMonth = filteredProjects.filter { $0.finalDeadlineDate > endOfMonth && $0.finalDeadlineDate <= endOfNextMonth }
        let later = filteredProjects.filter { $0.finalDeadlineDate > endOfNextMonth }
        
        return (thisMonth, nextMonth, later)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Navigation Header with buttons
                    VStack(spacing: 0) {
                        HStack {
                            // Completed button (left)
                            Button {
                                showingCompletedProjectsSheet = true
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                            }
                            
                            Spacer()
                            
                            // Title
                            VStack(spacing: DesignSystem.Spacing.xxxSmall) {
                                Text("Projects")
                                    .font(DesignSystem.Typography.title2)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                
                                Text(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none))
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
                    List {
                        // Search Bar (shown when pulled down)
                        if isSearching {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                                
                                TextField("Search projects...", text: $searchText)
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
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: DesignSystem.Spacing.medium, bottom: DesignSystem.Spacing.small, trailing: DesignSystem.Spacing.medium))
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        let grouped = groupedProjects
                        
                        // Empty State
                        if grouped.thisMonth.isEmpty && grouped.nextMonth.isEmpty && grouped.later.isEmpty {
                            EmptyStateView(
                                icon: "folder.badge.plus",
                                title: "No Active Projects",
                                message: "Start a new project by tapping the + button below."
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.top, DesignSystem.Spacing.xxxLarge)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } else {
                            // This Month Section
                            if !grouped.thisMonth.isEmpty {
                                Section {
                                    ForEach(grouped.thisMonth) { project in
                                        projectRow(for: project)
                                    }
                                } header: {
                                    sectionHeader(title: "This Month", count: grouped.thisMonth.count)
                                }
                            }
                            
                            // Next Month Section
                            if !grouped.nextMonth.isEmpty {
                                Section {
                                    ForEach(grouped.nextMonth) { project in
                                        projectRow(for: project)
                                    }
                                } header: {
                                    sectionHeader(title: "Next Month", count: grouped.nextMonth.count)
                                }
                            }
                            
                            // Later Section
                            if !grouped.later.isEmpty {
                                Section {
                                    ForEach(grouped.later) { project in
                                        projectRow(for: project)
                                    }
                                } header: {
                                    sectionHeader(title: "Later", count: grouped.later.count)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollIndicators(.hidden)
                    .refreshable {
                        withAnimation {
                            isSearching = true
                        }
                    }
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        FloatingActionButton(iconName: "plus") {
                            showingAddProjectSheet = true
                        }
                        .padding(DesignSystem.Spacing.large)
                    }
                }
                
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .appStyle()
        // Sheets
        .sheet(isPresented: $showingAddProjectSheet) {
            AddProjectView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingCompletedProjectsSheet) {
            CompletedProjectsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingTemplateManagerSheet) {
            TemplateManagerView(viewModel: viewModel)
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            Text("\(count)")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .padding(.horizontal, DesignSystem.Spacing.xSmall)
                .padding(.vertical, DesignSystem.Spacing.xxxSmall)
                .background(DesignSystem.Colors.tertiaryBackground)
                .cornerRadius(DesignSystem.Radii.small)
            
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.top, DesignSystem.Spacing.medium)
        .padding(.bottom, DesignSystem.Spacing.xSmall)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
    
    private func projectRow(for project: Project) -> some View {
        NavigationLink(
            destination: ProjectDetailView(project: project, viewModel: viewModel),
            tag: project.id,
            selection: $selectedProjectID
        ) {
            projectCard(for: project)
        }
        .buttonStyle(PlainButtonStyle())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: DesignSystem.Spacing.xxSmall, leading: DesignSystem.Spacing.medium, bottom: DesignSystem.Spacing.xxSmall, trailing: DesignSystem.Spacing.medium))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteProject(project)
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        }
    }
    
    private var projectsOverviewUnused: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            // Active Projects Count
            VStack(spacing: DesignSystem.Spacing.xxSmall) {
                Text("\(filteredProjects.count)")
                    .font(DesignSystem.Typography.title)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Text("Active")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.medium)
            .background(DesignSystem.Colors.secondaryBackground)
            .cornerRadius(DesignSystem.Radii.medium)
            
            // Upcoming Deadlines
            VStack(spacing: DesignSystem.Spacing.xxSmall) {
                let upcomingCount = filteredProjects.filter { 
                    Calendar.current.dateComponents([.day], from: Date(), to: $0.finalDeadlineDate).day ?? 0 <= 7 
                }.count
                
                Text("\(upcomingCount)")
                    .font(DesignSystem.Typography.title)
                    .foregroundColor(upcomingCount > 0 ? DesignSystem.Colors.warning : DesignSystem.Colors.primaryText)
                
                Text("This Week")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.medium)
            .background(DesignSystem.Colors.secondaryBackground)
            .cornerRadius(DesignSystem.Radii.medium)
            
            // Templates Count
            VStack(spacing: DesignSystem.Spacing.xxSmall) {
                Text("\(viewModel.templates.count)")
                    .font(DesignSystem.Typography.title)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Text("Templates")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.medium)
            .background(DesignSystem.Colors.secondaryBackground)
            .cornerRadius(DesignSystem.Radii.medium)
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
    }
    
    private func projectSection(title: String, projects: [Project]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            // Section Header
            HStack {
                Text(title)
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Text("\(projects.count)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .padding(.horizontal, DesignSystem.Spacing.xSmall)
                    .padding(.vertical, DesignSystem.Spacing.xxxSmall)
                    .background(DesignSystem.Colors.tertiaryBackground)
                    .cornerRadius(DesignSystem.Radii.small)
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            
            // Project Cards
            VStack(spacing: DesignSystem.Spacing.small) {
                ForEach(projects) { project in
                    NavigationLink(
                        destination: ProjectDetailView(project: project, viewModel: viewModel),
                        tag: project.id,
                        selection: $selectedProjectID
                    ) {
                        projectCard(for: project)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
        }
    }
    
    private func projectCard(for project: Project) -> some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                    Text(project.title)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(1)
                    
                    if let templateName = project.templateName {
                        Label(templateName, systemImage: "doc.plaintext")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
                
                Spacer()
                
                // Progress Ring
                ProgressRing(
                    progress: completionProgress(for: project),
                    size: 44,
                    lineWidth: 4
                )
            }
            
            // Progress Info
            HStack {
                // Next/Final Deadline
                VStack(alignment: .leading, spacing: 0) {
                    let nextDeadlineDate = nextSubDeadlineDate(for: project)
                    Text(nextDeadlineDate != nil ? "Next Deadline" : "Final Deadline")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    
                    let deadlineDate = nextDeadlineDate ?? project.finalDeadlineDate
                    Text(daysRemainingText(for: deadlineDate))
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(dateColor(for: deadlineDate))
                }
                
                Spacer()
                
                // Task Count
                VStack(alignment: .trailing, spacing: 0) {
                    let activeCount = project.subDeadlines.filter { !$0.isCompleted && viewModel.isSubDeadlineActive($0) }.count
                    let totalCount = project.subDeadlines.count
                    
                    Text("\(activeCount) of \(totalCount)")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    
                    Text("Tasks")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
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
        .contextMenu {
            Button {
                deleteProject(project)
            } label: {
                Label("Delete Project", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func completionProgress(for project: Project) -> Double {
        let totalCount = project.subDeadlines.count
        guard totalCount > 0 else { return project.isFullyCompleted ? 1.0 : 0.0 }
        let completedCount = project.subDeadlines.filter { $0.isCompleted }.count
        return Double(completedCount) / Double(totalCount)
    }
    
    private func nextSubDeadlineDate(for project: Project) -> Date? {
        project.subDeadlines
            .filter { !$0.isCompleted && viewModel.isSubDeadlineActive($0) }
            .sorted { $0.date < $1.date }
            .first?.date
    }
    
    private func dateColor(for date: Date) -> Color {
        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        
        if daysRemaining < 0 {
            return DesignSystem.Colors.deadlineUrgent
        } else if daysRemaining < viewModel.appSettings.colorSettings.orangeThreshold {
            return DesignSystem.Colors.deadlineUrgent
        } else if daysRemaining < viewModel.appSettings.colorSettings.greenThreshold {
            return DesignSystem.Colors.deadlineWarning
        } else {
            return DesignSystem.Colors.deadlineSafe
        }
    }
    
    private func progressColor(for progress: Double) -> Color {
        if progress < 0.33 {
            return DesignSystem.Colors.danger
        } else if progress < 0.66 {
            return DesignSystem.Colors.warning
        } else {
            return DesignSystem.Colors.success
        }
    }
    
    private func daysRemainingText(for date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let daysRemaining = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        
        if daysRemaining < 0 {
            return "\(-daysRemaining) days overdue"
        } else if daysRemaining == 0 {
            return "Due today"
        } else if daysRemaining == 1 {
            return "Due tomorrow"
        } else if daysRemaining <= 7 {
            return "\(daysRemaining) days left"
        } else if daysRemaining <= 30 {
            let weeks = daysRemaining / 7
            return "\(weeks) week\(weeks == 1 ? "" : "s") left"
        } else {
            let months = daysRemaining / 30
            return "\(months) month\(months == 1 ? "" : "s") left"
        }
    }
    
    private func deleteProject(_ project: Project) {
        viewModel.deleteProject(project)
    }
}