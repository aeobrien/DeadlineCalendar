import SwiftUI

struct CompletedTriggersView: View {
    @ObservedObject var viewModel: DeadlineViewModel
    @Environment(\.dismiss) var dismiss
    
    /// Projects that have all triggers activated (hidden from main triggers view)
    private var projectsWithAllTriggersActive: [Project] {
        viewModel.projects
            .filter { project in
                let projectTriggers = viewModel.triggers(for: project.id)
                return !projectTriggers.isEmpty && projectTriggers.allSatisfy { $0.isActive }
            }
            .sorted { $0.finalDeadlineDate < $1.finalDeadlineDate }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if projectsWithAllTriggersActive.isEmpty {
                    Text("No projects with all triggers activated.")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(.vertical, 50)
                } else {
                    List {
                        ForEach(projectsWithAllTriggersActive) { project in
                            ProjectTriggerSection(viewModel: viewModel, project: project)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Completed Triggers")
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
}

private struct ProjectTriggerSection: View {
    @ObservedObject var viewModel: DeadlineViewModel
    let project: Project
    
    private var projectTriggers: [Trigger] {
        viewModel.triggers(for: project.id)
            .sorted { trigger1, trigger2 in
                // Sort by activation date (newest first), then by name
                if let date1 = trigger1.activationDate, let date2 = trigger2.activationDate {
                    return date1 > date2
                }
                return trigger1.name < trigger2.name
            }
    }
    
    var body: some View {
        Section {
            ForEach(projectTriggers) { trigger in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trigger.name)
                            .font(.body)
                            .foregroundColor(.white)
                        
                        if let activationDate = trigger.activationDate {
                            Text("Activated: \(activationDate, formatter: dateFormatter)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        viewModel.deactivateTrigger(triggerID: trigger.id)
                    } label: {
                        Text("Deactivate")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text(project.title)
                .font(.headline)
                .foregroundColor(.white)
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

struct CompletedTriggersView_Previews: PreviewProvider {
    static var previews: some View {
        CompletedTriggersView(viewModel: DeadlineViewModel.preview)
            .preferredColorScheme(.dark)
    }
}