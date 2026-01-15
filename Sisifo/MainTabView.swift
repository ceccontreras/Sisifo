//
//  MainTabView.swift
//  Sisifo
//
//  Created by Carlos Campos on 1/11/26.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home - Your existing ContentView
            ContentView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            // Calendar
            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(1)
            
            // Add - Now handles habit management
            ManageHabitsView()
                .tabItem {
                    Label("Habits", systemImage: "plus.circle.fill")
                }
                .tag(2)
            
            // Statistics - Placeholder for now
            StatisticsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                .tag(3)
            
            // Settings - Placeholder for now
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .accentColor(.orange)
    }
}

// MARK: - Placeholder Views

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Text("Settings View")
                .navigationTitle("Settings")
        }
    }
}

#Preview {
    MainTabView()
}
