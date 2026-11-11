// PasteShelf — clipboard history in the menu bar.
// Click the icon or press ⌘⇧V to open it. Click / Enter / ⌘1–9 copies an item and pastes it into the previous app.
// Hold ⌥ (Option) while choosing to paste as plain text.

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let repositoryURL = URL(string: "https://github.com/sonzini/PasteShelf")!

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let store = ClipboardStore()
    private let state = PanelState()
    private var previousApp: NSRunningApplication?
    private var hotKey: HotKey?
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.startMonitoring()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "list.clipboard", accessibilityDescription: "PasteShelf")
            image?.isTemplate = true
            button.image = image
            button.toolTip = L("Clipboard history (⌘⇧V)")
            button.target = self
            button.action = #selector(togglePopover)
        }

        let host = NSHostingController(rootView: ContentView(
            store: store,
            state: state,
            onPick: { [weak self] item, plain in self?.pick(item, plain: plain) },
            onAbout: { [weak self] in self?.showAbout() }
        ))
        host.sizingOptions = [.preferredContentSize]
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = host

        hotKey = HotKey(keyCode: kVK_ANSI_V, modifiers: cmdKey | shiftKey) { [weak self] in
            self?.togglePopover()
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.popover.isShown else { return event }
            return self.handleKey(event) ? nil : event
        }

        #if DEBUG
        // Used to take README screenshots: open the panel right away.
        if CommandLine.arguments.contains("--open-panel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.togglePopover() }
        }
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
            let path = CommandLine.arguments[i + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.togglePopover() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { self.snapshotPanel(to: path) }
        }
        #endif
    }

    // MARK: - Panel

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
            return
        }
        guard let button = statusItem.button else { return }
        let front = NSWorkspace.shared.frontmostApplication
        previousApp = (front?.bundleIdentifier == Bundle.main.bundleIdentifier) ? nil : front
        state.openCount += 1
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func closePopover() {
        popover.performClose(nil)
        previousApp?.activate()
    }

    private func showAbout() {
        popover.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSMutableAttributedString(
            string: L("Clipboard history in your menu bar.") + "\n",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
        )
        credits.append(NSAttributedString(
            string: "github.com/sonzini/PasteShelf",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .link: Self.repositoryURL]
        ))
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        credits.addAttribute(.paragraphStyle, value: centered, range: NSRange(location: 0, length: credits.length))
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    #if DEBUG
    /// Renders the open panel (including the popover frame) to a PNG, then quits.
    private func snapshotPanel(to path: String) {
        guard let content = popover.contentViewController?.view,
              let frameView = content.window?.contentView?.superview ?? content.window?.contentView else { return }
        let bounds = frameView.bounds
        if let rep = frameView.bitmapImageRepForCachingDisplay(in: bounds) {
            frameView.cacheDisplay(in: bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        }
        NSApp.terminate(nil)
    }
    #endif

    // MARK: - Keyboard

    private func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let option = flags.contains(.option)
        let v = store.visible(search: state.search)
        let flat = v.favs + v.hist

        switch Int(event.keyCode) {
        case kVK_DownArrow:
            if !flat.isEmpty { state.selected = min(state.selected + 1, flat.count - 1) }
            return true
        case kVK_UpArrow:
            state.selected = max(state.selected - 1, 0)
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if flat.indices.contains(state.selected) { pick(flat[state.selected], plain: option) }
            return true
        case kVK_Escape:
            closePopover()
            return true
        default:
            break
        }

        // ⌘1 … ⌘9
        if flags.contains(.command),
           let ch = event.charactersIgnoringModifiers?.first,
           let digit = ch.wholeNumberValue, (1...9).contains(digit) {
            let idx = digit - 1
            if flat.indices.contains(idx) { pick(flat[idx], plain: option) }
            return true
        }
        return false
    }

    // MARK: - Pasting

    private func pick(_ item: ClipItem, plain: Bool) {
        store.copy(item, plain: plain)
        closePopover()
        guard store.autoPaste, ensureAccessibility() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            Self.sendCommandV()
        }
    }

    /// Simulating ⌘V requires the Accessibility permission. Asks for it the first time.
    private func ensureAccessibility() -> Bool {
        if AXIsProcessTrusted() { return true }
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        return false
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
