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
                        SwipeableHabitRow(
                            habit: habit,
                            isDone: store.isDoneToday(habitID: habit.id),
                            onToggle: {
                                if store.isDoneToday(habitID: habit.id) {
                                    store.markUndoneToday(habitID: habit.id)
                                } else {
                                    store.markDoneToday(habitID: habit.id)
                                }
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.hidden)
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

private struct SwipeableHabitRow: View {
    let habit: Habit
    let isDone: Bool
    let onToggle: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    
    private let swipeThreshold: CGFloat = 80
    
    var body: some View {
        ZStack(alignment: .leading) {
            // The habit content (stays in place)
            HStack(spacing: 12) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isDone ? .green : .secondary)
                    .font(.title3)

                Text(habit.title)
                    .strikethrough(isDone, color: .secondary)
                    .foregroundStyle(isDone ? .secondary : .primary)

                Spacer()

                Image(systemName: isDone ? "arrow.left" : "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .opacity(isDragging ? 1 : 0.3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemBackground))
            
            // Color overlay that slides over the content
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    if isDone {
                        Spacer()
                        Rectangle()
                            .fill(Color.orange.opacity(0.3))
                            .frame(width: abs(offset))
                    } else {
                        Rectangle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: offset)
                        Spacer()
                    }
                }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    isDragging = true
                    let translation = gesture.translation.width
                    if isDone {
                        offset = min(0, translation)
                    } else {
                        offset = max(0, translation)
                    }
                }
                .onEnded { gesture in
                    isDragging = false
                    let translation = gesture.translation.width
                    if isDone && translation < -swipeThreshold {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = 0
                        }
                        onToggle()
                    } else if !isDone && translation > swipeThreshold {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = 0
                        }
                        onToggle()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            offset = 0
                        }
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(habit.title)
        .accessibilityValue(isDone ? "Done" : "Not done")
        .accessibilityHint(isDone ? "Swipe left to undo" : "Swipe right to mark done")
    }
}

#Preview {
    ContentView()
}
