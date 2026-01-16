//
//  SettingsView.swift
//  Sisifo
//
//  Created by Carlos Campos on 1/15/26.
//

import SwiftUI
import Combine

// MARK: - Theme & Accent Enums

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppAccent: String, Codable, CaseIterable, Identifiable {
    case orange = "Orange"
    case blue = "Blue"
    case green = "Green"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .orange: return .orange
        case .blue: return .blue
        case .green: return .green
        }
    }
}

// MARK: - Settings Store

final class SettingsStore: ObservableObject {
    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "app_theme")
        }
    }
    
    @Published var accent: AppAccent {
        didSet {
            UserDefaults.standard.set(accent.rawValue, forKey: "app_accent")
        }
    }
    
    init() {
        // Load theme
        if let themeString = UserDefaults.standard.string(forKey: "app_theme"),
           let savedTheme = AppTheme(rawValue: themeString) {
            self.theme = savedTheme
        } else {
            self.theme = .system
        }
        
        // Load accent
        if let accentString = UserDefaults.standard.string(forKey: "app_accent"),
           let savedAccent = AppAccent(rawValue: accentString) {
            self.accent = savedAccent
        } else {
            self.accent = .orange
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Appearance & Experience
                Section("Appearance & Experience") {
                    // Theme Picker
                    Picker("Theme", selection: $settings.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    // Accent Color Picker
                    Picker("Accent Color", selection: $settings.accent) {
                        ForEach(AppAccent.allCases) { accent in
                            HStack {
                                Circle()
                                    .fill(accent.color)
                                    .frame(width: 20, height: 20)
                                Text(accent.rawValue)
                            }
                            .tag(accent)
                        }
                    }
                }
                
                // MARK: - About / Philosophy
                Section("About") {
                    // App metadata
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "app.fill")
                                .font(.largeTitle)
                                .foregroundStyle(settings.accent.color)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sisifo")
                                    .font(.headline)
                                Text("Version \(appVersion()) (\(buildNumber()))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Philosophy
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Philosophy")
                            .font(.subheadline)
                            .bold()
                        
                        Text("Sisifo is about showing up. Not perfection.")
                            .font(.body)
                        
                        Text("Like Sisyphus eternally pushing his boulder up the mountain, we embrace the daily practice of building habits—not because we'll reach some final destination, but because the act of showing up, day after day, is itself meaningful.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        
                        Text("Built by Carlos Campos")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    // MARK: - Helper Functions
    
    private func appVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private func buildNumber() -> String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
