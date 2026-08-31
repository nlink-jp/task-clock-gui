import AppKit
import TaskClockGUICore

@main
@MainActor
enum Main {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if let command = arguments.first {
            switch command {
            case "version", "--version", "-v":
                print(appVersion)
                exit(0)
            case "help", "--help", "-h":
                printUsage()
                exit(0)
            default:
                FileHandle.standardError.write(Data("task-clock-gui: unknown argument '\(command)'\n".utf8))
                printUsage()
                exit(2)
            }
        }

        // Two instances would stack two menu bar items and double-poll.
        // LSMultipleInstancesProhibited (Info.plist) stops LaunchServices
        // launches; this guard stops the rest (direct exec, `open -n`).
        let bundleID = Bundle.main.bundleIdentifier
        let instancePIDs = bundleID.map { id in
            NSRunningApplication.runningApplications(withBundleIdentifier: id)
                .map(\.processIdentifier)
        } ?? []
        if case .exitDuplicate(let message) = singleInstanceDecision(
            bundleID: bundleID,
            ownPID: ProcessInfo.processInfo.processIdentifier,
            instancePIDs: instancePIDs
        ) {
            FileHandle.standardError.write(Data((message + "\n").utf8))
            exit(0)
        }

        TaskClockApp.main()
    }
}

func printUsage() {
    print("""
    task-clock-gui — menu-bar front end for the task-clock scheduler

    Usage:
      task-clock-gui             Launch the menu bar app
      task-clock-gui --version   Print the version
      task-clock-gui --help      Show this help
    """)
}
