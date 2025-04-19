// DeadlineRow.swift (Widget Extension)

import SwiftUI

struct DeadlineRow: View {
    var deadline: Deadline
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(colorForDeadline)
                .frame(width: 6)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(deadline.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(formattedDate(deadline: deadline))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text(displayDaysRemaining)
                    .font(.caption)
                    .foregroundColor(daysRemaining <= 7 ? .red : .green)
            }
        }
        .padding(.vertical, 5)
        .background(Color.black)
    }
    
    func formattedDate(deadline: Deadline) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: deadline.date)
    }
    
    var colorForDeadline: Color {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: deadline.date).day ?? 0
        if days < 0 {
            return .red
        } else if days <= 7 {
            return .orange
        } else {
            return .green
        }
    }
}

