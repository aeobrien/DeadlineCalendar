import SwiftUI

struct TriggersView: View {
    @ObservedObject var viewModel: DeadlineViewModel
    @State private var showingCompletedTriggersSheet = false

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
        viewModel.triggers(for: project.id).filter { !$0.isActive }.count
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
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
            
            // Bottom button bar
            HStack {
                Spacer()
                
                Button {
                    showingCompletedTriggersSheet = true
                } label: {
                    Label("Completed Triggers", systemImage: "checkmark.circle.fill")
                        .font(.body)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.9))
            }
            .navigationTitle("Pending Triggers")
            .preferredColorScheme(.dark)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showingCompletedTriggersSheet) {
            CompletedTriggersView(viewModel: viewModel)
        }
    }
}
