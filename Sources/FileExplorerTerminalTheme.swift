import AppKit
import CmuxFoundation

/// Ghostty-terminal-derived font and palette for the Terminal Stealth
/// explorer style, so the tree matches the terminal the way the code editor
/// and diff viewer do. Values are cached because `FileExplorerStyle` getters
/// run per row; the explorer coordinator invalidates on the same Ghostty
/// config notifications `CodeEditorWebCoordinator` observes.
enum FileExplorerTerminalTheme {
    private struct Resolved {
        let nameFont: NSFont
        let palette: FileExplorerPalette
    }

    private static var cached: Resolved?

    static var nameFont: NSFont { resolved().nameFont }
    static var palette: FileExplorerPalette { resolved().palette }

    static func invalidate() {
        assert(Thread.isMainThread, "FileExplorerTerminalTheme is main-thread-only")
        cached = nil
    }

    private static func resolved() -> Resolved {
        assert(Thread.isMainThread, "FileExplorerTerminalTheme is main-thread-only")
        if let cached { return cached }
        let payload = AgentChatThemePayload(
            config: GhosttyConfig.load(globalFontMagnificationPercent: GlobalFontMagnification.storedPercent)
        )
        let value = Resolved(nameFont: font(for: payload), palette: palette(for: payload))
        cached = value
        return value
    }

    private static func font(for payload: AgentChatThemePayload) -> NSFont {
        // 12.5 matches the left sidebar's workspace row title size.
        let size = GlobalFontMagnification.scaledSize(12.5)
        if let family = payload.fontFamily,
           let font = NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: size) {
            return font
        }
        return GlobalFontMagnification.monospacedSystemFont(ofSize: 12.5, weight: .regular)
    }

    private static func palette(for payload: AgentChatThemePayload) -> FileExplorerPalette {
        let ansi = payload.palette
        guard ansi.count >= 8,
              let foreground = NSColor(hex: payload.foreground),
              let red = NSColor(hex: ansi[1]),
              let green = NSColor(hex: ansi[2]),
              let yellow = NSColor(hex: ansi[3]),
              let blue = NSColor(hex: ansi[4]) else {
            return .terminalStealth
        }
        return .terminalDerived(foreground: foreground, red: red, green: green, yellow: yellow, blue: blue)
    }
}
