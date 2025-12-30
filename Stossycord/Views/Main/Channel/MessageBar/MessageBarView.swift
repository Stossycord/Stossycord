import SwiftUI

struct MessageBarView: View {
    let permissionStatus: ChannelPermissionStatus
    let placeholder: String
    let canSendCurrentMessage: Bool
    let useNativePicker: Bool

    @Binding var message: String
    @Binding var showNativePicker: Bool
    @Binding var showNativePhotoPicker: Bool
    @Binding var showingFilePicker: Bool
    @Binding var showingUploadPicker: Bool

    let onMessageChange: (String) -> Void
    let onSubmit: () -> Void

    private let baseInputHeight: CGFloat = 46

    var body: some View {
        VStack(spacing: 10) {
            if let restrictionReason = permissionStatus.restrictionReason {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)

                    Text(restrictionReason)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground).opacity(0.6))
                )
            }

            if permissionStatus.canSendMessages {
                HStack(alignment: .bottom, spacing: 12) {
                    attachmentButton

                    inputStack
                }
            }
        }
        .padding(.vertical, 21)
        .padding(.horizontal, 16)
        .background(barBackground)
    }
}

private extension MessageBarView {
    @ViewBuilder
    var attachmentButton: some View {
        if permissionStatus.canAttachFiles {
            Button {
                if useNativePicker {
                    showNativePicker = true
                } else {
                    showingUploadPicker = true
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: baseInputHeight, height: baseInputHeight)
                    .foregroundStyle(.blue)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .background(attachmentBackground)
            .confirmationDialog("Select Attachment", isPresented: $showNativePicker) {
                Button("Photos") {
                    showNativePhotoPicker = true
                }
                Button("Files") {
                    showingFilePicker = true
                }
                Button("Cancel", role: .cancel) { }
            }
            .frame(width: baseInputHeight, height: baseInputHeight)
        }
    }

    @ViewBuilder
    var inputStack: some View {
        HStack(alignment: .bottom, spacing: 0) {
            TextField(placeholder, text: $message, axis: .vertical)
                .lineLimit(1...6)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.leading)
                .padding(.vertical, 10)
                .padding(.leading, 6)
                .padding(.trailing, 38)
                .onChange(of: message) { newValue in
                    onMessageChange(newValue)
                }
                .onSubmit {
                    onSubmit()
                }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .frame(minHeight: baseInputHeight, alignment: .bottom)
        .background(inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .trailing) {
            Button(action: onSubmit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(canSendCurrentMessage ? .blue : .gray)
                    .padding(10)
            }
            .disabled(!canSendCurrentMessage)
            .opacity(canSendCurrentMessage ? 1 : 0)
            .accessibilityLabel("Send Message")
            .accessibilityHidden(!canSendCurrentMessage)
        }
    }

    @ViewBuilder
    var barBackground: some View {
        if #available(iOS 26.0, *) {
            Color.clear
        } else {
            Rectangle()
                .fill(.thinMaterial)
                .overlay(alignment: .top) {
                    Divider()
                        .opacity(0.35)
                }
        }
    }

    @ViewBuilder
    var attachmentBackground: some View {
        if #available(iOS 26.0, *) {
            RoundedRectangle(cornerRadius: baseInputHeight / 2, style: .continuous)
                .glassEffect(.clear)
                .opacity(0.92)
        } else {
            RoundedRectangle(cornerRadius: baseInputHeight / 2, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        }
    }

    @ViewBuilder
    var inputBackground: some View {
        if #available(iOS 26.0, *) {
            RoundedRectangle(cornerRadius: 100, style: .continuous)
                .glassEffect(.clear)
                .opacity(0.92)
        } else {
            RoundedRectangle(cornerRadius: 100, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        }
    }
}

#Preview {
    MessageBarView(
        permissionStatus: ChannelPermissionStatus(canSendMessages: true, canAttachFiles: true, restrictionReason: "ig you might be muted idk"),
        placeholder: "Message #general",
        canSendCurrentMessage: true,
        useNativePicker: true,
        message: .constant(""),
        showNativePicker: .constant(false),
        showNativePhotoPicker: .constant(false),
        showingFilePicker: .constant(false),
        showingUploadPicker: .constant(false),
        onMessageChange: { _ in },
        onSubmit: { }
    )
}
