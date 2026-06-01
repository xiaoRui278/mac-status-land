import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            Form {
                Section {
                    Toggle(isOn: $settings.launchAtLogin) {
                        Label {
                            Text("launch_at_login".localized)
                        } icon: {
                            Image(systemName: "power")
                        }
                    }
                    .onChange(of: settings.launchAtLogin) { newValue in
                        toggleLaunchAtLogin(newValue)
                    }
                }
                
                Section {
                    Picker(selection: $settings.autoRefreshInterval) {
                        Text("off".localized).tag(0)
                        Text("seconds".localized(15)).tag(15)
                        Text("seconds".localized(30)).tag(30)
                        Text("seconds".localized(60)).tag(60)
                    } label: {
                        Label {
                            Text("auto_refresh".localized)
                        } icon: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Toggle(isOn: $settings.showSystemApps) {
                        Label {
                            Text("show_system_apps".localized)
                        } icon: {
                            Image(systemName: "app.badge")
                        }
                    }
                }
                
                Section {
                    Picker(selection: $settings.appLanguage) {
                        Text("中文").tag("zh")
                        Text("English").tag("en")
                    } label: {
                        Label {
                            Text("language".localized)
                        } icon: {
                            Image(systemName: "globe")
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 380, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("settings".localized)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("settings_description".localized)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func toggleLaunchAtLogin(_ enabled: Bool) {
    }
}

#Preview {
    SettingsView()
}
