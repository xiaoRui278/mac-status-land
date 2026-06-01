import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsService.shared
    @State private var language = SettingsService.shared.appLanguage
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            Divider()
                .padding(.horizontal, 16)
            
            Form {
                Section {
                    settingsToggle(
                        isOn: $settings.launchAtLogin,
                        icon: "power",
                        iconColor: .green,
                        title: "launch_at_login".localized
                    )
                    .onChange(of: settings.launchAtLogin) { newValue in
                        toggleLaunchAtLogin(newValue)
                    }
                }
                
                Section("section_display".localized) {
                    settingsPicker(
                        selection: $settings.autoRefreshInterval,
                        icon: "arrow.clockwise",
                        iconColor: .blue,
                        title: "auto_refresh".localized,
                        options: [
                            (0, "off".localized),
                            (15, "seconds".localized(15)),
                            (30, "seconds".localized(30)),
                            (60, "seconds".localized(60))
                        ]
                    )
                    
                    settingsToggle(
                        isOn: $settings.showSystemApps,
                        icon: "app.badge",
                        iconColor: .orange,
                        title: "show_system_apps".localized
                    )
                }
                
                Section("section_general".localized) {
                    settingsPicker(
                        selection: $language,
                        icon: "globe",
                        iconColor: .purple,
                        title: "language".localized,
                        options: [
                            ("zh", "中文"),
                            ("en", "English")
                        ]
                    )
                    .onChange(of: language) { newValue in
                        settings.appLanguage = newValue
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 400, height: 420)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 20))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("settings".localized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Text("settings_description".localized)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
    
    // MARK: - Reusable Components
    
    private func settingsToggle(
        isOn: Binding<Bool>,
        icon: String,
        iconColor: Color,
        title: String
    ) -> some View {
        Toggle(isOn: isOn) {
            Label {
                Text(title)
            } icon: {
                settingsIcon(name: icon, color: iconColor)
            }
        }
    }
    
    private func settingsPicker<T: Hashable>(
        selection: Binding<T>,
        icon: String,
        iconColor: Color,
        title: String,
        options: [(T, String)]
    ) -> some View {
        Picker(selection: selection) {
            ForEach(options, id: \.0) { value, label in
                Text(label).tag(value)
            }
        } label: {
            Label {
                Text(title)
            } icon: {
                settingsIcon(name: icon, color: iconColor)
            }
        }
        .pickerStyle(.menu)
    }
    
    private func settingsIcon(name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(color)
            )
    }
    
    // MARK: - Actions
    
    private func toggleLaunchAtLogin(_ enabled: Bool) {
    }
}

#Preview {
    SettingsView()
}
