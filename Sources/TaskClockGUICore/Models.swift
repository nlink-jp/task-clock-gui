import Foundation

// Decoded shapes of the task-clock CLI's --json output (which is the
// daemon's API response, passed through verbatim). Decoding is open-set:
// unknown enum-ish strings stay as raw strings and map to safe display
// states — the CLI, not this app, owns the vocabulary.

/// One task from `task-clock status --json` (`{"tasks":[...]}`).
public struct TaskView: Decodable, Equatable, Sendable {
    public var name: String
    public var enabled: Bool
    public var paused: Bool
    public var cron: String
    public var watermark: String
    public var overlap: String
    public var catchUp: Bool
    public var nextFire: Date?
    public var nextExpectedRun: NextExpected
    public var running: RunningStatus?
    public var queuedFor: Date?
    public var overrunSeconds: Double
    public var lastRun: Run?

    enum CodingKeys: String, CodingKey {
        case name, enabled, paused, cron, watermark, overlap
        case catchUp = "catch_up"
        case nextFire = "next_fire"
        case nextExpectedRun = "next_expected_run"
        case running
        case queuedFor = "queued_for"
        case overrunSeconds = "overrun_seconds"
        case lastRun = "last_run"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        enabled = try c.decode(Bool.self, forKey: .enabled)
        paused = try c.decodeIfPresent(Bool.self, forKey: .paused) ?? false
        cron = try c.decodeIfPresent(String.self, forKey: .cron) ?? ""
        watermark = try c.decodeIfPresent(String.self, forKey: .watermark) ?? ""
        overlap = try c.decodeIfPresent(String.self, forKey: .overlap) ?? ""
        catchUp = try c.decodeIfPresent(Bool.self, forKey: .catchUp) ?? false
        nextFire = try c.decodeIfPresent(Date.self, forKey: .nextFire)
        nextExpectedRun = try c.decodeIfPresent(NextExpected.self, forKey: .nextExpectedRun)
            ?? NextExpected(kind: "none", at: nil)
        running = try c.decodeIfPresent(RunningStatus.self, forKey: .running)
        queuedFor = try c.decodeIfPresent(Date.self, forKey: .queuedFor)
        overrunSeconds = try c.decodeIfPresent(Double.self, forKey: .overrunSeconds) ?? 0
        lastRun = try c.decodeIfPresent(Run.self, forKey: .lastRun)
    }

    public init(
        name: String, enabled: Bool = true, paused: Bool = false,
        cron: String = "", watermark: String = "", overlap: String = "",
        catchUp: Bool = true, nextFire: Date? = nil,
        nextExpectedRun: NextExpected = NextExpected(kind: "none", at: nil),
        running: RunningStatus? = nil, queuedFor: Date? = nil,
        overrunSeconds: Double = 0, lastRun: Run? = nil
    ) {
        self.name = name
        self.enabled = enabled
        self.paused = paused
        self.cron = cron
        self.watermark = watermark
        self.overlap = overlap
        self.catchUp = catchUp
        self.nextFire = nextFire
        self.nextExpectedRun = nextExpectedRun
        self.running = running
        self.queuedFor = queuedFor
        self.overrunSeconds = overrunSeconds
        self.lastRun = lastRun
    }
}

public struct NextExpected: Decodable, Equatable, Sendable {
    public var kind: String // "at" | "after_current" | "after_success" | "none"
    public var at: Date?

    public init(kind: String, at: Date?) {
        self.kind = kind
        self.at = at
    }
}

public struct RunningStatus: Decodable, Equatable, Sendable {
    public var scheduledFor: Date
    public var startedAt: Date
    public var elapsedSeconds: Double

    enum CodingKeys: String, CodingKey {
        case scheduledFor = "scheduled_for"
        case startedAt = "started_at"
        case elapsedSeconds = "elapsed_seconds"
    }

    public init(scheduledFor: Date, startedAt: Date, elapsedSeconds: Double) {
        self.scheduledFor = scheduledFor
        self.startedAt = startedAt
        self.elapsedSeconds = elapsedSeconds
    }
}

/// One history row (`task-clock history --json`: `{"task":..,"runs":[...]}`).
public struct Run: Decodable, Equatable, Sendable {
    public var id: Int64
    public var task: String
    public var scheduledFor: Date
    public var startedAt: Date?
    public var finishedAt: Date?
    public var exitCode: Int?
    public var outcome: String
    public var missedReason: String
    public var logPath: String
    public var error: String

    enum CodingKeys: String, CodingKey {
        case id, task, outcome, error
        case scheduledFor = "scheduled_for"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case exitCode = "exit_code"
        case missedReason = "missed_reason"
        case logPath = "log_path"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        task = try c.decode(String.self, forKey: .task)
        scheduledFor = try c.decode(Date.self, forKey: .scheduledFor)
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt)
        finishedAt = try c.decodeIfPresent(Date.self, forKey: .finishedAt)
        exitCode = try c.decodeIfPresent(Int.self, forKey: .exitCode)
        outcome = try c.decode(String.self, forKey: .outcome)
        missedReason = try c.decodeIfPresent(String.self, forKey: .missedReason) ?? ""
        logPath = try c.decodeIfPresent(String.self, forKey: .logPath) ?? ""
        error = try c.decodeIfPresent(String.self, forKey: .error) ?? ""
    }

    public init(
        id: Int64, task: String, scheduledFor: Date, startedAt: Date? = nil,
        finishedAt: Date? = nil, exitCode: Int? = nil, outcome: String,
        missedReason: String = "", logPath: String = "", error: String = ""
    ) {
        self.id = id
        self.task = task
        self.scheduledFor = scheduledFor
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.exitCode = exitCode
        self.outcome = outcome
        self.missedReason = missedReason
        self.logPath = logPath
        self.error = error
    }
}

struct StatusEnvelope: Decodable {
    var tasks: [TaskView]?
}

struct HistoryEnvelope: Decodable {
    var runs: [Run]?
}

public enum CLIDecode {
    /// Go marshals time.Time as RFC 3339 with nanoseconds; ISO8601DateFormatter
    /// needs the fractional-seconds option for those, and the plain variant for
    /// whole-second values — try both.
    public static func decoder() -> JSONDecoder {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .custom { d in
            let s = try d.singleValueContainer().decode(String.self)
            if let t = withFraction.date(from: s) ?? plain.date(from: s) {
                return t
            }
            throw DecodingError.dataCorrupted(.init(
                codingPath: d.codingPath, debugDescription: "unparseable timestamp: \(s)"))
        }
        return dec
    }

    public static func statusTasks(from data: Data) throws -> [TaskView] {
        try decoder().decode(StatusEnvelope.self, from: data).tasks ?? []
    }

    public static func historyRuns(from data: Data) throws -> [Run] {
        try decoder().decode(HistoryEnvelope.self, from: data).runs ?? []
    }
}
