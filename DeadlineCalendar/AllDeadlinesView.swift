import SwiftUI

// MARK: - Helper Models

/// A flattened representation of every visible deadline (project sub‑deadlines *and* standalone ones).
struct DeadlineListItem: Identifiable, Hashable {
    let id = UUID()                                   // Row identity only – *not* the sub‑deadline ID
    let projectID: UUID                               // Owning project (stand‑ins included)
    let projectName: String                           // Display name for project
    let subDeadlineID: UUID?                          // Actual SubDeadline ID – used for editing actions (nil for triggers)
    let subDeadlineTitle: String                      // Title shown in the list
    let subDeadlineDate: Date                         // When it is due
    let isSubDeadlineCompleted: Bool                  // Needed so we can grey out completed ones
    let triggerID: UUID?                              // Actual Trigger ID if this is a trigger
    let isTrigger: Bool                               // True if this item represents a trigger
}

/// Wrapper used so we can present the project editor via `.sheet(item:)`.
struct EditSheetParameters: Identifiable {
    let id = UUID()
    let projectID: UUID
    let subDeadlineID: UUID?
}

// MARK: - All Deadlines View

struct AllDeadlinesView: View {
    // Shared state
    @ObservedObject var viewModel: DeadlineViewModel

    // Navigation helpers
    @State private var selectedProjectID: UUID? = nil
    @State private var navigateToProject = false
    @State private var editSheetParameters: EditSheetParameters?

    // Display toggles
    @State private var showDueDate = false                       // "Days left" ⇄ "Due date" toggle

    // Sheet toggles
    @State private var showingAddStandaloneDeadlineSheet = false // Presents `AddStandaloneDeadlineView`
    @State private var showingAddProjectSheet = false            // Presents `AddProjectView`
    @State private var showingCompletedDeadlinesSheet = false     // Presents completed deadlines view
    
    // Timer for refreshing date calculations
    @State private var refreshTimer: Timer?
    @State private var currentTime = Date()

    // MARK: – Derived data

    /// Collect every *active* (trigger satisfied & not completed) deadline, sorted by soonest first.
    private var allDeadlinesSorted: [DeadlineListItem] {
        var items: [DeadlineListItem] = []

        // Add sub-deadlines
        for project in viewModel.projects {
            for sub in project.subDeadlines {
                guard !sub.isCompleted, viewModel.isSubDeadlineActive(sub) else { continue }
                items.append(DeadlineListItem(projectID: project.id,
                                             projectName: project.title,
                                             subDeadlineID: sub.id,
                                             subDeadlineTitle: sub.title,
                                             subDeadlineDate: sub.date,
                                             isSubDeadlineCompleted: sub.isCompleted,
                                             triggerID: nil,
                                             isTrigger: false))
            }
        }
        
        // Add triggers that are not yet activated
        for trigger in viewModel.triggers {
            guard !trigger.isActive else { continue }
            // Skip triggers without dates (old triggers)
            guard let triggerDate = trigger.date else { continue }
            if let project = viewModel.projects.first(where: { $0.id == trigger.projectID }) {
                items.append(DeadlineListItem(projectID: project.id,
                                             projectName: project.title,
                                             subDeadlineID: nil,
                                             subDeadlineTitle: trigger.name,
                                             subDeadlineDate: triggerDate,
                                             isSubDeadlineCompleted: false,
                                             triggerID: trigger.id,
                                             isTrigger: true))
            }
        }
        
        return items.sorted { $0.subDeadlineDate < $1.subDeadlineDate }
    }

    // MARK: – UI

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ---------- DEADLINE LIST ----------
                List {
                    ForEach(allDeadlinesSorted) { item in
                        row(for: item)
                    }
                }
                .listStyle(.plain)

                // Invisible link used to push `ProjectDetailView` when a context‑menu action is tapped
                NavigationLink(destination: projectDetailDestination(), isActive: $navigateToProject) {
                    EmptyView()
                }
                
                // --- Bottom Button Bar ---
                HStack {
                    // Button to show completed deadlines (left)
                    Button {
                        showingCompletedDeadlinesSheet = true
                    } label: {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .labelStyle(.iconOnly)
                    }
                    .frame(width: 60)
                    
                    Spacer()
                    
                    // Button to add a new standalone deadline (center)
                    Button {
                        showingAddStandaloneDeadlineSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .frame(width: 44, height: 44) // Larger central button
                    }
                    .frame(maxWidth: .infinity)
                    
                    Spacer()
                    
                    // Button to toggle date display (right)
                    Button {
                        showDueDate.toggle()
                    } label: {
                        Image(systemName: showDueDate ? "calendar" : "calendar.badge.clock")
                            .font(.title2)
                    }
                    .frame(width: 60)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.9))
            }
            .navigationTitle("All Deadlines")
            .preferredColorScheme(.dark)
        }
        .navigationViewStyle(.stack)
        .onAppear {
            // Set up timer to refresh every minute to keep date calculations fresh
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                currentTime = Date()
            }
        }
        .onDisappear {
            // Clean up timer when view disappears
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
        //------------------------------------------------------------------
        //  SHEETS
        //------------------------------------------------------------------
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
            ProjectEditorView(viewModel: viewModel,
                              projectToEditID: params.projectID,
                              scrollToSubDeadlineID: params.subDeadlineID)
        }
    }

    // MARK: – Row helper

    private func row(for item: DeadlineListItem) -> some View {
        HStack(spacing: 12) {
            // coloured urgency strip
            Capsule()
                .fill(stripColor(for: item.subDeadlineDate))
                .frame(width: 5)

            // Icon for triggers
            if item.isTrigger {
                Image(systemName: "play.circle")
                    .foregroundColor(.blue)
            }
            
            // title
            Text(item.projectID == DeadlineViewModel.standaloneProjectID ? item.subDeadlineTitle : "\(item.projectName) \(item.subDeadlineTitle)")
                .fontWeight(.medium)
                .foregroundColor(dateColor(for: item.subDeadlineDate, isCompleted: item.isSubDeadlineCompleted))

            Spacer()

            // date or days left
            Text(showDueDate ? formattedDate(item.subDeadlineDate) : daysRemainingText(for: item.subDeadlineDate))
                .font(.subheadline)
                .foregroundColor(dateColor(for: item.subDeadlineDate, isCompleted: item.isSubDeadlineCompleted))
                .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("View Project") {
                selectedProjectID = item.projectID
                navigateToProject = true
            }
            if !item.isTrigger {
                Button("Edit Deadline") {
                    editSheetParameters = EditSheetParameters(projectID: item.projectID, subDeadlineID: item.subDeadlineID)
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                complete(item)
            } label: {
                if item.isTrigger {
                    Label("Activate", systemImage: "play.circle.fill")
                } else {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                }
            }.tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                delete(item)
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        }
    }

    // MARK: – Row actions

    private func complete(_ item: DeadlineListItem) {
        if item.isTrigger {
            // Activate the trigger
            if let triggerID = item.triggerID {
                viewModel.activateTrigger(triggerID: triggerID)
            }
        } else {
            // Complete the sub-deadline
            guard let project = viewModel.projects.first(where: { $0.id == item.projectID }),
                  let subID = item.subDeadlineID,
                  let sub = project.subDeadlines.first(where: { $0.id == subID }) else { return }
            viewModel.toggleSubDeadlineCompletion(sub, in: project)
        }
    }

    private func delete(_ item: DeadlineListItem) {
        if item.isTrigger {
            // Delete the trigger
            if let triggerID = item.triggerID {
                viewModel.deleteTrigger(triggerID: triggerID)
            }
        } else {
            // Delete the sub-deadline
            if let subID = item.subDeadlineID {
                viewModel.deleteSubDeadline(subDeadlineID: subID, fromProjectID: item.projectID)
            }
        }
    }

    // MARK: – Navigation destination helper

    @ViewBuilder
    private func projectDetailDestination() -> some View {
        if let id = selectedProjectID, let project = viewModel.projects.first(where: { $0.id == id }) {
            ProjectDetailView(project: project, viewModel: viewModel)
        } else {
            Text("Error: project not found")
        }
    }

    // MARK: – Styling helpers (unchanged from previous version)

    private func dateColor(for date: Date, isCompleted: Bool) -> Color {
        if isCompleted { return .gray }
        if date < Calendar.current.startOfDay(for: currentTime) { return .red }
        if Calendar.current.isDateInToday(date) { return .orange }
        return .primary
    }

    private func daysRemaining(until date: Date) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: currentTime), to: cal.startOfDay(for: date)).day ?? 0
    }

    private func stripColor(for date: Date) -> Color {
        switch daysRemaining(until: date) {
        case ..<0:   return .red
        case 0..<7:  return .red
        case 7...21:return .orange
        default:     return .green
        }
    }

    private func daysRemainingText(for date: Date) -> String {
        let days = daysRemaining(until: date)
        switch days {
        case ..<0:  return "\(-days) day" + (abs(days) == 1 ? " overdue" : "s overdue")
        case 0:     return "Due Today"
        case 1:     return "Tomorrow"
        default:    return "\(days) days"
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"
        return df.string(from: date)
    }
}

// MARK: – Preview

struct AllDeadlinesView_Previews: PreviewProvider {
    static var previews: some View {
        AllDeadlinesView(viewModel: DeadlineViewModel.preview)
            .preferredColorScheme(.dark)
    }
}