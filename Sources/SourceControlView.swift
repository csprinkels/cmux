import CmuxGit
import SwiftUI

/// Closure bundle handed to source-control rows so they never hold the store
/// (SwiftUI list snapshot-boundary rule).
struct SourceControlRowActions {
    let stage: (GitStatusEntry) -> Void
    let unstage: (GitStatusEntry) -> Void
    let discard: (GitStatusEntry) -> Void
    let openDiff: (SourceControlDiffRequest) -> Void
}

/// A row's request to open the diff viewer scoped to one file.
struct SourceControlDiffRequest {
    let filePath: String
    let staged: Bool
}

/// The Source Control sidebar tool: branch bar, staged/unstaged change
/// sections, and a commit box, driven by ``SourceControlStore``.
struct SourceControlView: View {
    let store: SourceControlStore
    let onOpenDiff: (SourceControlDiffRequest) -> Void

    @State private var entryPendingDiscard: GitStatusEntry?

    var body: some View {
        VStack(spacing: 0) {
            branchBar
            if let message = store.lastErrorMessage {
                errorBanner(message)
            }
            if store.repositoryRoot == nil {
                emptyState(
                    String(
                        localized: "sourceControl.noRepository",
                        defaultValue: "Not a git repository"
                    )
                )
            } else if store.entries.isEmpty {
                emptyState(
                    String(localized: "sourceControl.noChanges", defaultValue: "No changes")
                )
            } else {
                changeList
            }
            commitBox
        }
        .onAppear { store.refresh() }
        .confirmationDialog(
            String(
                localized: "sourceControl.discardConfirm.title",
                defaultValue: "Discard changes?"
            ),
            isPresented: Binding(
                get: { entryPendingDiscard != nil },
                set: { if !$0 { entryPendingDiscard = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(
                String(
                    localized: "sourceControl.discardConfirm.discard",
                    defaultValue: "Discard"
                ),
                role: .destructive
            ) {
                if let entry = entryPendingDiscard {
                    store.discard(entry)
                }
                entryPendingDiscard = nil
            }
        } message: {
            if let entry = entryPendingDiscard {
                if entry.worktreeState == .untracked {
                    Text(String(
                        localized: "sourceControl.discardConfirm.untrackedMessage",
                        defaultValue: "\(entry.path) is untracked and will be deleted."
                    ))
                } else {
                    Text(String(
                        localized: "sourceControl.discardConfirm.trackedMessage",
                        defaultValue: "Unstaged changes to \(entry.path) will be lost."
                    ))
                }
            }
        }
    }

    // MARK: - Branch bar

    private var branchBar: some View {
        HStack(spacing: 6) {
            Menu {
                ForEach(store.branches) { branch in
                    Button {
                        store.checkout(branch: branch.name)
                    } label: {
                        if branch.isCurrent {
                            Label(branch.name, systemImage: "checkmark")
                        } else {
                            Text(branch.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    CmuxSystemSymbolImage(
                        systemName: "arrow.triangle.branch",
                        pointSize: 11,
                        weight: .regular,
                        appliesGlobalFontMagnification: true
                    )
                    Text(store.currentBranchName ?? "—")
                        .cmuxFont(size: 11, weight: .medium)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(store.isBusy || store.branches.isEmpty)

            Spacer(minLength: 0)

            toolbarButton(
                symbol: "arrow.down",
                help: String(localized: "sourceControl.pull.tooltip", defaultValue: "Pull (fast-forward)")
            ) {
                store.pull()
            }
            toolbarButton(
                symbol: "arrow.up",
                help: String(localized: "sourceControl.push.tooltip", defaultValue: "Push")
            ) {
                store.push()
            }
            toolbarButton(
                symbol: "arrow.clockwise",
                help: String(localized: "sourceControl.refresh.tooltip", defaultValue: "Refresh")
            ) {
                store.refresh()
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
    }

    private func toolbarButton(symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CmuxSystemSymbolImage(
                systemName: symbol,
                pointSize: 11,
                weight: .regular,
                appliesGlobalFontMagnification: true
            )
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .disabled(store.isBusy)
        .safeHelp(help)
    }

    // MARK: - Change list

    private var changeList: some View {
        let staged = store.stagedEntries
        let unstaged = store.unstagedEntries
        let actions = SourceControlRowActions(
            stage: { [weak store] in store?.stage($0) },
            unstage: { [weak store] in store?.unstage($0) },
            discard: { entry in entryPendingDiscard = entry },
            openDiff: onOpenDiff
        )
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !staged.isEmpty {
                    sectionHeader(
                        String(
                            localized: "sourceControl.section.staged",
                            defaultValue: "Staged Changes"
                        ),
                        count: staged.count
                    )
                    ForEach(staged) { entry in
                        SourceControlRowView(entry: entry, section: .staged, actions: actions)
                    }
                }
                if !unstaged.isEmpty {
                    HStack {
                        sectionHeader(
                            String(
                                localized: "sourceControl.section.changes",
                                defaultValue: "Changes"
                            ),
                            count: unstaged.count
                        )
                        Spacer(minLength: 0)
                        Button {
                            store.stageAll()
                        } label: {
                            Text(String(
                                localized: "sourceControl.stageAll",
                                defaultValue: "Stage All"
                            ))
                            .cmuxFont(size: 10, weight: .medium)
                            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                        }
                        .buttonStyle(.plain)
                        .disabled(store.isBusy)
                        .padding(.trailing, 12)
                    }
                    ForEach(unstaged) { entry in
                        SourceControlRowView(entry: entry, section: .unstaged, actions: actions)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        Text("\(title) (\(count))")
            .cmuxFont(size: 10, weight: .semibold)
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private func emptyState(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .cmuxFont(size: 11)
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .cmuxFont(size: 10)
            .lineLimit(3)
            .foregroundStyle(Color(nsColor: .systemRed))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .systemRed).opacity(0.1))
    }

    // MARK: - Commit box

    private var commitBox: some View {
        VStack(spacing: 6) {
            TextField(
                String(
                    localized: "sourceControl.commitMessage.placeholder",
                    defaultValue: "Commit message"
                ),
                text: Binding(
                    get: { store.commitMessage },
                    set: { store.commitMessage = $0 }
                ),
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .lineLimit(1...4)
            .cmuxFont(size: 11)
            .onSubmit { if store.canCommit { store.commit() } }

            Button {
                store.commit()
            } label: {
                Text(String(localized: "sourceControl.commit", defaultValue: "Commit"))
                    .cmuxFont(size: 11, weight: .medium)
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
            // ⌘⏎ commits from inside the message field (Return inserts a
            // newline in the vertical-axis TextField).
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!store.canCommit)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// One change row: status letter, filename, directory, hover actions.
/// Receives value snapshots and closures only — never the store.
private struct SourceControlRowView: View {
    enum Section {
        case staged
        case unstaged
    }

    let entry: GitStatusEntry
    let section: Section
    let actions: SourceControlRowActions

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text(statusLetter)
                .cmuxFont(size: 10, weight: .semibold, monospacedDigit: true)
                .foregroundStyle(Color(nsColor: statusColor))
                .frame(width: 12)
            Text(fileName)
                .cmuxFont(size: 11)
                .foregroundStyle(Color(nsColor: statusColor))
                .lineLimit(1)
            Text(directory)
                .cmuxFont(size: 10)
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            if isHovered {
                hoverActions
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 22)
        .contentShape(Rectangle())
        .background(
            isHovered
                ? Color.primary.opacity(0.05)
                : Color.clear
        )
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) {
            actions.openDiff(SourceControlDiffRequest(filePath: entry.path, staged: section == .staged))
        }
    }

    @ViewBuilder
    private var hoverActions: some View {
        switch section {
        case .staged:
            rowButton(
                symbol: "minus",
                help: String(localized: "sourceControl.unstage.tooltip", defaultValue: "Unstage")
            ) {
                actions.unstage(entry)
            }
        case .unstaged:
            rowButton(
                symbol: "arrow.uturn.backward",
                help: String(localized: "sourceControl.discard.tooltip", defaultValue: "Discard changes")
            ) {
                actions.discard(entry)
            }
            rowButton(
                symbol: "plus",
                help: String(localized: "sourceControl.stage.tooltip", defaultValue: "Stage")
            ) {
                actions.stage(entry)
            }
        }
    }

    private func rowButton(symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CmuxSystemSymbolImage(
                systemName: symbol,
                pointSize: 9,
                weight: .medium,
                appliesGlobalFontMagnification: true
            )
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
        .safeHelp(help)
    }

    private var relevantState: GitStatusEntry.State {
        section == .staged ? entry.indexState : entry.worktreeState
    }

    private var statusLetter: String {
        relevantState == .untracked ? "U" : String(relevantState.rawValue)
    }

    private var statusColor: NSColor {
        FileExplorerStyle.current.gitColor(for: fileStatus)
    }

    private var fileStatus: GitFileStatus {
        switch relevantState {
        case .added, .copied:
            return .added
        case .deleted:
            return .deleted
        case .renamed:
            return .renamed
        case .untracked:
            return .untracked
        case .modified, .typeChanged, .unmerged, .unmodified, .ignored:
            return .modified
        }
    }

    private var fileName: String {
        (entry.path as NSString).lastPathComponent
    }

    private var directory: String {
        let parent = (entry.path as NSString).deletingLastPathComponent
        return parent.isEmpty ? "" : parent
    }
}
