//
//  ContentView.swift
//  Sisifo
//
//  Created by Carlos Campos on 1/6/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = HabitStore()
    @State private var showingManageHabits = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                header

                List {
                    ForEach(store.state.habits) { habit in
                        HabitRow(
                            title: habit.title,
                            isDone: store.isDoneToday(habitID: habit.id)
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                store.markDoneToday(habitID: habit.id)
                            } label: {
                                Label("Done", systemImage: "checkmark")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                store.markUndoneToday(habitID: habit.id)
                            } label: {
                                Label("Undo", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.orange)
                        }
                    }

                    if store.state.habits.isEmpty {
                        Text("No habits yet. Tap Manage to add your daily checklist.")
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Manage") { showingManageHabits = true }
                }
            }
            .sheet(isPresented: $showingManageHabits) {
                ManageHabitsView(store: store)
            }
            .onAppear {
                store.refreshForNewDayIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                // When the app becomes active again, ensure day reset is correct
                if newPhase == .active {
                    store.refreshForNewDayIfNeeded()
                }
            }
        }
    }

    private var header: some View {
        let doneCount = store.todayDoneCount()
        let total = store.state.habits.count
        let progress = total == 0 ? 0 : Double(doneCount) / Double(total)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(doneCount)/\(total) done")
                    .font(.headline)
                Spacer()
                Text(store.todayDisplayString())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

private struct HabitRow: View {
    let title: String
    let isDone: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isDone ? .green : .secondary)

            Text(title)
                .strikethrough(isDone, color: .secondary)
                .foregroundStyle(isDone ? .secondary : .primary)

            Spacer()

            Text(isDone ? "Done" : "Swipe")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isDone ? "Done" : "Not done")
    }
}

#Preview {
    ContentView()
}
