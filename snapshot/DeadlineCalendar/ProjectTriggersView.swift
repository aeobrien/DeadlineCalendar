import SwiftUI

/// Shows *pending* triggers for a single project and lets the user activate them.
struct ProjectTriggersView: View {
    @ObservedObject var viewModel: DeadlineViewModel
    let project: Project                         // Injected from parent list
    
    // Date formatter for trigger display
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    /// Template order lookup so rows appear in the same order set in **Edit Template**.
    private var templateOrder: [UUID: Int] {
        guard
            let templateID = project.templateID,
            let template = viewModel.templates.first(where: { $0.id == templateID })
        else { return [:] }
        return Dictionary(
            uniqueKeysWithValues: template.templateTriggers.enumerated().map { ($0.element.id, $0.offset) }
        )
    }

    /// All triggers, sorted chronologically by date.
    private var allTriggers: [Trigger] {
        let triggers = viewModel.triggers(for: project.id)
            .sorted { first, second in
                // Handle nil dates (put them at the end)
                guard let firstDate = first.date else { return false }
                guard let secondDate = second.date else { return true }
                return firstDate < secondDate
            }
        
        // Debug output
        print("ProjectTriggersView: Project '\(project.title)' has \(triggers.count) triggers:")
        for trigger in triggers {
            print("  - Trigger '\(trigger.name)': isActive = \(trigger.isActive), date = \(trigger.date?.description ?? "nil")")
        }
        
        return triggers
    }

    var body: some View {
        List {
            if allTriggers.isEmpty {
                Text("No triggers.")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                ForEach(allTriggers) { trig in
                    Button {
                        print("ProjectTriggersView: Tapped trigger '\(trig.name)' with isActive = \(trig.isActive)")
                        if !trig.isActive {
                            viewModel.activateTrigger(triggerID: trig.id)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(trig.name)
                                    .strikethrough(trig.isActive, color: .gray)         // crosses out when activated
                                    .foregroundColor(trig.isActive ? .gray : .primary)
                                    .opacity(trig.isActive ? 0.6 : 1.0)
                                Spacer()
                                Image(systemName: trig.isActive ? "checkmark.circle" : "play.circle")
                                    .foregroundColor(trig.isActive ? .green : .blue)
                            }
                            
                            // Show trigger date
                            if let triggerDate = trig.date {
                                Text("Due: \(triggerDate, formatter: dateFormatter)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(trig.isActive)
                    .contextMenu {
                        if trig.isActive {
                            Button {
                                viewModel.deactivateTrigger(triggerID: trig.id)
                            } label: {
                                Label("Deactivate", systemImage: "xmark.circle")
                            }
                        } else {
                            Button {
                                viewModel.activateTrigger(triggerID: trig.id)
                            } label: {
                                Label("Activate", systemImage: "play.circle")
                            }
                        }
                    }
                }

            }
        }
        .navigationTitle(project.title)
        .preferredColorScheme(.dark)
    }
}
