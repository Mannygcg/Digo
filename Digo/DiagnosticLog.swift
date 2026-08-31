import Foundation
import os

/// A small local log, separate from os_log, specifically so a friend who hits a launch
/// problem can find and share one plain-text file without knowing how to use Console.app.
/// Nothing written here ever leaves the machine — it stays at ~/Library/Logs/Digo/digo.log.
///
/// This covers app-level failures (hangs, wrong state) that Apple's own crash reporter
/// won't — that one already covers hard crashes locally at
/// ~/Library/Logs/DiagnosticReports/Digo-*.ips, with no code needed from us.
enum DiagnosticLog {
    private static let logger = Logger(subsystem: "com.manuelcabrera.Digo", category: "DiagnosticLog")

    private static let fileURL: URL? = {
        guard let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = base.appendingPathComponent("Logs/Digo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("digo.log")
    }()

    static func write(_ message: String) {
        logger.log("\(message, privacy: .public)")
        guard let fileURL else { return }
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        } else {
            try? data.write(to: fileURL)
        }
    }

    /// Catches Cocoa/AppKit-level exceptions (e.g. thrown by AppKit internals) that would
    /// otherwise just crash silently from the user's perspective. Swift traps/fatalErrors
    /// aren't catchable this way — those already go to the system crash reporter above.
    static func installUncaughtExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            DiagnosticLog.write("Uncaught exception: \(exception.name.rawValue) — \(exception.reason ?? "no reason") — \(exception.callStackSymbols.joined(separator: "\n"))")
        }
    }
}
