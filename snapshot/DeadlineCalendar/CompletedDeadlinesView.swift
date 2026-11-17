import SwiftUI

struct CompletedDeadlinesView: View {
    @ObservedObject var viewModel: DeadlineViewModel
    @Environment(\.dismiss) var dismiss
    
    // Collect all completed deadlines and activated triggers
    private var completedDeadlines: [DeadlineListItem] {
        var items: [DeadlineListItem] = []
        
        // Add completed sub-deadlines
        for project in viewModel.projects {
            for sub in project.subDeadlines {
                guard sub.isCompleted else { continue }
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
        
        // Add activated triggers
        for trigger in viewModel.triggers {
            guard trigger.isActive else { continue }
            guard let date = trigger.date else { continue }
            
            // Find which project this trigger belongs to
            var triggerProjectName = ""
            for project in viewModel.projects {
                if project.triggers.contains(where: { $0.id == trigger.id }) {
                    triggerProjectName = project.title
                    break
                }
            }
            
            items.append(DeadlineListItem(
                projectID: UUID(), // Use a dummy ID since triggers don't have a project ID in this context
                projectName: triggerProjectName,
                subDeadlineID: nil,
                subDeadlineTitle: trigger.name,
                subDeadlineDate: date,
                isSubDeadlineCompleted: false,
                triggerID: trigger.id,
                isTrigger: true
            ))
        }
        
        return items.sorted { $0.subDeadlineDate > $1.subDeadlineDate } // Most recent first
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if completedDeadlines.isEmpty {
                    Text("No completed deadlines or activated triggers")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    List {
                        ForEach(completedDeadlines) { item in
                            HStack(spacing: 12) {
                                // Icon - different for triggers vs deadlines
                                if item.isTrigger {
                                    Image(systemName: "play.circle.fill")
                                        .foregroundColor(.blue)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                                
                                // Title
                                Text(item.projectID == DeadlineViewModel.standaloneProjectID ? item.subDeadlineTitle : "\(item.projectName) \(item.subDeadlineTitle)")
                                    .strikethrough(!item.isTrigger)
                                    .foregroundColor(item.isTrigger ? .primary : .gray)
                                
                                Spacer()
                                
                                // Date
                                Text(formattedDate(item.subDeadlineDate))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    if item.isTrigger {
                                        untrigger(item)
                                    } else {
                                        uncomplete(item)
                                    }
                                } label: {
                                    if item.isTrigger {
                                        Label("Deactivate", systemImage: "play.slash")
                                    } else {
                                        Label("Uncomplete", systemImage: "arrow.uturn.backward")
                                    }
                                }
                                .tint(.orange)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Completed Deadlines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func uncomplete(_ item: DeadlineListItem) {
        guard let project = viewModel.projects.first(where: { $0.id == item.projectID }),
              let sub = project.subDeadlines.first(where: { $0.id == item.subDeadlineID }) else { return }
        viewModel.toggleSubDeadlineCompletion(sub, in: project)
    }
    
    private func untrigger(_ item: DeadlineListItem) {
        guard let triggerID = item.triggerID else { return }
        viewModel.deactivateTrigger(triggerID: triggerID)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"
        return df.string(from: date)
    }
}

struct CompletedDeadlinesView_Previews: PreviewProvider {
    static var previews: some View {
        CompletedDeadlinesView(viewModel: DeadlineViewModel.preview)
            .preferredColorScheme(.dark)
    }
}