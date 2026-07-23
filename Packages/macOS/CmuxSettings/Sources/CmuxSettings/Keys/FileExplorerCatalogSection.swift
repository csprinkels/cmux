import Foundation

/// Settings under the dotted-id prefix `fileExplorer.*`.
///
/// Controls the file explorer (file tree). Note the legacy exception: the
/// double-click action ships under the flat `fileExplorerDoubleClickAction`
/// defaults key and is parsed directly from the `fileExplorer` config section,
/// so it is not registered here.
public struct FileExplorerCatalogSection: SettingCatalogSection {
    /// Where the file tree is mounted.
    ///
    /// `"right"` (the default) is the established right-sidebar Files tool.
    /// `"left"` mounts the tree in the left sidebar below the workspace list
    /// and hides the right sidebar's Files tab. `"both"` shows both,
    /// sharing one selection. Changing this applies live.
    public let placement = DefaultsKey<String>(
        id: "fileExplorer.placement",
        defaultValue: "right",
        userDefaultsKey: "fileExplorer.placement"
    )

    /// Creates the file explorer settings section with its default keys.
    public init() {}
}
