//
//  mouse_funApp.swift
//  mouse-fun
//
//  Created by liliang on 2025/11/7.
//

import SwiftUI
import Cocoa

@main
struct mouse_funApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the dock icon
        NSApp.setActivationPolicy(.accessory)

        // Setup menu bar
        menuBarController = MenuBarController()
        menuBarController?.setupMenuBar()

        // Apply default banana cursor on startup
        let defaultSize = CGSize(width: 32, height: 32)
        CursorManager.shared.setCursorFromSVG(named: "cursor-banana", size: defaultSize)
    }
}
