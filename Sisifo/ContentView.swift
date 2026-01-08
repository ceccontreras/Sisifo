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
                
                // Streak indicator
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(store.state.currentStreak)")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
            }
            
            HStack {
                ProgressView(value: progress)
                
                Text(store.todayDisplayString())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Celebration message
            if doneCount == total && total > 0 {
                HStack {
                    Text("🎉 All done today!")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                    Spacer()
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: doneCount)
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
