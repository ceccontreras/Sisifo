//
//  ModelsAndStore.swift
//  Sisifo
//
//  Created by Carlos Campos on 1/6/26.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Models

struct Habit: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }
}

/// AppState persisted to JSON.
/// - habits: your master list
/// - doneByDate: dictionary of "YYYY-MM-DD" -> set of habit IDs completed that day
/// - lastOpenedDateKey: used for reset logic
/// - currentStreak: consecutive days with all habits completed
/// - bestStreak: highest streak ever achieved
struct AppState: Codable {
    var habits: [Habit] = []
    var doneByDate: [String: Set<UUID>] = [:]
    var lastOpenedDateKey: String = ""
    var currentStreak: Int = 0
    var bestStreak: Int = 0

    static func emptyWithDefaults() -> AppState {
        var s = AppState()
        s.habits = [
            Habit(title: "Take pills"),
            Habit(title: "Drink creatine"),
            Habit(title: "Run 3 miles"),
            Habit(title: "Read 10 pages")
        ]
        s.lastOpenedDateKey = DateKey.today()
        return s
    }
}

// MARK: - DateKey Helper

enum DateKey {
    /// Returns "YYYY-MM-DD" in the user's current calendar/timezone
    static func today() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    static func prettyToday() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }
    
    /// Returns date for a given key string "YYYY-MM-DD"
    static func date(from key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }
    
    /// Returns yesterday's date key
    static func yesterday() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else {
            return ""
        }
        return formatter.string(from: yesterday)
    }
}

// MARK: - JSON Persistence

final class JSONStore {
    private let filename = "habits_state.json"

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(filename)
    }

    func load() -> AppState {
        do {
            let url = fileURL
            guard FileManager.default.fileExists(atPath: url.path) else {
                return AppState.emptyWithDefaults()
            }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(AppState.self, from: data)
        } catch {
            // If decoding fails, fall back to defaults (keeps app usable)
            return AppState.emptyWithDefaults()
        }
    }

    func save(_ state: AppState) {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // In v1 we'll fail silently; you can add logging later
        }
    }
}

// MARK: - Store (ObservableObject)

@MainActor
final class HabitStore: ObservableObject {
    @Published private(set) var state: AppState

    private let store = JSONStore()

    init() {
        self.state = store.load()
        refreshForNewDayIfNeeded()
    }

    // MARK: - Today helpers

    func todayKey() -> String { DateKey.today() }

    func todayDisplayString() -> String { DateKey.prettyToday() }

    func isDoneToday(habitID: UUID) -> Bool {
        let key = todayKey()
        return state.doneByDate[key]?.contains(habitID) == true
    }

    func todayDoneCount() -> Int {
        let key = todayKey()
        return state.doneByDate[key]?.count ?? 0
    }

    // MARK: - Actions

    func markDoneToday(habitID: UUID) {
        let key = todayKey()
        var set = state.doneByDate[key] ?? []
        set.insert(habitID)
        state.doneByDate[key] = set
        
        // Check if all habits are now complete and update streak
        checkAndUpdateStreak()
        
        persist()
    }

    func markUndoneToday(habitID: UUID) {
        let key = todayKey()
        var set = state.doneByDate[key] ?? []
        set.remove(habitID)
        state.doneByDate[key] = set
        persist()
    }

    func refreshForNewDayIfNeeded() {
        let key = todayKey()

        // If first launch or date changed, we "reset" by ensuring today's set exists and updating lastOpenedDateKey
        if state.lastOpenedDateKey != key {
            // Before moving to new day, check if yesterday was complete
            updateStreakForNewDay()
            
            state.lastOpenedDateKey = key
            // we do NOT delete past days – keeps door open for history later
            if state.doneByDate[key] == nil {
                state.doneByDate[key] = []
            }
            persist()
        } else {
            // Ensure today's bucket exists
            if state.doneByDate[key] == nil {
                state.doneByDate[key] = []
                persist()
            }
        }
    }

    // MARK: - Streak Logic
    
    private func checkAndUpdateStreak() {
        let today = todayKey()
        guard let todayDone = state.doneByDate[today] else { return }
        
        // Only count as complete if ALL habits are done
        let allHabitsCount = state.habits.count
        guard allHabitsCount > 0 else { return }
        
        if todayDone.count == allHabitsCount {
            // Today is complete! But we don't increment streak until tomorrow
            // (streak is for consecutive COMPLETED days)
            persist()
        }
    }
    
    private func updateStreakForNewDay() {
        let yesterday = DateKey.yesterday()
        guard !yesterday.isEmpty else { return }
        
        let allHabitsCount = state.habits.count
        guard allHabitsCount > 0 else {
            // No habits, reset streak
            state.currentStreak = 0
            return
        }
        
        // Check if yesterday was complete
        let yesterdayDone = state.doneByDate[yesterday]?.count ?? 0
        
        if yesterdayDone == allHabitsCount {
            // Yesterday was complete, increment streak
            state.currentStreak += 1
            
            // Update best streak if needed
            if state.currentStreak > state.bestStreak {
                state.bestStreak = state.currentStreak
            }
        } else {
            // Streak broken
            state.currentStreak = 0
        }
    }

    // MARK: - Habit management

    func addHabit(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.habits.append(Habit(title: trimmed))
        persist()
    }

    func deleteHabits(at offsets: IndexSet) {
        // Remove their "done" record from all dates too
        let idsToDelete = offsets.map { state.habits[$0].id }
        state.habits.remove(atOffsets: offsets)

        for (dateKey, set) in state.doneByDate {
            var updated = set
            idsToDelete.forEach { updated.remove($0) }
            state.doneByDate[dateKey] = updated
        }

        persist()
    }

    func moveHabits(from source: IndexSet, to destination: Int) {
        state.habits.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        store.save(state)
    }
}

// MARK: - Manage Habits View

// MARK: - Manage Habits View

struct ManageHabitsView: View {
    @StateObject private var store = HabitStore()
    @State private var newHabitTitle: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Add New Habit") {
                    HStack {
                        TextField("Example: Run 5 miles", text: $newHabitTitle)
                            .submitLabel(.done)
                            .onSubmit {
                                addHabit()
                            }
                        
                        Button {
                            addHabit()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.orange)
                                .font(.title2)
                        }
                        .disabled(newHabitTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section("Your Habits") {
                    if store.state.habits.isEmpty {
                        Text("No habits yet. Add your first habit above!")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(store.state.habits) { habit in
                            Text(habit.title)
                        }
                        .onDelete(perform: store.deleteHabits)
                        .onMove(perform: store.moveHabits)
                    }
                }
                
                Section("Streaks") {
                    HStack {
                        Label("Current Streak", systemImage: "flame.fill")
                        Spacer()
                        Text("\(store.state.currentStreak) days")
                            .foregroundStyle(.orange)
                            .bold()
                    }
                    
                    HStack {
                        Label("Best Streak", systemImage: "trophy.fill")
                        Spacer()
                        Text("\(store.state.bestStreak) days")
                            .foregroundStyle(.yellow)
                            .bold()
                    }
                }
            }
            .navigationTitle("Manage Habits")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }
    
    private func addHabit() {
        store.addHabit(title: newHabitTitle)
        newHabitTitle = ""
    }
}
