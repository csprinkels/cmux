struct TextBoxMentionCandidate: Sendable {
    let title: String
    let subtitle: String
    let targetPath: String
    let systemImageName: String
    let searchKey: String
    let priority: Int
    let isDirectory: Bool

    init(
        title: String,
        subtitle: String,
        targetPath: String,
        systemImageName: String,
        searchKey: String,
        priority: Int,
        isDirectory: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.targetPath = targetPath
        self.systemImageName = systemImageName
        self.searchKey = searchKey
        self.priority = priority
        self.isDirectory = isDirectory
    }

    func suggestion(trigger: Character) -> TextBoxMentionSuggestion {
        let displayTitle: String
        if (trigger == "/" || trigger == "$"), (title.hasPrefix("/") || title.hasPrefix("$")) {
            displayTitle = "\(trigger)\(title.dropFirst())"
        } else {
            displayTitle = title
        }

        let insertionText: String
        if trigger == "$" {
            // The $ trigger intentionally inserts the bare skill reference
            // (e.g. "$skill-name") as a plain-text shorthand. The / and @
            // triggers insert a markdown link instead.
            insertionText = displayTitle
        } else {
            insertionText = TextBoxMentionMarkdown.link(label: displayTitle, path: targetPath)
        }

        return TextBoxMentionSuggestion(
            id: "\(trigger):\(targetPath)",
            title: displayTitle,
            subtitle: subtitle,
            insertionText: insertionText,
            systemImageName: systemImageName
        )
    }
}
