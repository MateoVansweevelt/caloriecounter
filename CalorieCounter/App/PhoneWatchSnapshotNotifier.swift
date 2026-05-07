import Foundation
import WatchConnectivity

/// Pings the paired Watch after the App Group snapshot changes so `TodayWatchRootView` can reload promptly.
/// App Group storage still carries the payload; this only nudges the watch process to re-read it.
final class PhoneWatchSnapshotNotifier: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = PhoneWatchSnapshotNotifier()

    private var pendingContextUpdate = false

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func notifySnapshotUpdated() {
        DispatchQueue.main.async { [weak self] in
            self?.notifySnapshotUpdatedOnMain()
        }
    }

    private func notifySnapshotUpdatedOnMain() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.activationState == .activated {
            sendContextTick(using: session)
        } else {
            pendingContextUpdate = true
        }
    }

    private func sendContextTick(using session: WCSession) {
        sendWatchReloadSignals(using: session)
    }

    /// `updateApplicationContext` coalesces to the latest payload; `transferUserInfo` queues each delivery so the Watch
    /// still gets a nudge when timestamps repeat or context delivery is deferred.
    private func sendWatchReloadSignals(using session: WCSession) {
        let ts = Date().timeIntervalSince1970
        do {
            try session.updateApplicationContext(["t": ts])
        } catch {
            // Unpaired watch, simulator without companion, throttling, etc.
        }
        session.transferUserInfo(["t": ts, "reload": 1])
    }

    /// Extra ping after heavy work (e.g. full widget timeline reload) so the Watch re-reads the App Group.
    func pushWatchReloadDelivery() {
        DispatchQueue.main.async { [weak self] in
            self?.pushWatchReloadDeliveryOnMain()
        }
    }

    private func pushWatchReloadDeliveryOnMain() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            pendingContextUpdate = true
            return
        }
        sendWatchReloadSignals(using: session)
    }

    private func flushPendingIfNeededOnMain() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        if pendingContextUpdate {
            pendingContextUpdate = false
            sendContextTick(using: session)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        DispatchQueue.main.async { [weak self] in
            self?.flushPendingIfNeededOnMain()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
