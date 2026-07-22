// MacStatusLand/MacStatusLand/Views/SettingsView.swift

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsService.shared
    @State private var loginItemService = LoginItemService.shared
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var showAddPreset = false
    @State private var newPresetName = ""
    
    var body: some View {
        Form {
            // 通用设置
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
                            // 回滚
                            settings.launchAtLogin = !newValue
                        }
                    }
                ))
                
                Toggle("auto_close_focus_loss".localized(), isOn: $settings.autoCloseOnFocusLoss)
                
                Toggle("show_system_apps".localized(), isOn: $settings.showSystemApps)

                Toggle("settings.auto_hide_left_icons".localized(), isOn: $settings.autoHideLeftIcons)

                Picker("refresh_interval".localized(), selection: $settings.autoRefreshInterval) {
                    Text("15 秒").tag(15)
                    Text("30 秒").tag(30)
                    Text("60 秒").tag(60)
                    Text("120 秒").tag(120)
                }
            }
            
            // 快捷键
            Section("hotkey_section".localized()) {
                HotkeyRecorderView(hotkey: $settings.globalHotkey)
            }
            
            // 预设管理
            Section("presets_section".localized()) {
                ForEach(settings.presets) { preset in
                    HStack {
                        Text(preset.name)

                        Spacer()

                        Text("\(preset.visibleIcons.count) 个图标")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button(action: { deletePreset(preset) }) {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                        .onHover { isHovered in
                            withAnimation(.easeOut(duration: 0.15)) {
                                if !accessibilityReduceMotion {
                                    // Simple opacity change on hover
                                }
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                
                Button("add_preset".localized()) {
                    showAddPreset = true
                }
            }
            
            // 已隐藏图标
            Section("hidden_icons_section".localized()) {
                if settings.hiddenIcons.isEmpty {
                    Text("无隐藏图标")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(settings.hiddenIcons), id: \.self) { bundleId in
                        HStack {
                            Text(bundleId)
                                .font(.caption)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Button("restore_icon".localized()) {
                                settings.hiddenIcons.remove(bundleId)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
            
            // 语言
            Section("language_section".localized()) {
                Picker("app_language".localized(), selection: $settings.appLanguage) {
                    Text("简体中文").tag("zh")
                    Text("English").tag("en")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 500)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .alert("添加预设", isPresented: $showAddPreset) {
            TextField("预设名称", text: $newPresetName)
            Button("取消", role: .cancel) { }
            Button("添加") {
                addPreset()
            }
        }
    }
    
    // MARK: - 预设管理
    
    private func addPreset() {
        guard !newPresetName.isEmpty else { return }
        let preset = IconPreset(name: newPresetName, visibleIcons: [])
        settings.presets.append(preset)
        newPresetName = ""
    }
    
    private func deletePreset(_ preset: IconPreset) {
        settings.presets.removeAll { $0.id == preset.id }
    }
}

/// 快捷键录制视图
struct HotkeyRecorderView: View {
    @Binding var hotkey: HotkeyConfig?
    @State private var isRecording = false
    
    var body: some View {
        HStack {
            if let hotkey = hotkey {
                Text(hotkey.displayName)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
            } else {
                Text("未设置")
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(isRecording ? "按下快捷键..." : "录制") {
                isRecording.toggle()
            }
            .buttonStyle(.bordered)
            
            if hotkey != nil {
                Button("清除") {
                    hotkey = nil
                }
                .buttonStyle(.bordered)
            }
        }
    }
}