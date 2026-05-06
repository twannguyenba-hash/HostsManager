import SwiftUI
import AppKit

struct RawTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = CommentToggleTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isRichText = false
        textView.string = text
        textView.delegate = context.coordinator
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RawTextEditor

        init(_ parent: RawTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

class CommentToggleTextView: NSTextView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "/" {
            toggleCommentOnSelectedLines()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private func toggleCommentOnSelectedLines() {
        let fullText = string
        let nsString = fullText as NSString
        let selectedRange = self.selectedRange()

        let lineRange = nsString.lineRange(for: selectedRange)
        let linesString = nsString.substring(with: lineRange)
        let lines = linesString.components(separatedBy: "\n")

        let trimmedLines: [String]
        if lines.last == "" {
            trimmedLines = Array(lines.dropLast())
        } else {
            trimmedLines = lines
        }

        let allCommented = trimmedLines.allSatisfy { $0.isEmpty || $0.hasPrefix("#") }

        let newLines: [String] = trimmedLines.map { line in
            if line.isEmpty { return line }
            if allCommented {
                if line.hasPrefix("# ") {
                    return String(line.dropFirst(2))
                } else if line.hasPrefix("#") {
                    return String(line.dropFirst(1))
                }
                return line
            } else {
                return "# " + line
            }
        }

        var replacement = newLines.joined(separator: "\n")
        if lines.last == "" {
            replacement += "\n"
        }

        if shouldChangeText(in: lineRange, replacementString: replacement) {
            replaceCharacters(in: lineRange, with: replacement)
            didChangeText()

            let newLength = (replacement as NSString).length
            setSelectedRange(NSRange(location: lineRange.location, length: newLength))
        }
    }
}
