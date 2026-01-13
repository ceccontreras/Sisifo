//
//  CalendarView.swift
//  Sisifo
//

import SwiftUI

struct CalendarView: View {
    @StateObject private var store = HabitStore()
    @State private var selectedDate = Date()
    
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month and year header with navigation
                HStack {
                    Button {
                        changeMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundStyle(.orange)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text(monthYearString)
                            .font(.title2)
                            .bold()
                        
                        if !isCurrentMonth {
                            Button("Today") {
                                selectedDate = Date()
                            }
                            .font(.caption)
                            .foregroundStyle(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        changeMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundStyle(.orange)
                    }
                }
                .padding()
                
                // Days of week header
                HStack(spacing: 0) {
                    ForEach(daysOfWeek, id: \.self) { day in
                        Text(day)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                    ForEach(daysInMonth, id: \.self) { day in
                        if day == 0 {
                            // Empty space
                            Color.clear
                                .frame(height: 50)
                        } else {
                            DayCell(
                                day: day,
                                isCompleted: isDateCompleted(day: day),
                                isToday: isToday(day: day),
                                isCurrentMonth: isCurrentMonth
                            )
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Legend
                VStack(spacing: 12) {
                    HStack(spacing: 20) {
                        LegendItem(color: .green, text: "All habits completed")
                        LegendItem(color: .orange, text: "Today")
                    }
                    .font(.caption)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding()
            }
            .navigationTitle("Calendar")
        }
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }
    
    private var isCurrentMonth: Bool {
        let calendar = Calendar.current
        let now = Date()
        return calendar.component(.year, from: selectedDate) == calendar.component(.year, from: now) &&
               calendar.component(.month, from: selectedDate) == calendar.component(.month, from: now)
    }
    
    private var daysInMonth: [Int] {
        var days: [Int] = []
        let calendar = Calendar.current
        
        let year = calendar.component(.year, from: selectedDate)
        let month = calendar.component(.month, from: selectedDate)
        
        // Get first day of month
        let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let weekday = calendar.component(.weekday, from: firstDay) // 1 = Sunday
        
        // Add empty spaces for days before the first day
        for _ in 1..<weekday {
            days.append(0)
        }
        
        // Get number of days in month
        let range = calendar.range(of: .day, in: .month, for: firstDay)!
        
        // Add actual days
        for day in 1...range.count {
            days.append(day)
        }
        
        return days
    }
    
    private func isDateCompleted(day: Int) -> Bool {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: selectedDate)
        let month = calendar.component(.month, from: selectedDate)
        
        let dateKey = String(format: "%04d-%02d-%02d", year, month, day)
        let totalHabits = store.state.habits.count
        
        guard totalHabits > 0 else { return false }
        
        let completedCount = store.state.doneByDate[dateKey]?.count ?? 0
        return completedCount == totalHabits
    }
    
    private func isToday(day: Int) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        let year = calendar.component(.year, from: selectedDate)
        let month = calendar.component(.month, from: selectedDate)
        
        return calendar.component(.year, from: now) == year &&
               calendar.component(.month, from: now) == month &&
               calendar.component(.day, from: now) == day
    }
    
    private func changeMonth(by value: Int) {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: value, to: selectedDate) {
            selectedDate = newDate
        }
    }
}

struct DayCell: View {
    let day: Int
    let isCompleted: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    
    var body: some View {
        ZStack {
            if isCompleted {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green)
            } else if isToday {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.orange, lineWidth: 2)
            }
            
            Text("\(day)")
                .font(.body)
                .foregroundStyle(isCompleted ? .white : (isToday ? .orange : .primary))
                .bold(isToday || isCompleted)
        }
        .frame(height: 50)
    }
}

struct LegendItem: View {
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 16, height: 16)
            
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    CalendarView()
}
