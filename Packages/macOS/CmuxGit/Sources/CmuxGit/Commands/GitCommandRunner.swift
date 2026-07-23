public import Foundation

/// Executes mutating git commands (stage, commit, push, branch…) in a local
/// repository.
///
/// This is the write-side counterpart to the read-only status/metadata
/// services: every method shells out to the injected `git` executable inside
/// the given repository directory and either returns the command's output or
/// throws ``GitCommandFailure`` carrying git's stderr. Local repositories
/// only; commands never prompt (`GIT_TERMINAL_PROMPT=0`), so a push that
/// needs interactive credentials fails fast instead of hanging.
///
/// ```swift
/// let runner = GitCommandRunner()
/// try await runner.stage(paths: ["Sources/App.swift"], in: repoURL)
/// try await runner.commit(message: "Fix launch crash", in: repoURL)
/// try await runner.push(in: repoURL)
/// ```
///
/// Tests inject a scoped environment (isolated `HOME`,
/// `GIT_CONFIG_NOSYSTEM=1`) and run against scratch repositories; see
/// `GitCommandRunnerTests`.
public actor GitCommandRunner {
    private let gitExecutableURL: URL
    private let baseEnvironment: [String: String]

    /// Creates a runner.
    ///
    /// - Parameters:
    ///   - gitExecutableURL: The `git` binary to execute. Defaults to the
    ///     system git at `/usr/bin/git`.
    ///   - environment: The base process environment. Defaults to the current
    ///     process environment so user credential helpers and SSH agents
    ///     keep working; tests pass an isolated environment.
    public init(
        gitExecutableURL: URL = URL(fileURLWithPath: "/usr/bin/git"),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.gitExecutableURL = gitExecutableURL
        self.baseEnvironment = environment
    }

    // MARK: - Staging

    /// Stages the given paths (`git add -- <paths>`).
    ///
    /// - Parameters:
    ///   - paths: Repository-relative paths; also stages untracked files.
    ///   - repository: The repository's working-tree root.
    public func stage(paths: [String], in repository: URL) async throws {
        guard !paths.isEmpty else { return }
        _ = try await run(["add", "--"] + paths, in: repository)
    }

    /// Stages every change in the repository (`git add -A`).
    ///
    /// - Parameter repository: The repository's working-tree root.
    public func stageAll(in repository: URL) async throws {
        _ = try await run(["add", "-A"], in: repository)
    }

    /// Removes the given paths from the index (`git restore --staged`),
    /// leaving the working tree untouched.
    ///
    /// - Parameters:
    ///   - paths: Repository-relative paths currently staged.
    ///   - repository: The repository's working-tree root.
    public func unstage(paths: [String], in repository: URL) async throws {
        guard !paths.isEmpty else { return }
        _ = try await run(["restore", "--staged", "--"] + paths, in: repository)
    }

    /// Discards unstaged modifications to tracked files
    /// (`git restore -- <paths>`), restoring index content.
    ///
    /// Untracked files are not touched; use
    /// ``removeUntracked(paths:in:)`` for those.
    ///
    /// - Parameters:
    ///   - paths: Repository-relative tracked paths.
    ///   - repository: The repository's working-tree root.
    public func discardWorktreeChanges(paths: [String], in repository: URL) async throws {
        guard !paths.isEmpty else { return }
        _ = try await run(["restore", "--"] + paths, in: repository)
    }

    /// Deletes the given untracked files (`git clean -f -- <paths>`).
    ///
    /// - Parameters:
    ///   - paths: Repository-relative untracked paths.
    ///   - repository: The repository's working-tree root.
    public func removeUntracked(paths: [String], in repository: URL) async throws {
        guard !paths.isEmpty else { return }
        _ = try await run(["clean", "-f", "--"] + paths, in: repository)
    }

    /// Applies a unified-diff patch to the index only
    /// (`git apply --cached [-R]`), the primitive behind hunk staging.
    ///
    /// - Parameters:
    ///   - patch: A complete single-file patch (headers plus hunks).
    ///   - reverse: Pass `true` to unstage the hunk (`-R`).
    ///   - repository: The repository's working-tree root.
    public func applyPatchToIndex(_ patch: String, reverse: Bool = false, in repository: URL) async throws {
        var arguments = ["apply", "--cached"]
        if reverse {
            arguments.append("-R")
        }
        arguments.append("-")
        _ = try await run(arguments, in: repository, standardInput: Data(patch.utf8))
    }

    // MARK: - Commit / sync

    /// Records the staged changes (`git commit -m <message>`).
    ///
    /// - Parameters:
    ///   - message: The commit message; must be non-empty.
    ///   - repository: The repository's working-tree root.
    /// - Returns: The command output (summary line with short hash).
    @discardableResult
    public func commit(message: String, in repository: URL) async throws -> GitCommandOutput {
        try await run(["commit", "-m", message], in: repository)
    }

    /// Pushes the current branch (`git push`).
    ///
    /// - Parameter repository: The repository's working-tree root.
    /// - Returns: The command output (transfer summary lives on stderr).
    @discardableResult
    public func push(in repository: URL) async throws -> GitCommandOutput {
        try await run(["push"], in: repository)
    }

    /// Fast-forwards the current branch from its upstream
    /// (`git pull --ff-only`).
    ///
    /// Diverged branches fail with git's fast-forward error rather than
    /// creating a merge commit behind the user's back.
    ///
    /// - Parameter repository: The repository's working-tree root.
    /// - Returns: The command output.
    @discardableResult
    public func pull(in repository: URL) async throws -> GitCommandOutput {
        try await run(["pull", "--ff-only"], in: repository)
    }

    // MARK: - Repository

    /// Resolves the working-tree root containing the given directory
    /// (`git rev-parse --show-toplevel`), or `nil` when the directory is not
    /// inside a git repository.
    ///
    /// Porcelain status paths are root-relative, so every other command in
    /// this runner should be invoked with the URL this returns.
    ///
    /// - Parameter directory: Any directory, typically a workspace's cwd.
    public func repositoryTopLevel(containing directory: URL) async -> URL? {
        guard let output = try? await run(["rev-parse", "--show-toplevel"], in: directory) else {
            return nil
        }
        let path = output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    // MARK: - Status

    /// Reads the repository's change list with staged/unstaged sides intact
    /// (`git status --porcelain=v1 -z --untracked-files=all`).
    ///
    /// - Parameter repository: The repository's working-tree root.
    /// - Returns: Entries in git's output order.
    public func status(in repository: URL) async throws -> [GitStatusEntry] {
        let output = try await run(
            ["status", "--porcelain=v1", "-z", "--untracked-files=all"],
            in: repository
        )
        return GitPorcelainStatusParser().parse(output.standardOutput)
    }

    // MARK: - Branches

    /// Lists local branches with the current one marked.
    ///
    /// - Parameter repository: The repository's working-tree root.
    /// - Returns: Branches in git's default (alphabetical) order.
    public func branches(in repository: URL) async throws -> [GitBranch] {
        let output = try await run(
            ["branch", "--format", "%(HEAD)\t%(refname:short)"],
            in: repository
        )
        return output.standardOutput
            .split(separator: "\n")
            .compactMap { line in
                let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2, !parts[1].isEmpty else { return nil }
                return GitBranch(name: String(parts[1]), isCurrent: parts[0] == "*")
            }
    }

    /// Switches to the given branch (`git checkout <branch>`).
    ///
    /// Fails (like git does) when the switch would clobber uncommitted
    /// changes; callers surface git's message.
    ///
    /// - Parameters:
    ///   - branch: The short branch name to check out.
    ///   - repository: The repository's working-tree root.
    public func checkout(branch: String, in repository: URL) async throws {
        _ = try await run(["checkout", branch], in: repository)
    }

    // MARK: - Execution

    private func run(
        _ arguments: [String],
        in repository: URL,
        standardInput: Data? = nil
    ) async throws -> GitCommandOutput {
        let process = Process()
        process.executableURL = gitExecutableURL
        process.arguments = arguments
        process.currentDirectoryURL = repository
        var environment = baseEnvironment
        // Never block on an interactive credential prompt.
        environment["GIT_TERMINAL_PROMPT"] = "0"
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        let stdinPipe: Pipe?
        if standardInput != nil {
            let pipe = Pipe()
            process.standardInput = pipe
            stdinPipe = pipe
        } else {
            process.standardInput = FileHandle.nullDevice
            stdinPipe = nil
        }

        // The handler is installed before run() so an instantly-exiting
        // process can never race the observation; the buffered AsyncStream
        // holds the status until it is awaited below.
        let (termination, terminationContinuation) = AsyncStream.makeStream(of: Int32.self)
        process.terminationHandler = { finished in
            terminationContinuation.yield(finished.terminationStatus)
            terminationContinuation.finish()
        }

        do {
            try process.run()
        } catch {
            terminationContinuation.finish()
            throw GitCommandFailure(
                arguments: arguments,
                exitCode: nil,
                standardError: error.localizedDescription
            )
        }

        // Drain both pipes while the process runs (a full pipe buffer would
        // deadlock a wait-then-read sequence); file descriptors are Sendable
        // where FileHandle is not.
        async let stdoutData = Self.drain(fileDescriptor: stdoutPipe.fileHandleForReading.fileDescriptor)
        async let stderrData = Self.drain(fileDescriptor: stderrPipe.fileHandleForReading.fileDescriptor)

        if let standardInput, let stdinPipe {
            Self.feed(standardInput, toFileDescriptor: stdinPipe.fileHandleForWriting.fileDescriptor)
        }

        var exitCode: Int32 = -1
        for await status in termination {
            exitCode = status
        }
        let output = GitCommandOutput(
            standardOutput: String(data: await stdoutData, encoding: .utf8) ?? "",
            standardError: String(data: await stderrData, encoding: .utf8) ?? ""
        )
        guard exitCode == 0 else {
            throw GitCommandFailure(
                arguments: arguments,
                exitCode: exitCode,
                standardError: output.standardError,
                standardOutput: output.standardOutput
            )
        }
        return output
    }

    private nonisolated static func drain(fileDescriptor: Int32) async -> Data {
        let handle = FileHandle(fileDescriptor: fileDescriptor, closeOnDealloc: false)
        var data = Data()
        do {
            for try await byte in handle.bytes {
                data.append(byte)
            }
        } catch {
            // A read error mid-stream surfaces as truncated output; the
            // exit code remains the source of truth for success.
        }
        return data
    }

    private nonisolated static func feed(_ data: Data, toFileDescriptor fileDescriptor: Int32) {
        // Detached: a patch larger than the pipe buffer would block the
        // writer until git reads; the fd (not the FileHandle) crosses the
        // task boundary.
        Task.detached {
            let handle = FileHandle(fileDescriptor: fileDescriptor, closeOnDealloc: false)
            try? handle.write(contentsOf: data)
            try? handle.close()
        }
    }

}
