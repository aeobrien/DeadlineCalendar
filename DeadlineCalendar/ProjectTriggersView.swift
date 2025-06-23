import SwiftUI

/// Shows *pending* triggers for a single project and lets the user activate them.
struct ProjectTriggersView: View {
    @ObservedObject var viewModel: DeadlineViewModel
    let project: Project                         // Injected from parent list

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

    /// All triggers, sorted by template order (fallback: alphabetic).
    private var allTriggers: [Trigger] {
        let triggers = viewModel.triggers(for: project.id)
            .sorted {
                let first = templateOrder[$0.originatingTemplateTriggerID ?? UUID()] ?? Int.max
                let second = templateOrder[$1.originatingTemplateTriggerID ?? UUID()] ?? Int.max
                return first == second ? $0.name < $1.name : first < second
            }
        
        // Debug output
        print("ProjectTriggersView: Project '\(project.title)' has \(triggers.count) triggers:")
        for trigger in triggers {
            print("  - Trigger '\(trigger.name)': isActive = \(trigger.isActive), activationDate = \(trigger.activationDate?.description ?? "nil")")
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
                        HStack {
                            Text(trig.name)
                                .strikethrough(trig.isActive, color: .gray)         // crosses out when activated
                                .foregroundColor(trig.isActive ? .gray : .primary)
                                .opacity(trig.isActive ? 0.6 : 1.0)
                            Spacer()
                            Image(systemName: trig.isActive ? "checkmark.circle" : "play.circle")
                                .foregroundColor(trig.isActive ? .green : .blue)
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
