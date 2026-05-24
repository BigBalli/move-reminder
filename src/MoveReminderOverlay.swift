// MoveReminderOverlay — full-screen frosted-blur "get up and move" overlay.
// Blurs every display, shows a centered card with a break countdown.
// Auto-dismisses when the countdown ends; "Skip break" or Esc dismisses early.
//
// Build:  swiftc -O MoveReminderOverlay.swift -o move-reminder-overlay -framework Cocoa
// Usage:  ./move-reminder-overlay [breakSeconds]      (default 120)

import Cocoa

let breakSeconds: Int = {
    if CommandLine.arguments.count > 1, let n = Int(CommandLine.arguments[1]), n > 0 { return n }
    return 120
}()

// Borderless window that can still take key focus and handle Esc.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 /* esc */ || event.keyCode == 36 /* return */ {
            NSApp.terminate(nil)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var windows: [NSWindow] = []
    var remaining = breakSeconds
    var countdown: NSTextField!
    var timer: Timer?

    func applicationDidFinishLaunching(_ note: Notification) {
        let shieldLevel = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        let mainScreen = NSScreen.main ?? NSScreen.screens.first

        for screen in NSScreen.screens {
            let win = OverlayWindow(contentRect: screen.frame,
                                    styleMask: .borderless,
                                    backing: .buffered,
                                    defer: false)
            win.level = shieldLevel
            win.isOpaque = false
            win.backgroundColor = .clear
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            win.ignoresMouseEvents = false

            // Frosted blur of whatever is behind the window.
            let blur = NSVisualEffectView(frame: screen.frame)
            blur.material = .fullScreenUI
            blur.blendingMode = .behindWindow
            blur.state = .active
            blur.autoresizingMask = [.width, .height]

            // Subtle dark tint for contrast.
            let tint = NSView(frame: screen.frame)
            tint.wantsLayer = true
            tint.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.28).cgColor
            tint.autoresizingMask = [.width, .height]
            blur.addSubview(tint)

            win.contentView = blur

            if screen == mainScreen {
                blur.addSubview(makeCard())
                addCardConstraints(card: blur.subviews.last!, in: blur)
            }

            win.makeKeyAndOrderFront(nil)
            windows.append(win)
        }

        NSApp.activate(ignoringOtherApps: true)
        windows.first(where: { $0.contentView?.subviews.count ?? 0 > 1 })?.makeKey()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remaining -= 1
            if self.remaining <= 0 {
                NSApp.terminate(nil)
            } else {
                self.countdown.stringValue = self.format(self.remaining)
            }
        }
    }

    private func format(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight,
                       color: NSColor, mono: Bool = false) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.font = mono ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
                      : NSFont.systemFont(ofSize: size, weight: weight)
        f.textColor = color
        f.alignment = .center
        f.maximumNumberOfLines = 0
        f.lineBreakMode = .byWordWrapping
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }

    private func makeCard() -> NSView {
        let card = NSVisualEffectView()
        card.material = .hudWindow
        card.blendingMode = .withinWindow
        card.state = .active
        card.wantsLayer = true
        card.layer?.cornerRadius = 28
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        let title = label("Time to move", size: 40, weight: .bold, color: .white)
        let subtitle = label("Stand up, stretch, and walk around for a couple of minutes.",
                             size: 17, weight: .regular, color: NSColor.white.withAlphaComponent(0.75))
        countdown = label(format(remaining), size: 64, weight: .semibold, color: .white, mono: true)
        let caption = label("until your break is up", size: 13, weight: .regular,
                            color: NSColor.white.withAlphaComponent(0.5))

        let skip = NSButton(title: "Skip break", target: self, action: #selector(skipTapped))
        skip.isBordered = false
        skip.translatesAutoresizingMaskIntoConstraints = false
        skip.attributedTitle = NSAttributedString(string: "Skip break", attributes: [
            .foregroundColor: NSColor.white.withAlphaComponent(0.55),
            .font: NSFont.systemFont(ofSize: 14, weight: .medium)
        ])

        let stack = NSStackView(views: [title, subtitle, countdown, caption, skip])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.setCustomSpacing(28, after: subtitle)
        stack.setCustomSpacing(24, after: caption)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 52),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -44),
            stack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            stack.widthAnchor.constraint(equalToConstant: 460),
        ])
        return card
    }

    private func addCardConstraints(card: NSView, in container: NSView) {
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 560),
        ])
    }

    @objc private func skipTapped() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
