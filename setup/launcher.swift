// launcher.swift: Hauptprogramm der App. Startet Contents/Resources/launch.sh mit zsh.
// Ein echtes Mach-O statt eines Skripts, damit die Code-Signatur das Ein- und Auspacken (ZIP) übersteht.
import Foundation
let exe = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
let app = exe.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let script = app.appendingPathComponent("Contents/Resources/launch.sh").path
let args: [UnsafeMutablePointer<CChar>?] = [strdup("/bin/zsh"), strdup(script), nil]
execv("/bin/zsh", args)
perror("execv"); exit(1)
