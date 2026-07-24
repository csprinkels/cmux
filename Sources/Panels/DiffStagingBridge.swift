import CmuxGit
import Foundation
import WebKit

/// Native bridge for the diff viewer's per-hunk stage/unstage buttons.
///
/// The webview never ships patch text: it names a hunk by its `@@` header
/// numbers, and this bridge recomputes the file's diff with git, matches the
/// hunk, and applies it to the index via ``GitCommandRunner``. A hunk that no
/// longer matches (the worktree moved on) fails with a reload hint instead of
/// applying the wrong change.
///
/// Only main-frame pages served from a registered diff viewer session may
/// call it — the same trust gate as `DiffCommentsBridge`.
@MainActor
final class DiffStagingBridge: NSObject, WKScriptMessageHandlerWithReply {
    static let handlerName = "cmuxGitStage"
    static let shared = DiffStagingBridge()

    private static var handlerInstalledKey: UInt8 = 0

    private enum BridgeError: Error {
        case notAllowed
        case invalidRequest(String)
        case hunkOutOfDate

        var code: String {
            switch self {
            case .notAllowed: return "not_allowed"
            case .invalidRequest: return "invalid_request"
            case .hunkOutOfDate: return "hunk_out_of_date"
            }
        }

        var userMessage: String {
            switch self {
            case .notAllowed:
                return String(
                    localized: "diffStaging.bridge.notAllowed",
                    defaultValue: "This page cannot stage changes."
                )
            case .invalidRequest(let detail):
                return detail
            case .hunkOutOfDate:
                return String(
                    localized: "diffStaging.bridge.hunkOutOfDate",
                    defaultValue: "This hunk no longer matches the repository. Reload the diff to continue."
                )
            }
        }
    }

    /// Adds the reply handler to a user content controller exactly once.
    static func installIfNeeded(on userContentController: WKUserContentController) {
        guard objc_getAssociatedObject(userContentController, &handlerInstalledKey) == nil else {
            return
        }
        userContentController.addScriptMessageHandler(
            shared,
            contentWorld: .page,
            name: handlerName
        )
        objc_setAssociatedObject(
            userContentController,
            &handlerInstalledKey,
            NSNumber(value: true),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage,
        replyHandler: @escaping (Any?, String?) -> Void
    ) {
        guard DiffCommentsBridge.isTrustedDiffViewerFrame(message.frameInfo) else {
            replyHandler(Self.errorReply(BridgeError.notAllowed), nil)
            return
        }
        let request: StageHunkRequest
        do {
            request = try Self.parseRequest(body: message.body)
        } catch let error as BridgeError {
            replyHandler(Self.errorReply(error), nil)
            return
        } catch {
            replyHandler(Self.errorReply(.invalidRequest("Malformed bridge request")), nil)
            return
        }
        Task { @MainActor in
            do {
                try await Self.applyHunk(request)
                replyHandler(["ok": true], nil)
            } catch let error as BridgeError {
                replyHandler(Self.errorReply(error), nil)
            } catch {
                replyHandler([
                    "ok": false,
                    "error": ["code": "git_failure", "userMessage": error.localizedDescription],
                ] as [String: Any], nil)
            }
        }
    }

    // MARK: - Request handling

    private struct StageHunkRequest {
        let repoRoot: String
        let filePath: String
        let unstage: Bool
        let target: GitDiffHunk.HeaderNumbers
    }

    private static func parseRequest(body: Any) throws -> StageHunkRequest {
        guard let body = body as? [String: Any],
              body["method"] as? String == "staging.applyHunk",
              let params = body["params"] as? [String: Any] else {
            throw BridgeError.invalidRequest("Malformed bridge request")
        }
        guard let repoRoot = (params["repoRoot"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !repoRoot.isEmpty else {
            throw BridgeError.invalidRequest("Missing repoRoot")
        }
        guard let filePath = params["filePath"] as? String,
              !filePath.isEmpty,
              !filePath.hasPrefix("/"),
              !filePath.split(separator: "/").contains("..") else {
            throw BridgeError.invalidRequest("Missing or invalid filePath")
        }
        guard let action = params["action"] as? String, action == "stage" || action == "unstage" else {
            throw BridgeError.invalidRequest("Unsupported action")
        }
        guard let hunk = params["hunk"] as? [String: Any],
              let deletionStart = hunk["deletionStart"] as? Int,
              let deletionCount = hunk["deletionCount"] as? Int,
              let additionStart = hunk["additionStart"] as? Int,
              let additionCount = hunk["additionCount"] as? Int else {
            throw BridgeError.invalidRequest("Missing hunk coordinates")
        }
        return StageHunkRequest(
            repoRoot: repoRoot,
            filePath: filePath,
            unstage: action == "unstage",
            target: GitDiffHunk.HeaderNumbers(
                deletionStart: deletionStart,
                deletionCount: deletionCount,
                additionStart: additionStart,
                additionCount: additionCount
            )
        )
    }

    private static func applyHunk(_ request: StageHunkRequest) async throws {
        let runner = GitCommandRunner()
        let requested = URL(fileURLWithPath: request.repoRoot, isDirectory: true)
        guard let root = await runner.repositoryTopLevel(containing: requested),
              root.resolvingSymlinksInPath().path == requested.resolvingSymlinksInPath().path else {
            throw BridgeError.invalidRequest("repoRoot is not a repository root")
        }
        let diffText = try await runner.fileDiff(
            path: request.filePath,
            staged: request.unstage,
            in: root
        )
        let hunks = GitDiffHunkSplitter().split(fileDiff: diffText)
        guard let hunk = hunks.first(where: { $0.headerNumbers == request.target }) else {
            throw BridgeError.hunkOutOfDate
        }
        try await runner.applyPatchToIndex(hunk.patchText, reverse: request.unstage, in: root)
    }

    private static func errorReply(_ error: BridgeError) -> [String: Any] {
        ["ok": false, "error": ["code": error.code, "userMessage": error.userMessage]]
    }
}
