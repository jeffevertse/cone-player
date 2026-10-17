import SwiftUI

/// Login, question and error dialogs from VLC, in the app's sheet style.
struct VLCDialogSheet: View {
    let dialog: DialogCenter.Dialog
    @Environment(DialogCenter.self) private var dialogs
    @State private var username = ""
    @State private var password = ""
    @State private var remember = true
    @FocusState private var focus: Field?

    private enum Field { case username, password }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch dialog {
            case let .login(title, message, defaultUsername, canRemember, _):
                header(title, message, icon: "lock")
                field("User name", text: $username, secure: false)
                    .focused($focus, equals: .username)
                field("Password", text: $password, secure: true)
                    .focused($focus, equals: .password)
                if canRemember {
                    Toggle("Remember in Keychain", isOn: $remember)
                        .toggleStyle(.checkbox)
                        .foregroundStyle(Theme.textSecondary)
                }
                buttons(primary: "Log In", primaryAction: logIn, cancel: "Cancel")
                    .onAppear {
                        username = defaultUsername
                        focus = defaultUsername.isEmpty ? .username : .password
                    }
            case let .question(title, message, cancel, action1, action2, _):
                header(title, message, icon: "questionmark.circle")
                HStack {
                    Spacer()
                    if let cancel {
                        secondaryButton(cancel) { dialogs.dismiss() }
                            .keyboardShortcut(.cancelAction)
                    }
                    if let action2 {
                        secondaryButton(action2) { dialogs.answer(2) }
                    }
                    if let action1 {
                        primaryButton(action1) { dialogs.answer(1) }
                            .keyboardShortcut(.defaultAction)
                    }
                }
            case let .error(title, message):
                header(title, message, icon: "exclamationmark.triangle")
                HStack {
                    Spacer()
                    primaryButton("OK") { dialogs.dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(Theme.bar)
        .preferredColorScheme(.dark)
        .font(.inter(14))
    }

    private func logIn() {
        dialogs.logIn(username: username, password: password, remember: remember)
    }

    private func header(_ title: String, _ message: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.inter(16, .medium))
                    .foregroundStyle(Theme.textBright)
                Text(message)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func field(_ placeholder: String, text: Binding<String>, secure: Bool) -> some View {
        Group {
            if secure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
            }
        }
        .textFieldStyle(.plain)
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Theme.well, in: .rect(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.panel))
        .onSubmit(logIn)
    }

    private func buttons(primary: String, primaryAction: @escaping () -> Void, cancel: String) -> some View {
        HStack {
            Spacer()
            secondaryButton(cancel) { dialogs.dismiss() }
                .keyboardShortcut(.cancelAction)
            primaryButton(primary, action: primaryAction)
                .keyboardShortcut(.defaultAction)
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.inter(14, .semibold))
                .foregroundStyle(Color(hex: 0x161616))
                .padding(.horizontal, 16)
                .frame(height: 32)
                .background(Theme.accent, in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 12)
    }
}
