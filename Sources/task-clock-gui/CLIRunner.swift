import Foundation
import TaskClockGUICore

enum CLIError: LocalizedError {
    case binaryNotFound
    case launchFailed(detail: String)
    case daemonDown
    case runFailed(summary: String, detail: String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "task-clock CLI not found. Reinstall TaskClock.app (the CLI ships bundled), or install task-clock on your PATH."
        case .launchFailed:
            return "Couldn't start the task-clock CLI. Reinstall the app if this keeps happening."
        case .daemonDown:
            return "The task-clock daemon is not running."
        case .runFailed(let summary, _):
            return summary
        }
    }

    var failureReason: String? {
        switch self {
        case .binaryNotFound, .daemonDown: return nil
        case .launchFailed(let d): return d.isEmpty ? nil : d
        case .runFailed(_, let d): return d.isEmpty ? nil : d
        }
    }

    /// Translate a CLI failure into a short, actionable summary. Pure
    /// (testable); the raw stderr stays available separately as the detail.
    static func classify(exitCode: Int32, crashed: Bool, stderr: String) -> CLIError {
        let s = stderr.lowercased()
        if crashed {
            return .runFailed(
                summary: "The task-clock CLI stopped unexpectedly. Try again; if it keeps happening, reinstall the app.",
                detail: stderr)
        }
        if s.contains("daemon is not running") {
            return .daemonDown
        }
        if s.contains("no config.toml found") {
            return .runFailed(
                summary: "No task-clock config yet. Create ~/.config/task-clock/config.toml (see the task-clock README).",
                detail: stderr)
        }
        if s.contains("api_key is not set") {
            return .runFailed(
                summary: "The config has no api_key. Generate one (openssl rand -hex 32) and set it under [daemon].",
                detail: stderr)
        }
        if s.contains("chmod 600") {
            return .runFailed(
                summary: "The config file holding api_key is too open. Run: chmod 600 ~/.config/task-clock/config.toml",
                detail: stderr)
        }
        if s.contains("already_running") {
            return .runFailed(summary: "That task is already running.", detail: stderr)
        }
        let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .runFailed(summary: "The task-clock CLI exited with an error (code \(exitCode)).", detail: "")
        }
        let firstLine = trimmed.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? trimmed
        return .runFailed(summary: "task-clock: \(firstLine)", detail: trimmed)
    }
}

/// CLIRunner locates and invokes the bundled task-clock CLI, decoding its
/// --json output. The CLI owns config resolution, the API key and the HTTP
/// calls; this app is a thin front end over it.
enum CLIRunner {
    static func findBinary() -> String? {
        var allowEnvOverride = false
        var devPaths: [String] = []
        #if DEBUG
        allowEnvOverride = true
        devPaths = [
            NSHomeDirectory() + "/works/nlink-jp/util-series/task-clock/dist/task-clock",
        ]
        #endif
        return resolveCLIBinary(
            env: ProcessInfo.processInfo.environment,
            allowEnvOverride: allowEnvOverride,
            bundled: Bundle.main.resourceURL?.appendingPathComponent("task-clock").path,
            devPaths: devPaths,
            isExecutable: { FileManager.default.isExecutableFile(atPath: $0) }
        )
    }

    @discardableResult
    static func run(_ args: [String]) throws -> Data {
        guard let bin = findBinary() else { throw CLIError.binaryNotFound }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: bin)
        proc.arguments = args
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        do {
            try proc.run()
        } catch {
            throw CLIError.launchFailed(detail: error.localizedDescription)
        }
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        if proc.terminationStatus != 0 {
            let stderr = String(
                data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw CLIError.classify(
                exitCode: proc.terminationStatus,
                crashed: proc.terminationReason == .uncaughtSignal,
                stderr: stderr)
        }
        return data
    }

    // MARK: - Typed queries

    static func status() throws -> [TaskView] {
        try CLIDecode.statusTasks(from: run(["status", "--json"]))
    }

    static func history(task: String, limit: Int = 20) throws -> [Run] {
        try CLIDecode.historyRuns(from: run(
            ["history", "--json", "-limit", String(limit), task]))
    }

    static func trigger(task: String) throws { _ = try run(["trigger", task]) }
    static func pause(task: String) throws { _ = try run(["pause", task]) }
    static func resume(task: String) throws { _ = try run(["resume", task]) }
    static func reload() throws { _ = try run(["reload"]) }

    /// Daemon lifecycle: register / remove the LaunchAgent (RunAtLoad +
    /// KeepAlive), so the GUI never sends the user to a terminal for it.
    static func installDaemon() throws { _ = try run(["install"]) }
    static func uninstallDaemon() throws { _ = try run(["uninstall"]) }
}
