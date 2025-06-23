import SwiftUI

struct CompletedDeadlinesView: View {
    @ObservedObject var viewModel: DeadlineViewModel
    @Environment(\.dismiss) var dismiss
    
    // Collect all completed deadlines
    private var completedDeadlines: [DeadlineListItem] {
        var items: [DeadlineListItem] = []
        
        for project in viewModel.projects {
            for sub in project.subDeadlines {
                guard sub.isCompleted else { continue }
                items.append(DeadlineListItem(
                    projectID: project.id,
                    projectName: project.title,
                    subDeadlineID: sub.id,
                    subDeadlineTitle: sub.title,
                    subDeadlineDate: sub.date,
                    isSubDeadlineCompleted: sub.isCompleted
                ))
            }
        }
        return items.sorted { $0.subDeadlineDate > $1.subDeadlineDate } // Most recent first
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if completedDeadlines.isEmpty {
                    Text("No completed deadlines")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    List {
                        ForEach(completedDeadlines) { item in
                            HStack(spacing: 12) {
                                // Check mark
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                
                                // Title
                                Text(item.projectID == DeadlineViewModel.standaloneProjectID ? item.subDeadlineTitle : "\(item.projectName) \(item.subDeadlineTitle)")
                                    .strikethrough()
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                // Date
                                Text(formattedDate(item.subDeadlineDate))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    uncomplete(item)
                                } label: {
                                    Label("Uncomplete", systemImage: "arrow.uturn.backward")
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