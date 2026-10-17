// launcher.swift: main executable of the app. Runs Contents/Resources/launch.sh with zsh.
// A real Mach-O instead of a script, so the code signature survives zipping and unzipping.
import Foundation
let exe = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
let app = exe.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let script = app.appendingPathComponent("Contents/Resources/launch.sh").path
let args: [UnsafeMutablePointer<CChar>?] = [strdup("/bin/zsh"), strdup(script), nil]
execv("/bin/zsh", args)
perror("execv"); exit(1)
