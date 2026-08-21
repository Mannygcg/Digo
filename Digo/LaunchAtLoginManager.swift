import ServiceManagement
import os

enum LaunchAtLoginManager {
    private static let logger = Logger(subsystem: "com.manuelcabrera.Digo", category: "LaunchAtLoginManager")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Failed to \(enabled ? "register" : "unregister", privacy: .public) launch-at-login: \(String(describing: error), privacy: .public)")
        }
    }
}
