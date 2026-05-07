import Foundation
import WatchConnectivity

extension Notification.Name {
    /// Posted when the iPhone signals that `CalorieSnapshotStore` may have new data (reload from App Group).
    static let calorieSnapshotUpdatedFromPhone = Notification.Name("CalorieCounter.calorieSnapshotUpdatedFromPhone")
}

enum WatchSnapshotConnectivity {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var didStart = false

    /// Call from UI after launch (e.g. `.task` on the root) — avoid `WCSession.activate()` during `App.init()` on device;
    /// early activation can exit before the debugger attaches.
    static func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !didStart else { return }
        didStart = true
        WatchSnapshotSessionBridge.shared.start()
    }
}

private final class WatchSnapshotSessionBridge: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchSnapshotSessionBridge()

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            NotificationCenter.default.post(name: .calorieSnapshotUpdatedFromPhone, object: nil)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext _: [String: Any]) {
        Task { @MainActor in
            NotificationCenter.default.post(name: .calorieSnapshotUpdatedFromPhone, object: nil)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        _ = userInfo
        Task { @MainActor in
            NotificationCenter.default.post(name: .calorieSnapshotUpdatedFromPhone, object: nil)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            NotificationCenter.default.post(name: .calorieSnapshotUpdatedFromPhone, object: nil)
        }
    }
}
