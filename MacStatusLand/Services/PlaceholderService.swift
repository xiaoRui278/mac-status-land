import Foundation
import AppKit
import Combine

@available(macOS 14.0, *)
class PlaceholderService {
    static let shared = PlaceholderService()

    private init() {
        // Create placeholder immediately so it's added before main icon
        // This ensures it's always positioned to the left of the main icon
        createPlaceholder()
        setupObservers()
    }

    private var statusItem: NSStatusItem?
    private var mainButton: NSStatusBarButton?
    private var observation: NSKeyValueObservation?
    private var cancellables = Set<AnyCancellable>()

    private func createPlaceholder() {
        guard statusItem == nil else { return }
        // Create with initial width 0 (no space taken when disabled)
        statusItem = NSStatusBar.system.statusItem(withLength: 0)
        // Make completely transparent, no interaction
        statusItem?.button?.isTransparent = true
        statusItem?.button?.wantsLayer = true
        statusItem?.button?.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func setupObservers() {
        // Listen for setting changes
        SettingsService.shared.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleSettingChanged()
            }
        }.store(in: &cancellables)
    }

    /// Start observing position changes of the main button after main icon is created
    func startObserving(mainButton: NSStatusBarButton) {
        self.mainButton = mainButton

        // KVO observe frame changes (update width when user drags icon)
        observation = mainButton.observe(\.frame, options: [.new]) { [weak self] _, _ in
            guard let self = self, SettingsService.shared.autoHideLeftIcons else { return }
            self.updatePlaceholderWidth()
        }

        // Apply current setting
        handleSettingChanged()
    }

    /// Handle setting toggle
    private func handleSettingChanged() {
        let enabled = SettingsService.shared.autoHideLeftIcons

        if enabled {
            updatePlaceholderWidth()
        } else {
            // When disabled, set width back to 0 (no space taken)
            statusItem?.length = 0
        }
    }

    /// Update placeholder width based on main button position
    private func updatePlaceholderWidth() {
        guard let statusItem = statusItem,
              let mainButton = mainButton else {
            return
        }

        // Get main button frame in screen coordinates
        let buttonFrameInWindow = mainButton.convert(mainButton.bounds, to: nil)
        let buttonFrameInScreen = mainButton.window?.convertToScreen(buttonFrameInWindow)

        // Placeholder width = distance from screen left edge to main button left edge
        // This exactly fills the space from left screen edge to our icon
        // pushing all icons that would be in that space off-screen to the left
        let width = buttonFrameInScreen?.minX ?? 0

        // Update placeholder width
        if width > 0 {
            statusItem.length = width
        } else {
            // If width is near zero, main icon is at far left - no need for placeholder
            statusItem.length = 0
        }
    }

    deinit {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        observation = nil
        cancellables.removeAll()
    }
}
