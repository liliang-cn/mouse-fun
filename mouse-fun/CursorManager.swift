//
//  CursorManager.swift
//  mouse-fun
//
//  Created by liliang on 2025/11/7.
//

import Cocoa
import CoreGraphics

// MARK: - Private CoreGraphics APIs for Cursor Hiding

// Private API declarations
typealias CGSConnectionID = UInt32

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSSetConnectionProperty")
func CGSSetConnectionProperty(_ connection: CGSConnectionID, _ connection2: CGSConnectionID, _ key: CFString, _ value: CFTypeRef) -> CGError

// MARK: - Cursor Overlay Window with Direct Drawing

class CursorOverlayWindow: NSWindow {
    private var cursorView: CursorView!
    private var mouseTracker: Any?
    private var localTracker: Any?
    private var positionTimer: Timer?

    init() {
        // Small window that follows the cursor
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 64, height: 64),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Window configuration - must be above EVERYTHING including Dock
        self.isOpaque = false
        self.backgroundColor = .clear
        // Use the highest possible window level to be above Dock
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.cursorWindow)))
        self.ignoresMouseEvents = true  // Pass through all clicks
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.hasShadow = false
        self.isReleasedWhenClosed = false

        // Create custom view for drawing cursor
        cursorView = CursorView(frame: self.contentView!.bounds)
        self.contentView = cursorView

        // Start tracking
        startMouseTracking()
    }

    private func startMouseTracking() {
        // High-frequency timer for smooth tracking
        positionTimer = Timer.scheduledTimer(withTimeInterval: 1.0/120.0, repeats: true) { [weak self] _ in
            self?.updatePosition()
        }
        RunLoop.current.add(positionTimer!, forMode: .common)

        // Initial position
        updatePosition()
    }

    private func updatePosition() {
        guard let cursorView = cursorView else { return }

        let mouseLocation = NSEvent.mouseLocation
        let hotSpot = cursorView.hotSpot

        // Position window so cursor hotspot is at mouse location
        let windowOrigin = NSPoint(
            x: mouseLocation.x - hotSpot.x,
            y: mouseLocation.y - hotSpot.y
        )

        self.setFrameOrigin(windowOrigin)

        // Aggressively hide system cursor on every position update
        // This helps combat Dock and menu bar showing the cursor
        CGDisplayHideCursor(CGMainDisplayID())
        NSCursor.hide()
    }

    func setCursorImage(_ image: NSImage, hotSpot: NSPoint) {
        cursorView.cursorImage = image
        cursorView.hotSpot = hotSpot

        // Resize window to fit cursor image
        let newSize = NSSize(
            width: max(image.size.width, 64),
            height: max(image.size.height, 64)
        )
        self.setContentSize(newSize)
        cursorView.frame = NSRect(origin: .zero, size: newSize)

        updatePosition()
        cursorView.needsDisplay = true
    }

    deinit {
        positionTimer?.invalidate()
        if let tracker = mouseTracker {
            NSEvent.removeMonitor(tracker)
        }
        if let tracker = localTracker {
            NSEvent.removeMonitor(tracker)
        }
    }
}

// MARK: - Custom View for Drawing Cursor

class CursorView: NSView {
    var cursorImage: NSImage?
    var hotSpot: NSPoint = .zero

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Clear background
        NSColor.clear.setFill()
        dirtyRect.fill()

        // Draw cursor image
        if let image = cursorImage {
            image.draw(in: NSRect(origin: .zero, size: image.size),
                      from: NSRect(origin: .zero, size: image.size),
                      operation: .sourceOver,
                      fraction: 1.0)
        }
    }
}

// MARK: - Cursor Manager

class CursorManager {
    static let shared = CursorManager()

    // Current cursor state
    private(set) var isCustomCursorActive = false
    private var currentSVGName: String?
    private var currentEmoji: String?
    private var currentCursorImage: NSImage?
    private var currentHotSpot: NSPoint = .zero

    // Overlay window for custom cursor
    private var overlayWindow: CursorOverlayWindow?

    // Timer to continuously hide system cursor
    private var cursorHideTimer: Timer?

    private init() {}

    deinit {
        cleanup()
    }

    private func cleanup() {
        // Stop hide timer
        cursorHideTimer?.invalidate()
        cursorHideTimer = nil

        overlayWindow?.orderOut(nil)
        overlayWindow = nil

        // Show system cursor
        NSCursor.unhide()
        CGDisplayShowCursor(CGMainDisplayID())

        isCustomCursorActive = false
    }

    // MARK: - Public Methods

    func setCursorFromSVG(named svgName: String, size: CGSize = CGSize(width: 32, height: 32)) {
        print("Loading SVG cursor: \(svgName) at size: \(size)")

        // Reset previous cursor first
        if isCustomCursorActive {
            resetToDefault()
        }

        currentSVGName = svgName
        currentEmoji = nil

        // Find SVG file
        var svgURL = Bundle.main.url(forResource: svgName, withExtension: "svg", subdirectory: "Resources")
        if svgURL == nil {
            svgURL = Bundle.main.url(forResource: svgName, withExtension: "svg")
        }

        guard let url = svgURL else {
            print("SVG not found: \(svgName)")
            return
        }

        guard let image = loadSVGImage(from: url, size: size) else {
            print("Failed to create image from SVG")
            return
        }

        // Create and apply cursor hotspot for SVG
        // SVGs are rotated -45 degrees around center (16, 16)
        // Original top-center (16, 0) rotates to approximately (5, 16) after -45deg rotation
        // So hotspot should be at the left edge, middle height
        let hotSpot = NSPoint(x: size.width * 0.15, y: size.height * 0.5)
        applyCustomCursor(image: image, hotSpot: hotSpot)
    }

    func setCursorFromEmoji(_ emoji: String, size: CGFloat = 32) {
        print("Setting emoji cursor: \(emoji) at size: \(size)")

        // Reset previous cursor first
        if isCustomCursorActive {
            resetToDefault()
        }

        currentEmoji = emoji
        currentSVGName = nil

        let image = createImageFromEmoji(emoji, size: size)
        // Center hotspot for emoji (macOS bottom-left origin)
        let hotSpot = NSPoint(x: size / 2, y: size / 2)
        applyCustomCursor(image: image, hotSpot: hotSpot)
    }

    func reapplyCurrentCursor(size: CGSize) {
        if let svgName = currentSVGName {
            setCursorFromSVG(named: svgName, size: size)
        } else if let emoji = currentEmoji {
            setCursorFromEmoji(emoji, size: size.width)
        }
    }

    func resetToDefault() {
        print("Resetting to default cursor")

        cleanup()

        currentSVGName = nil
        currentEmoji = nil
        currentCursorImage = nil
    }

    // MARK: - Private Helper Methods

    private func applyCustomCursor(image: NSImage, hotSpot: NSPoint) {
        // Store cursor info
        currentCursorImage = image
        currentHotSpot = hotSpot
        isCustomCursorActive = true

        // CRITICAL: Use private API to hide cursor even when app is in background
        let connection = CGSMainConnectionID()
        let key = "SetsCursorInBackground" as CFString
        let value = kCFBooleanTrue as CFTypeRef
        CGSSetConnectionProperty(connection, connection, key, value)

        // Now hide the cursor - this will work even in background
        CGDisplayHideCursor(CGMainDisplayID())
        NSCursor.hide()

        // Start aggressive timer to continuously hide system cursor
        // This is needed because system menus and some apps force cursor to show
        cursorHideTimer?.invalidate()
        cursorHideTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            guard self?.isCustomCursorActive == true else { return }
            CGDisplayHideCursor(CGMainDisplayID())
            NSCursor.hide()
        }
        if let timer = cursorHideTimer {
            RunLoop.current.add(timer, forMode: .common)
        }

        // Create overlay window if needed
        if overlayWindow == nil {
            overlayWindow = CursorOverlayWindow()
        }

        // Set cursor image in overlay
        overlayWindow?.setCursorImage(image, hotSpot: hotSpot)
        overlayWindow?.orderFrontRegardless()

        print("Custom cursor applied - size: \(image.size), hotSpot: \(hotSpot)")
    }

    private func loadSVGImage(from url: URL, size: CGSize) -> NSImage? {
        // Use autoreleasepool to ensure proper memory management
        return autoreleasepool {
            guard let svgData = try? Data(contentsOf: url) else {
                print("Failed to load SVG data from: \(url)")
                return nil
            }

            // Create source image from SVG data
            guard let sourceImage = NSImage(data: svgData) else {
                print("Failed to create NSImage from SVG data")
                return nil
            }

            // If the source image has representations, use the first one's size
            let sourceSize = sourceImage.representations.first?.size ?? sourceImage.size
            print("Original SVG size: \(sourceSize), target size: \(size)")

            // Create new image with exact target size
            let targetImage = NSImage(size: size)
            targetImage.lockFocus()
            defer { targetImage.unlockFocus() }

            // Configure graphics context for high quality
            if let context = NSGraphicsContext.current {
                context.imageInterpolation = .high
                context.shouldAntialias = true
            }

            // Clear background
            NSColor.clear.setFill()
            NSRect(origin: .zero, size: size).fill()

            // Calculate aspect-fit scaling
            let scaleX = size.width / sourceSize.width
            let scaleY = size.height / sourceSize.height
            let scale = min(scaleX, scaleY)

            let scaledWidth = sourceSize.width * scale
            let scaledHeight = sourceSize.height * scale
            let drawRect = NSRect(
                x: (size.width - scaledWidth) / 2,
                y: (size.height - scaledHeight) / 2,
                width: scaledWidth,
                height: scaledHeight
            )

            // Draw the source image
            sourceImage.draw(
                in: drawRect,
                from: NSRect(origin: .zero, size: sourceSize),
                operation: .sourceOver,
                fraction: 1.0,
                respectFlipped: true,
                hints: [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)]
            )

            print("Created resized image: \(targetImage.size)")
            return targetImage
        }
    }

    private func createImageFromEmoji(_ emoji: String, size: CGFloat) -> NSImage {
        let fontSize = size * 0.8 // Slightly larger font for better visibility
        let font = NSFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]

        let attributedString = NSAttributedString(string: emoji, attributes: attributes)
        let textSize = attributedString.size()

        let imageSize = NSSize(width: size, height: size)
        let image = NSImage(size: imageSize)

        image.lockFocus()
        defer { image.unlockFocus() }

        // Clear background
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: imageSize).fill()

        // Center the emoji
        let x = (size - textSize.width) / 2
        let y = (size - textSize.height) / 2
        attributedString.draw(at: NSPoint(x: x, y: y))

        return image
    }
}