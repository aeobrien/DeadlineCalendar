import SwiftUI

struct TriggersView: View {
    @ObservedObject var viewModel: DeadlineViewModel

    /// Only projects that still have at least one inactive trigger
    private var projectsWithPending: [Project] {
        viewModel.projects
            .filter { project in
                viewModel.triggers(for: project.id).contains { !$0.isActive }
            }
            .sorted { $0.finalDeadlineDate < $1.finalDeadlineDate }
    }


    /// Pending-count helper
    private func pendingCount(for project: Project) -> Int {
        project.triggers.filter { !$0.isActive }.count
    }

    var body: some View {
        NavigationView {
            List {
                if projectsWithPending.isEmpty {
                    Text("No pending triggers.")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 50)
                        .listRowBackground(Color.black)
                } else {
                    ForEach(projectsWithPending) { project in
                        NavigationLink {
                            ProjectTriggersView(viewModel: viewModel, project: project)
                        } label: {
                            TriggerProjectRow(viewModel: viewModel, projectID: project.id)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Pending Triggers")
            .preferredColorScheme(.dark)
        }
        .navigationViewStyle(.stack)
    }
}
