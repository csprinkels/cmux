import Foundation

/// Which list the palette is showing: the `>`-prefixed command list, the
/// workspace/surface switcher, or the `/`-prefixed quick-open file list.
public enum CommandPaletteListScope: String, Sendable {
    /// The command list (query prefixed with `>`).
    case commands
    /// The workspace/surface switcher list.
    case switcher
    /// The quick-open file list (query prefixed with `/`).
    case files
}
