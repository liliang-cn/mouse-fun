//
//  MenuBarController.swift
//  mouse-fun
//
//  Created by liliang on 2025/11/7.
//

import Cocoa
import SwiftUI

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var cursorManager = CursorManager.shared
    private var currentEmoji: String?
    private var currentStyle: CursorStyle?

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Try to load the menubar template icon
            var iconURL = Bundle.main.url(forResource: "menubar-template", withExtension: "svg", subdirectory: "Resources")
            if iconURL == nil {
                iconURL = Bundle.main.url(forResource: "menubar-template", withExtension: "svg")
            }

            if let url = iconURL,
               let iconData = try? Data(contentsOf: url),
               let image = NSImage(data: iconData) {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                button.image = image
            } else {
                // Fallback to SF Symbol
                let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
                if let image = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "Mouse Fun") {
                    button.image = image.withSymbolConfiguration(config)
                }
            }
            button.toolTip = "Mouse-Fun"
        }

        constructMenu()
    }

    private func constructMenu() {
        let menu = NSMenu()

        // Title
        let titleItem = NSMenuItem(title: "Mouse-Fun", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        // Add all cursor styles
        for style in CursorStyle.allCases {
            if style == .customEmoji {
                menu.addItem(NSMenuItem.separator())
            }

            let menuItem = NSMenuItem(title: style.displayName, action: #selector(cursorStyleSelected(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = style

            // Add icon for SVG-based cursors
            if let svgName = style.svgFileName {
                if let icon = loadMenuIcon(svgName: svgName) {
                    menuItem.image = icon
                }
            }

            menu.addItem(menuItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Settings submenu
        let settingsMenu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        settingsItem.submenu = settingsMenu

        // Cursor size options
        let sizeMenu = NSMenu()
        for size in CursorSize.allCases {
            let sizeItem = NSMenuItem(title: size.displayName, action: #selector(cursorSizeSelected(_:)), keyEquivalent: "")
            sizeItem.target = self
            sizeItem.representedObject = size
            sizeMenu.addItem(sizeItem)
        }

        let sizeMenuItem = NSMenuItem(title: "Cursor Size", action: nil, keyEquivalent: "")
        sizeMenuItem.submenu = sizeMenu
        settingsMenu.addItem(sizeMenuItem)

        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())

        // Reset
        let resetItem = NSMenuItem(title: "Reset to Default", action: #selector(resetCursor), keyEquivalent: "r")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Mouse-Fun", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func cursorStyleSelected(_ sender: NSMenuItem) {
        guard let style = sender.representedObject as? CursorStyle else { return }

        currentStyle = style  // Store current style

        if style == .customEmoji {
            showEmojiInputDialog()
        } else if style == .defaultCursor {
            cursorManager.resetToDefault()
            currentEmoji = nil
            currentStyle = nil
        } else if let svgName = style.svgFileName {
            let size = UserDefaults.standard.cursorSize
            cursorManager.setCursorFromSVG(named: svgName, size: CGSize(width: size, height: size))
            currentEmoji = nil
        }
    }

    @objc private func cursorSizeSelected(_ sender: NSMenuItem) {
        guard let size = sender.representedObject as? CursorSize else { return }
        UserDefaults.standard.cursorSize = size.rawValue

        // Reapply current cursor with new size
        reapplyCurrentCursor()
    }

    @objc private func resetCursor() {
        cursorManager.resetToDefault()
        currentEmoji = nil
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func showEmojiInputDialog() {
        let alert = NSAlert()
        alert.messageText = "Custom Emoji Cursor"
        alert.informativeText = "Enter an emoji to use as your cursor:"
        alert.alertStyle = .informational

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.placeholderString = "🎯"
        if let emoji = currentEmoji {
            textField.stringValue = emoji
        }
        alert.accessoryView = textField

        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let emoji = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !emoji.isEmpty {
                currentEmoji = emoji
                let size = UserDefaults.standard.cursorSize
                cursorManager.setCursorFromEmoji(emoji, size: size)
            }
        }
    }

    private func reapplyCurrentCursor() {
        let size = UserDefaults.standard.cursorSize
        cursorManager.reapplyCurrentCursor(size: CGSize(width: size, height: size))
    }

    private func loadMenuIcon(svgName: String) -> NSImage? {
        // Try Resources folder first
        var svgURL = Bundle.main.url(forResource: svgName, withExtension: "svg", subdirectory: "Resources")
        if svgURL == nil {
            svgURL = Bundle.main.url(forResource: svgName, withExtension: "svg")
        }

        guard let url = svgURL,
              let svgData = try? Data(contentsOf: url),
              let image = NSImage(data: svgData) else {
            return nil
        }

        // Create a small icon for menu (16x16)
        let iconSize = NSSize(width: 16, height: 16)
        
        // Simple resize by setting size
        image.size = iconSize
        return image
    }
}

// MARK: - CursorSize

enum CursorSize: CGFloat, CaseIterable {
    case small = 24
    case medium = 32
    case large = 48

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    private static let cursorSizeKey = "cursorSize"

    var cursorSize: CGFloat {
        get {
            let value = double(forKey: Self.cursorSizeKey)
            return value > 0 ? CGFloat(value) : CursorSize.medium.rawValue
        }
        set {
            set(Double(newValue), forKey: Self.cursorSizeKey)
        }
    }
}
