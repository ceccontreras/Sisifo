//
//  StatisticsView.swift
//  Sisifo
//
//  Created by Carlos Campos on 1/14/26.
//

import SwiftUI

// MARK: - Time Range Filter

enum TimeRange: String, CaseIterable {
    case week = "7D"
    case month = "30D"
    case all = "All"
    
    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .all: return nil
        }
    }
}

// MARK: - Statistics Models

struct HabitStats {
    let habitID: UUID
    let habitTitle: String
    let completedCount: Int
    let totalDays: Int
    
    var completionRate: Double {
        guard totalDays > 0 else { return 0 }
        return Double(completedCount) / Double(totalDays)
    }
    
    var completionPercentage: Int {
        Int((completionRate * 100).rounded())
    }
}

struct OverallStats {
    let totalCompletions: Int
    let totalPossible: Int
    let averagePerDay: Double
    
    var completionRate: Double {
        guard totalPossible > 0 else { return 0 }
        return Double(totalCompletions) / Double(totalPossible)
    }
    
    var completionPercentage: Int {
        Int((completionRate * 100).rounded())
    }
}

// MARK: - Statistics View

struct StatisticsView: View {
    @StateObject private var store = HabitStore()
    @State private var selectedRange: TimeRange = .week
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Time range picker
                    Picker("Time Range", selection: $selectedRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Overall performance card
                    if let overall = calculateOverallStats() {
                        OverallStatsCard(stats: overall, range: selectedRange)
                    }
                    
                    // Habit leaderboard
                    HabitLeaderboardSection(
                        habitStats: calculateHabitStats(),
                        range: selectedRange
                    )
                    
                    // Streak summary (optional)
                    StreakSummaryCard(
                        currentStreak: store.state.currentStreak,
                        bestStreak: store.state.bestStreak
                    )
                }
                .padding(.bottom, 16)
            }
            .navigationTitle("Statistics")
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
    
    // MARK: - Statistics Calculations
    
    /// Calculate overall completion statistics for the selected time range
    private func calculateOverallStats() -> OverallStats? {
        let dateKeys = getDateKeysInRange()
        guard !dateKeys.isEmpty else { return nil }
        
        let currentHabits = store.state.habits
        guard !currentHabits.isEmpty else { return nil }
        
        var totalCompletions = 0
        var totalPossible = 0
        
        for dateKey in dateKeys {
            // Count how many habits existed and were completed on this date
            let completedIDs = store.state.doneByDate[dateKey] ?? []
            
            // Only count completions for habits that still exist
            let validCompletions = completedIDs.filter { id in
                currentHabits.contains { $0.id == id }
            }
            
            totalCompletions += validCompletions.count
            totalPossible += currentHabits.count
        }
        
        let avgPerDay = dateKeys.isEmpty ? 0 : Double(totalCompletions) / Double(dateKeys.count)
        
        return OverallStats(
            totalCompletions: totalCompletions,
            totalPossible: totalPossible,
            averagePerDay: avgPerDay
        )
    }
    
    /// Calculate per-habit statistics for the selected time range
    private func calculateHabitStats() -> [HabitStats] {
        let dateKeys = getDateKeysInRange()
        guard !dateKeys.isEmpty else { return [] }
        
        let currentHabits = store.state.habits
        guard !currentHabits.isEmpty else { return [] }
        
        let totalDays = dateKeys.count
        
        return currentHabits.map { habit in
            var completedCount = 0
            
            // Count how many days this habit was completed
            for dateKey in dateKeys {
                if store.state.doneByDate[dateKey]?.contains(habit.id) == true {
                    completedCount += 1
                }
            }
            
            return HabitStats(
                habitID: habit.id,
                habitTitle: habit.title,
                completedCount: completedCount,
                totalDays: totalDays
            )
        }
        .sorted { $0.completionRate > $1.completionRate } // Sort by completion rate
    }
    
    /// Get all date keys within the selected time range
    /// For 7D/30D: generates keys for last N days (including today), even if missing from doneByDate
    /// For All: returns all keys present in doneByDate
    private func getDateKeysInRange() -> [String] {
        switch selectedRange {
        case .all:
            // Return all dates that exist in doneByDate, sorted
            return store.state.doneByDate.keys.sorted()
            
        case .week, .month:
            guard let days = selectedRange.days else { return [] }
            
            let calendar = Calendar.current
            let today = Date()
            var dateKeys: [String] = []
            
            // Generate date keys for the last N days (including today)
            for dayOffset in (0..<days).reversed() {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                    continue
                }
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let key = formatter.string(from: date)
                dateKeys.append(key)
            }
            
            return dateKeys
        }
    }
}

// MARK: - Overall Stats Card

struct OverallStatsCard: View {
    let stats: OverallStats
    let range: TimeRange
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Overall Completion")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text("\(stats.completionPercentage)%")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.orange)
            }
            
            HStack(spacing: 32) {
                StatItem(
                    label: "Completed",
                    value: "\(stats.totalCompletions)"
                )
                
                Divider()
                    .frame(height: 40)
                
                StatItem(
                    label: "Total Possible",
                    value: "\(stats.totalPossible)"
                )
                
                Divider()
                    .frame(height: 40)
                
                StatItem(
                    label: "Avg/Day",
                    value: String(format: "%.1f", stats.averagePerDay)
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .bold()
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Habit Leaderboard Section

struct HabitLeaderboardSection: View {
    let habitStats: [HabitStats]
    let range: TimeRange
    
    var topHabit: HabitStats? {
        habitStats.first
    }
    
    var bottomHabit: HabitStats? {
        // Only show bottom if there are at least 2 habits
        guard habitStats.count > 1 else { return nil }
        return habitStats.last
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Habit Performance")
                .font(.headline)
                .padding(.horizontal)
            
            if habitStats.isEmpty {
                Text("No habit data available for this time range.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 12) {
                    // Top performer
                    if let top = topHabit {
                        HabitStatRow(
                            stats: top,
                            badge: "👑",
                            badgeColor: .green,
                            label: "Top Habit"
                        )
                    }
                    
                    // Bottom performer (if exists)
                    if let bottom = bottomHabit {
                        HabitStatRow(
                            stats: bottom,
                            badge: "📉",
                            badgeColor: .orange,
                            label: "Needs Attention"
                        )
                    }
                    
                    // All habits list
                    VStack(alignment: .leading, spacing: 8) {
                        Text("All Habits")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        ForEach(habitStats, id: \.habitID) { stats in
                            HabitProgressRow(stats: stats)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct HabitStatRow: View {
    let stats: HabitStats
    let badge: String
    let badgeColor: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(badge)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(stats.habitTitle)
                    .font(.headline)
                
                Text("\(stats.completedCount)/\(stats.totalDays) days · \(stats.completionPercentage)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("\(stats.completionPercentage)%")
                .font(.title2)
                .bold()
                .foregroundStyle(badgeColor)
        }
        .padding()
        .background(badgeColor.opacity(0.1))
        .cornerRadius(10)
    }
}

struct HabitProgressRow: View {
    let stats: HabitStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(stats.habitTitle)
                    .font(.subheadline)
                
                Spacer()
                
                Text("\(stats.completionPercentage)%")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.orange)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(uiColor: .systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange)
                        .frame(width: geometry.size.width * stats.completionRate, height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(stats.completedCount) of \(stats.totalDays) days")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Streak Summary Card

struct StreakSummaryCard: View {
    let currentStreak: Int
    let bestStreak: Int
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Streak Summary")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                StreakItem(
                    icon: "flame.fill",
                    color: .orange,
                    label: "Current",
                    value: currentStreak
                )
                
                StreakItem(
                    icon: "trophy.fill",
                    color: .yellow,
                    label: "Best",
                    value: bestStreak
                )
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct StreakItem: View {
    let icon: String
    let color: Color
    let label: String
    let value: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("\(value) days")
                    .font(.headline)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(10)
    }
}

#Preview {
    StatisticsView()
}
