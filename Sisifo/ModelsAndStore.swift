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
struct AppState: Codable {
    var habits: [Habit] = []
    var doneByDate: [String: Set<UUID>] = [:]
    var lastOpenedDateKey: String = ""

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
            // In v1 we’ll fail silently; you can add logging later
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
            state.lastOpenedDateKey = key
            // we do NOT delete past days — keeps door open for history later
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

struct ManageHabitsView: View {
    @ObservedObject var store: HabitStore
    @Environment(\.dismiss) private var dismiss
    @State private var newHabitTitle: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Add") {
                    HStack {
                        TextField("Example: Run 5 miles", text: $newHabitTitle)
                        Button("Add") {
                            store.addHabit(title: newHabitTitle)
                            newHabitTitle = ""
                        }
                        .disabled(newHabitTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section("Habits") {
                    if store.state.habits.isEmpty {
                        Text("No habits yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        List {
                            ForEach(store.state.habits) { habit in
                                Text(habit.title)
                            }
                            .onDelete(perform: store.deleteHabits)
                            .onMove(perform: store.moveHabits)
                        }
                        .frame(minHeight: 200)
                    }
                }
            }
            .navigationTitle("Manage Habits")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }
}
