// MacStatusLand/MacStatusLand/Views/SettingsView.swift

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsService.shared
    @State private var loginItemService = LoginItemService.shared

    var body: some View {
        Form {
            Section("about_icons_section".localized()) {
                aboutIconsSection
            }

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
        .frame(width: 560, height: 560)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 图标说明

    private var aboutIconsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            iconExplanationRow(
                systemName: "list.bullet",
                title: "about_main_icon_title".localized(),
                desc: "about_main_icon_desc".localized(),
                tint: .accentColor
            )

            Divider()

            iconExplanationRow(
                systemName: "sidebar.left",
                title: "about_divider_icon_title".localized(),
                desc: "about_divider_icon_desc".localized(),
                tint: .accentColor
            )

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
                Text("about_order_warning".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    private func iconExplanationRow(systemName: String, title: String, desc: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
