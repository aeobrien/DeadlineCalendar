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

    /// Pending triggers, sorted by template order (fallback: alphabetic).
    private var pendingTriggers: [Trigger] {
        project.triggers
            .filter { !$0.isActive }
            .sorted {
                let first = templateOrder[$0.originatingTemplateTriggerID ?? UUID()] ?? Int.max
                let second = templateOrder[$1.originatingTemplateTriggerID ?? UUID()] ?? Int.max
                return first == second ? $0.name < $1.name : first < second
            }
    }

    var body: some View {
        List {
            if pendingTriggers.isEmpty {
                Text("No pending triggers.")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                ForEach(pendingTriggers) { trig in
                    Button {
                        viewModel.activateTrigger(triggerID: trig.id)
                    } label: {
                        HStack {
                            Text(trig.name)
                                .strikethrough(trig.isActive)         // crosses out when activated
                                .foregroundColor(trig.isActive ? .gray : .primary)
                            Spacer()
                            Image(systemName: trig.isActive ? "checkmark.circle" : "play.circle")
                                .foregroundColor(trig.isActive ? .green : .blue)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }

            }
        }
        .navigationTitle(project.title)
        .preferredColorScheme(.dark)
    }
}
