// front.swift: brings the windows of the given process IDs to the front (no accessibility permission needed).
import AppKit
var any = false
for pid in CommandLine.arguments.dropFirst().compactMap({ Int32($0) }) {
    if let app = NSRunningApplication(processIdentifier: pid) {
        _ = app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        any = true
    }
}
exit(any ? 0 : 1)
