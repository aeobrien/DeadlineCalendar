import SwiftUI

struct TriggerProjectRow: View {
    @ObservedObject var viewModel: DeadlineViewModel
    let projectID: UUID

    /// Current project object (for the title)
    private var project: Project { viewModel.projects.first { $0.id == projectID }! }

    /// All triggers for this project
    private var triggers: [Trigger] { viewModel.triggers(for: projectID) }

    /// Template order map (so “next trigger” follows the template sequence)
    private var templateOrder: [UUID: Int] {
        guard
            let tid = project.templateID,
            let tpl = viewModel.templates.first(where: { $0.id == tid })
        else { return [:] }

        return Dictionary(uniqueKeysWithValues:
            tpl.templateTriggers.enumerated().map { ($0.element.id, $0.offset) })
    }

    // Progress
    private var completed: Int { triggers.filter(\.isActive).count }
    private var total: Int     { triggers.count }
    private var progress: Double { total == 0 ? 0 : Double(completed) / Double(total) }

    // Next pending trigger in template order
    private var nextTriggerName: String {
        let pending = triggers.filter { !$0.isActive }.sorted {
            (templateOrder[$0.originatingTemplateTriggerID ?? UUID()] ?? Int.max)
          < (templateOrder[$1.originatingTemplateTriggerID ?? UUID()] ?? Int.max)
        }
        return pending.first?.name ?? "All triggered"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Percentage badge
            Text("\(Int(progress * 100))%")
                .font(.caption).fontWeight(.bold)
                .frame(width: 40)
                .foregroundColor(progress == 1 ? .green : .orange)

            // Titles
            VStack(alignment: .leading, spacing: 2) {
                Text(project.title).font(.headline)
                Text("Next: \(nextTriggerName)")
                    .font(.subheadline).foregroundColor(.gray)
                Text("\(completed) / \(total) triggers")
                    .font(.caption)
                    .foregroundColor(progress == 1 ? .green : .orange)
            }

            Spacer()

            // Progress bar
            if total > 0 {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 60)
            }

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
}
