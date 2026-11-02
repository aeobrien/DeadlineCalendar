import SwiftUI

// MARK: - Redesigned All Deadlines View
// Using the new design system for a cleaner, more modern UI

struct AllDeadlinesViewRedesigned: View {
    @ObservedObject var viewModel: DeadlineViewModel
    
    // Navigation helpers
    @State private var selectedProjectID: UUID? = nil
    @State private var navigateToProject = false
    @State private var editSheetParameters: EditSheetParameters?
    
    // Display toggles
    @State private var showDueDate = false
    @State private var searchText = ""
    @State private var isSearching = false
    
    // Sheet toggles
    @State private var showingAddStandaloneDeadlineSheet = false
    @State private var showingAddProjectSheet = false
    @State private var showingCompletedDeadlinesSheet = false
    
    // Timer for refreshing
    @State private var refreshTimer: Timer?
    @State private var currentTime = Date()
    
    // MARK: - Grouped Deadlines
    
    private var groupedDeadlines: (today: [DeadlineListItem], thisWeek: [DeadlineListItem], later: [DeadlineListItem]) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday)!
        
        let filtered = allDeadlinesSorted.filter { item in
            searchText.isEmpty || 
            item.subDeadlineTitle.localizedCaseInsensitiveContains(searchText) ||
            item.projectName.localizedCaseInsensitiveContains(searchText)
        }
        
        let today = filtered.filter { $0.subDeadlineDate < startOfTomorrow }
        let thisWeek = filtered.filter { $0.subDeadlineDate >= startOfTomorrow && $0.subDeadlineDate < endOfWeek }
        let later = filtered.filter { $0.subDeadlineDate >= endOfWeek }
        
        return (today, thisWeek, later)
    }
    
    private var allDeadlinesSorted: [DeadlineListItem] {
        var items: [DeadlineListItem] = []
        
        // Add sub-deadlines
        for project in viewModel.projects {
            for sub in project.subDeadlines {
                guard !sub.isCompleted, viewModel.isSubDeadlineActive(sub) else { continue }
                items.append(DeadlineListItem(
                    projectID: project.id,
                    projectName: project.title,
                    subDeadlineID: sub.id,
                    subDeadlineTitle: sub.title,
                    subDeadlineDate: sub.date,
                    isSubDeadlineCompleted: sub.isCompleted,
                    triggerID: nil,
                    isTrigger: false
                ))
            }
        }
        
        // Add triggers
        for trigger in viewModel.triggers {
            guard !trigger.isActive, let triggerDate = trigger.date else { continue }
            if let project = viewModel.projects.first(where: { $0.id == trigger.projectID }) {
                items.append(DeadlineListItem(
                    projectID: project.id,
                    projectName: project.title,
                    subDeadlineID: nil,
                    subDeadlineTitle: trigger.name,
                    subDeadlineDate: triggerDate,
                    isSubDeadlineCompleted: false,
                    triggerID: trigger.id,
                    isTrigger: true
                ))
            }
        }
        
        return items.sorted { $0.subDeadlineDate < $1.subDeadlineDate }
    }
    
    // MARK: - Body
    
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
                                showingCompletedDeadlinesSheet = true
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                            }
                            
                            Spacer()
                            
                            // Title
                            VStack(spacing: DesignSystem.Spacing.xxxSmall) {
                                Text("Deadlines")
                                    .font(DesignSystem.Typography.title2)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                
                                Text(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none))
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                            }
                            
                            Spacer()
                            
                            // Date toggle button (right)
                            Button {
                                withAnimation(DesignSystem.Animation.fast) {
                                    showDueDate.toggle()
                                }
                            } label: {
                                Image(systemName: showDueDate ? "calendar" : "calendar.badge.clock")
                                    .font(.system(size: 22))
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                            }
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
                                
                                TextField("Search deadlines...", text: $searchText)
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
                        
                        let grouped = groupedDeadlines
                        
                        // Empty State
                        if grouped.today.isEmpty && grouped.thisWeek.isEmpty && grouped.later.isEmpty {
                            EmptyStateView(
                                icon: "calendar.badge.exclamationmark",
                                title: "No Active Deadlines",
                                message: "You're all caught up! Tap the + button to add a new deadline."
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.top, DesignSystem.Spacing.xxxLarge)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } else {
                            // Today Section
                            if !grouped.today.isEmpty {
                                Section {
                                    ForEach(grouped.today) { item in
                                        deadlineRow(for: item)
                                    }
                                } header: {
                                    sectionHeader(title: "Today", count: grouped.today.count)
                                }
                            }
                            
                            // This Week Section
                            if !grouped.thisWeek.isEmpty {
                                Section {
                                    ForEach(grouped.thisWeek) { item in
                                        deadlineRow(for: item)
                                    }
                                } header: {
                                    sectionHeader(title: "This Week", count: grouped.thisWeek.count)
                                }
                            }
                            
                            // Later Section
                            if !grouped.later.isEmpty {
                                Section {
                                    ForEach(grouped.later) { item in
                                        deadlineRow(for: item)
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
                            showingAddStandaloneDeadlineSheet = true
                        }
                        .padding(DesignSystem.Spacing.large)
                    }
                }
                
                
                // Hidden navigation link
                NavigationLink(destination: projectDetailDestination(), isActive: $navigateToProject) {
                    EmptyView()
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .appStyle()
        .onAppear {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                currentTime = Date()
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
        // Sheets
        .sheet(isPresented: $showingAddStandaloneDeadlineSheet) {
            AddStandaloneDeadlineView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingAddProjectSheet) {
            AddProjectView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingCompletedDeadlinesSheet) {
            CompletedDeadlinesView(viewModel: viewModel)
        }
        .sheet(item: $editSheetParameters) { params in
            ProjectEditorView(
                viewModel: viewModel,
                projectToEditID: params.projectID,
                scrollToSubDeadlineID: params.subDeadlineID
            )
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
    
    private func deadlineRow(for item: DeadlineListItem) -> some View {
        deadlineCard(for: item)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: DesignSystem.Spacing.xxSmall, leading: DesignSystem.Spacing.medium, bottom: DesignSystem.Spacing.xxSmall, trailing: DesignSystem.Spacing.medium))
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    complete(item)
                } label: {
                    if item.isTrigger {
                        Label("Activate", systemImage: "play.circle.fill")
                    } else {
                        Label("Complete", systemImage: "checkmark.circle.fill")
                    }
                }
                .tint(.green)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    delete(item)
                } label: {
                    Label("Delete", systemImage: "trash.fill")
                }
            }
            .contextMenu {
                Button {
                    selectedProjectID = item.projectID
                    navigateToProject = true
                } label: {
                    Label("View Project", systemImage: "folder")
                }
                
                if !item.isTrigger {
                    Button {
                        editSheetParameters = EditSheetParameters(
                            projectID: item.projectID,
                            subDeadlineID: item.subDeadlineID
                        )
                    } label: {
                        Label("Edit Deadline", systemImage: "pencil")
                    }
                }
                
                Button(role: .destructive) {
                    delete(item)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
    
    
    private func deadlineCard(for item: DeadlineListItem) -> some View {
        HStack(spacing: 0) {
            // Urgency indicator
            RoundedRectangle(cornerRadius: DesignSystem.Radii.small)
                .fill(stripColor(for: item.subDeadlineDate))
                .frame(width: 4)
            
            HStack(spacing: DesignSystem.Spacing.small) {
                // Icon for triggers
                if item.isTrigger {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: DesignSystem.Layout.iconSize))
                        .foregroundColor(DesignSystem.Colors.info)
                }
                
                // Content
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxxSmall) {
                    Text(item.subDeadlineTitle)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(1)
                    
                    if item.projectID != DeadlineViewModel.standaloneProjectID {
                        Text(item.projectName)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
                
                Spacer()
                
                // Date/Time info
                VStack(alignment: .trailing, spacing: 0) {
                    Text(showDueDate ? formattedDate(item.subDeadlineDate) : daysRemainingText(for: item.subDeadlineDate))
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(dateColor(for: item.subDeadlineDate, isCompleted: item.isSubDeadlineCompleted))
                }
            }
            .padding(DesignSystem.Spacing.medium)
        }
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.Radii.card)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radii.card)
                .stroke(DesignSystem.Colors.border.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Helper Functions
    
    private func projectDetailDestination() -> some View {
        if let projectID = selectedProjectID,
           let project = viewModel.projects.first(where: { $0.id == projectID }) {
            return AnyView(ProjectDetailView(project: project, viewModel: viewModel))
        } else {
            return AnyView(EmptyView())
        }
    }
    
    private func stripColor(for date: Date) -> Color {
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
    
    private func dateColor(for date: Date, isCompleted: Bool) -> Color {
        if isCompleted {
            return DesignSystem.Colors.deadlineCompleted
        }
        return stripColor(for: date)
    }
    
    private func daysRemainingText(for date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let daysRemaining = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        
        if daysRemaining < 0 {
            return "\(-daysRemaining)d overdue"
        } else if daysRemaining == 0 {
            return "Today"
        } else if daysRemaining == 1 {
            return "Tomorrow"
        } else {
            return "\(daysRemaining)d left"
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func complete(_ item: DeadlineListItem) {
        if item.isTrigger {
            // Activate trigger
            if let triggerID = item.triggerID {
                viewModel.activateTrigger(triggerID: triggerID)
            }
        } else {
            // Complete sub-deadline
            if let subID = item.subDeadlineID,
               let project = viewModel.projects.first(where: { $0.id == item.projectID }),
               let subDeadline = project.subDeadlines.first(where: { $0.id == subID }) {
                viewModel.toggleSubDeadlineCompletion(subDeadline, in: project)
            }
        }
    }
    
    private func delete(_ item: DeadlineListItem) {
        if item.isTrigger {
            // Delete trigger
            if let triggerID = item.triggerID {
                viewModel.deleteTrigger(triggerID: triggerID)
            }
        } else {
            // Delete sub-deadline
            if let subID = item.subDeadlineID {
                viewModel.deleteSubDeadline(subDeadlineID: subID, fromProjectID: item.projectID)
            }
        }
    }
    
    private enum UrgencyLevel {
        case high, medium, low
    }
}