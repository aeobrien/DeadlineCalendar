import WidgetKit

class SharedDeadlineViewModel: ObservableObject {
    @Published var deadlines: [Deadline] = []

    private let deadlinesKey = "deadlines_key"
    private let userDefaults: UserDefaults

    init() {
        // Access the shared UserDefaults using the App Group identifier
        if let sharedDefaults = UserDefaults(suiteName: "group.com.yourapp.deadlines") {
            self.userDefaults = sharedDefaults
        } else {
            self.userDefaults = UserDefaults.standard
        }
        loadDeadlines()
    }

    func loadDeadlines() {
        if let data = userDefaults.data(forKey: deadlinesKey) {
            if let decoded = try? JSONDecoder().decode([Deadline].self, from: data) {
                self.deadlines = decoded
                return
            }
        }
        self.deadlines = []
    }
}
