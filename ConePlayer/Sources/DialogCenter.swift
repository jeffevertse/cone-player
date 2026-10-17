import Foundation
import Observation
import VLCKit

/// Shows VLC's dialogs (logins for SMB/UPnP/HTTP, questions, errors) in Cone Player's UI.
///
/// VLC asks from its own threads through `VLCCustomDialogRendererProtocol`; the bridge
/// hops to the main actor and the window presents whatever `pending` holds.
@MainActor
@Observable
final class DialogCenter {
    enum Dialog: Identifiable {
        case login(title: String, message: String, username: String, canRemember: Bool, reference: DialogReference)
        case question(title: String, message: String, cancel: String?, action1: String?, action2: String?, reference: DialogReference)
        case error(title: String, message: String)

        var id: String {
            switch self {
            case .login(_, _, _, _, let reference), .question(_, _, _, _, _, let reference): reference.id
            case .error(let title, let message): title + message
            }
        }
    }

    /// Dialogs waiting to be shown, oldest first; the window shows the first.
    private(set) var queue: [Dialog] = []
    var current: Dialog? { queue.first }

    @ObservationIgnored private var providers: [VLCDialogProvider] = []
    @ObservationIgnored private lazy var bridge = DialogBridge(center: self)

    /// Hooks up every VLC library that might ask: the player's and the shared one the
    /// network browser parses with.
    func attach(to libraries: [VLCLibrary]) {
        var seen = Set<ObjectIdentifier>()
        for library in libraries where seen.insert(ObjectIdentifier(library)).inserted {
            guard let provider = VLCDialogProvider(library: library, customUI: true) else { continue }
            provider.customRenderer = bridge
            providers.append(provider)
        }
    }

    func logIn(username: String, password: String, remember: Bool) {
        guard case .login(_, _, _, _, let reference) = current else { return }
        // A dialog must be answered exactly once; any provider can answer it.
        providers.first?.postUsername(username, andPassword: password, forDialogReference: reference.value, store: remember)
        queue.removeFirst()
    }

    /// `button` is 1 or 2, matching VLC's action1 / action2.
    func answer(_ button: Int32) {
        guard case .question(_, _, _, _, _, let reference) = current else { return }
        providers.first?.postAction(button, forDialogReference: reference.value)
        queue.removeFirst()
    }

    func dismiss() {
        guard let dialog = current else { return }
        switch dialog {
        case .login(_, _, _, _, let reference), .question(_, _, _, _, _, let reference):
            providers.first?.dismissDialog(withReference: reference.value)
        case .error:
            break
        }
        queue.removeFirst()
    }

    fileprivate func enqueue(_ dialog: Dialog) {
        queue.append(dialog)
    }

    /// VLC withdrew a dialog (for example the connection gave up).
    fileprivate func cancel(_ reference: DialogReference) {
        queue.removeAll { $0.id == reference.id }
    }
}

/// VLC's opaque dialog handle. It's only passed back to VLC, never read, so it's
/// safe to carry across threads.
struct DialogReference: @unchecked Sendable {
    let value: NSValue
    var id: String { "\(value.pointerValue.map { Int(bitPattern: $0) } ?? value.hash)" }
}

/// Receives VLC's dialog callbacks (on VLC's threads) and forwards them to the main actor.
private final class DialogBridge: NSObject, VLCCustomDialogRendererProtocol, @unchecked Sendable {
    private weak var center: DialogCenter?

    @MainActor init(center: DialogCenter) {
        self.center = center
    }

    private func post(_ dialog: DialogCenter.Dialog) {
        Task { @MainActor [weak center] in center?.enqueue(dialog) }
    }

    func showError(withTitle error: String, message: String) {
        // VLC's generic "can't open … Check the log" repeats what the page or player
        // already shows; keep its more specific errors (codecs, devices, …).
        guard !message.contains("Check the log for details") else { return }
        post(.error(title: error, message: message))
    }

    func showLogin(withTitle title: String, message: String, defaultUsername username: String?,
                   askingForStorage: Bool, withReference reference: NSValue) {
        post(.login(title: title, message: message, username: username ?? "",
                    canRemember: askingForStorage, reference: DialogReference(value: reference)))
    }

    func showQuestion(withTitle title: String, message: String, type questionType: VLCDialogQuestionType,
                      cancel cancelString: String?, action1String: String?, action2String: String?,
                      withReference reference: NSValue) {
        post(.question(title: title, message: message, cancel: cancelString,
                       action1: action1String, action2: action2String, reference: DialogReference(value: reference)))
    }

    // Progress dialogs (e.g. "Connecting…") aren't shown; the views have their own spinners.
    func showProgress(withTitle title: String, message: String, isIndeterminate: Bool, position: Float,
                      cancel cancelString: String?, withReference reference: NSValue) {}

    func updateProgress(withReference reference: NSValue, message: String?, position: Float) {}

    func cancelDialog(withReference reference: NSValue) {
        let reference = DialogReference(value: reference)
        Task { @MainActor [weak center] in center?.cancel(reference) }
    }
}
