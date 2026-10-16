// front.swift: holt die Fenster der angegebenen Prozess-IDs nach vorn (ohne Bedienungshilfen-Rechte).
import AppKit
var any = false
for pid in CommandLine.arguments.dropFirst().compactMap({ Int32($0) }) {
    if let app = NSRunningApplication(processIdentifier: pid) {
        _ = app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        any = true
    }
}
exit(any ? 0 : 1)
