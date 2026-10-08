// DeadlineRow.swift (Widget Extension)

import SwiftUI

struct DeadlineRow: View {
    var subDeadline: SubDeadline
    var projectName: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(colorForDeadline)
                .frame(width: 6)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(projectName): \(subDeadline.title)")
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(formattedDate(date: subDeadline.date))
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Text(displayDaysRemaining)
                    .font(.caption)
                    .foregroundColor(daysRemaining <= 7 ? .red : .green)
            }
        }
        .padding(.vertical, 5)
    }
    
    private var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: subDeadline.date).day ?? 0
    }

    private var displayDaysRemaining: String {
        if daysRemaining < 0 {
            return "\(abs(daysRemaining)) days overdue"
        } else if daysRemaining == 0 {
            return "Due today"
        } else if daysRemaining == 1 {
            return "Due tomorrow"
        } else {
            return "\(daysRemaining) days remaining"
        }
    }
    
    private func formattedDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    private var colorForDeadline: Color {
        if daysRemaining < 0 {
            return .red
        } else if daysRemaining <= 7 {
            return .orange
        } else {
            return .green
        }
    }
}

