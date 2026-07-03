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
    @Binding var showingEmojiPicker: Bool
    @Binding var showingGIFPicker: Bool
    @Binding var showingUploadPicker: Bool
    
    let onMessageChange: (String) -> Void
    let onSubmit: () -> Void
    
    private let baseInputHeight: CGFloat = 46
    @State private var iOS15InputHeight: CGFloat = 22
    
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
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(barBackground)
    }
}

private extension MessageBarView {
    @ViewBuilder
    var attachmentButton: some View {
        if permissionStatus.canSendMessages {
            Button {
                if useNativePicker {
                    showNativePicker = true
                } else {
                    showingUploadPicker.toggle()
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
                Button("GIFs") {
                    presentAttachmentDestination {
                        showingGIFPicker = true
                    }
                }
                
                if permissionStatus.canAttachFiles {
                    Button("Photos") {
                        presentAttachmentDestination {
                            showNativePhotoPicker = true
                        }
                    }
                    Button("Files") {
                        presentAttachmentDestination {
                            showingFilePicker = true
                        }
                    }
                }
                
                Button("Cancel", role: .cancel) { }
            }
            .frame(width: baseInputHeight, height: baseInputHeight)
        }
    }
    
    @ViewBuilder
    var inputStack: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if #available(iOS 16.0, *) {
                TextField(placeholder, text: $message, axis: .vertical)
                    .lineLimit(1...6)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.leading)
                    .padding(.vertical, 10)
                    .padding(.leading, 6)
                    .padding(.trailing, 74)
                    .onChange(of: message) { newValue in
                        onMessageChange(newValue)
                    }
                    .onSubmit {
                        onSubmit()
                    }
            } else {
                iOS15TextEditor
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .frame(minHeight: baseInputHeight, alignment: .bottom)
        .background(inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .trailing) {
            HStack(spacing: 2) {
                Button {
                    showingEmojiPicker = true
                } label: {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Emoji")
                
                Button(action: onSubmit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(canSendCurrentMessage ? .blue : .gray.opacity(0.65))
                        .frame(width: 34, height: 34)
                }
                .disabled(!canSendCurrentMessage)
                .accessibilityLabel("Send Message")
            }
            .padding(.trailing, 5)
        }
        .simultaneousGesture(dismissKeyboardDragGesture)
    }
    
    var iOS15TextEditor: some View {
        GrowingTextView(
            text: $message,
            placeholder: placeholder,
            minHeight: 22,
            maxHeight: 120,
            measuredHeight: $iOS15InputHeight,
            onTextChange: onMessageChange
        )
        .frame(height: iOS15InputHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.leading, 2)
        .padding(.trailing, 70)
    }
    
    @ViewBuilder
    var barBackground: some View {
        if #available(iOS 19.0, *) {
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
        if #available(iOS 19.0, *) {
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
        if #available(iOS 19.0, *) {
            RoundedRectangle(cornerRadius: 100, style: .continuous)
                .glassEffect(.clear)
                .opacity(0.92)
        } else {
            RoundedRectangle(cornerRadius: 100, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        }
    }
    
    var dismissKeyboardDragGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onEnded { value in
                guard value.translation.height > 28,
                      value.translation.height > abs(value.translation.width) else {
                    return
                }
                
                dismissKeyboard()
            }
    }
    
    func dismissKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }
    
    func presentAttachmentDestination(_ action: @escaping () -> Void) {
        showNativePicker = false
        DispatchQueue.main.async {
            action()
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
        showingEmojiPicker: .constant(false),
        showingGIFPicker: .constant(false),
        showingUploadPicker: .constant(false),
        onMessageChange: { _ in },
        onSubmit: { }
    )
}


struct GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let minHeight: CGFloat
    let maxHeight: CGFloat
    @Binding var measuredHeight: CGFloat
    let onTextChange: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.font = .preferredFont(forTextStyle: .body)
        tv.textColor = .label
        tv.isScrollEnabled = false
        tv.showsVerticalScrollIndicator = false
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentHuggingPriority(.required, for: .vertical)
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentCompressionResistancePriority(.required, for: .vertical)
        
        let ph = UILabel()
        ph.tag = 999
        ph.text = placeholder
        ph.font = tv.font
        ph.textColor = .placeholderText
        ph.numberOfLines = 1
        ph.translatesAutoresizingMaskIntoConstraints = false
        tv.addSubview(ph)
        NSLayoutConstraint.activate([
            ph.topAnchor.constraint(equalTo: tv.topAnchor),
            ph.leadingAnchor.constraint(equalTo: tv.leadingAnchor),
            ph.trailingAnchor.constraint(equalTo: tv.trailingAnchor),
        ])
        
        return tv
    }
    
    func updateUIView(_ tv: UITextView, context: Context) {
        context.coordinator.parent = self
        
        if tv.text != text {
            tv.text = text
        }
        
        tv.viewWithTag(999)?.isHidden = !text.isEmpty
        context.coordinator.updateMeasuredHeight(for: tv)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingTextView
        
        init(parent: GrowingTextView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.onTextChange(textView.text)
            updateMeasuredHeight(for: textView)
        }
        
        func updateMeasuredHeight(for textView: UITextView) {
            let fallbackWidth = max(UIScreen.main.bounds.width - 120, 1)
            let fittingWidth = textView.bounds.width > 1 ? textView.bounds.width : fallbackWidth
            let fittingSize = textView.sizeThatFits(CGSize(width: fittingWidth, height: .greatestFiniteMagnitude))
            let newHeight = min(max(fittingSize.height, parent.minHeight), parent.maxHeight)
            textView.isScrollEnabled = fittingSize.height > parent.maxHeight
            textView.invalidateIntrinsicContentSize()
            
            guard abs(parent.measuredHeight - newHeight) > 0.5 else { return }
            DispatchQueue.main.async {
                self.parent.measuredHeight = newHeight
            }
        }
    }
}
