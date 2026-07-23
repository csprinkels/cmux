import Foundation

/// A test-only real git repository in a temp directory, driven by the actual
/// `git` binary (unlike ``GitRepositoryFixture``, which fakes metadata files).
/// The environment is isolated (`GIT_CONFIG_NOSYSTEM`, scoped `HOME`) so the
/// developer's global config never leaks in. Removed on `deinit`.
final class LiveGitRepositoryFixture {
    let root: URL
    /// Environment for every git invocation in this fixture's repositories.
    let environment: [String: String]

    private let base: URL

    init() throws {
        base = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmuxgit-live-tests-\(UUID().uuidString)", isDirectory: true)
        root = base.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = base.path
        environment["GIT_CONFIG_NOSYSTEM"] = "1"
        environment["GIT_TERMINAL_PROMPT"] = "0"
        self.environment = environment

        try git(["init", "-b", "main"])
        try git(["config", "user.email", "tests@cmux.local"])
        try git(["config", "user.name", "cmux tests"])
    }

    deinit {
        try? FileManager.default.removeItem(at: base)
    }

    /// Writes (or overwrites) a file relative to the repository root.
    func write(_ contents: String, to relativePath: String) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Reads a repository file's contents.
    func read(_ relativePath: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// Whether a repository-relative path exists on disk.
    func exists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(relativePath).path)
    }

    /// Commits everything currently in the working tree.
    func commitAll(message: String) throws {
        try git(["add", "-A"])
        try git(["commit", "-m", message])
    }

    /// Creates a bare sibling repository and wires it up as `origin`.
    func addBareOrigin() throws -> URL {
        let bare = base.appendingPathComponent("origin.git", isDirectory: true)
        try FileManager.default.createDirectory(at: bare, withIntermediateDirectories: true)
        try runGit(["init", "--bare", "-b", "main"], in: bare)
        try git(["remote", "add", "origin", bare.path])
        return bare
    }

    /// Runs git in the fixture repository, returning stdout; throws on
    /// non-zero exit.
    @discardableResult
    func git(_ arguments: [String]) throws -> String {
        try runGit(arguments, in: root)
    }

    /// `git status --porcelain` for assertions.
    func porcelainStatus() throws -> String {
        try git(["status", "--porcelain"])
    }

    @discardableResult
    private func runGit(_ arguments: [String], in directory: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.environment = environment
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw FixtureGitError(
                arguments: arguments,
                stderr: String(data: errData, encoding: .utf8) ?? ""
            )
        }
        return String(data: outData, encoding: .utf8) ?? ""
    }

    struct FixtureGitError: Error, CustomStringConvertible {
        let arguments: [String]
        let stderr: String
        var description: String { "git \(arguments.joined(separator: " ")) failed: \(stderr)" }
    }
}
