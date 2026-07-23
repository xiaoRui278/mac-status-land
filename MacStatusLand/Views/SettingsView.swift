// MacStatusLand/MacStatusLand/Views/SettingsView.swift

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsService.shared
    @State private var loginItemService = LoginItemService.shared

    var body: some View {
        Form {
            Section("general_section".localized()) {
                Toggle("launch_at_login".localized(), isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { newValue in
                        settings.launchAtLogin = newValue
                        do {
                            if newValue {
                                try loginItemService.enable()
                            } else {
                                try loginItemService.disable()
                            }
                        } catch {
                            settings.launchAtLogin = !newValue
                        }
                    }
                ))

                Toggle("auto_close_focus_loss".localized(), isOn: $settings.autoCloseOnFocusLoss)

                Toggle("show_system_apps".localized(), isOn: $settings.showSystemApps)

                Toggle("settings.auto_hide_left_icons".localized(), isOn: $settings.autoHideLeftIcons)

                if settings.autoHideLeftIcons {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("settings.auto_hide_left_icons.hint".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, 4)
                }
            }

            Section("language_section".localized()) {
                Picker("app_language".localized(), selection: $settings.appLanguage) {
                    Text("简体中文").tag("zh")
                    Text("English").tag("en")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 400)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
