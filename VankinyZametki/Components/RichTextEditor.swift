import SwiftUI
import UIKit

struct RichTextEditor: UIViewRepresentable {
    @Binding var htmlContent: String
    @Binding var selectedRange: NSRange
    var onTextChange: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isScrollEnabled = true
        textView.allowsEditingTextAttributes = true
        textView.font = .systemFont(ofSize: 16)
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 60, right: 8)
        textView.backgroundColor = .clear
        textView.autocorrectionType = .yes
        textView.spellCheckingType = .yes
        textView.smartQuotesType = .yes
        textView.smartDashesType = .yes

        if !htmlContent.isEmpty {
            textView.attributedText = HTMLConverter.attributedString(from: htmlContent)
        }

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        guard !context.coordinator.isEditing else { return }

        let currentHTML = HTMLConverter.html(from: textView.attributedText)
        if currentHTML != htmlContent && !htmlContent.isEmpty {
            let oldRange = textView.selectedRange
            textView.attributedText = HTMLConverter.attributedString(from: htmlContent)
            textView.selectedRange = oldRange
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        var isEditing = false

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
            parent.htmlContent = HTMLConverter.html(from: textView.attributedText)
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.htmlContent = HTMLConverter.html(from: textView.attributedText)
            parent.selectedRange = textView.selectedRange
            parent.onTextChange?()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selectedRange = textView.selectedRange
        }
    }
}

// MARK: - Formatting Commands

enum TextFormatAction: Equatable {
    case bold, italic, underline, strikethrough
    case heading(Int)
    case bulletList, numberedList
    case highlight, code
    case clearFormatting
}

extension UITextView {
    func applyFormat(_ action: TextFormatAction) {
        let range = selectedRange
        guard range.length > 0 || action == .bulletList || action == .numberedList else { return }

        let mutable = NSMutableAttributedString(attributedString: attributedText)

        switch action {
        case .bold:
            toggleTrait(.traitBold, in: range, of: mutable)
        case .italic:
            toggleTrait(.traitItalic, in: range, of: mutable)
        case .underline:
            toggleAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, in: range, of: mutable)
        case .strikethrough:
            toggleAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, in: range, of: mutable)
        case .heading(let level):
            let size: CGFloat = level == 1 ? 28 : level == 2 ? 24 : 20
            let font = UIFont.systemFont(ofSize: size, weight: .bold)
            mutable.addAttribute(.font, value: font, range: range)
        case .bulletList:
            insertListPrefix("•\t", in: mutable)
        case .numberedList:
            insertListPrefix("1.\t", in: mutable)
        case .highlight:
            let currentBg = mutable.attribute(.backgroundColor, at: range.location, effectiveRange: nil) as? UIColor
            if currentBg != nil {
                mutable.removeAttribute(.backgroundColor, range: range)
            } else {
                mutable.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.4), range: range)
            }
        case .code:
            let monoFont = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            mutable.addAttribute(.font, value: monoFont, range: range)
            mutable.addAttribute(.backgroundColor, value: UIColor.systemGray5, range: range)
        case .clearFormatting:
            let plain = mutable.string
            let cleaned = NSMutableAttributedString(string: plain, attributes: [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.label
            ])
            mutable.replaceCharacters(in: NSRange(location: 0, length: mutable.length), with: cleaned)
        }

        attributedText = mutable
        selectedRange = range
    }

    private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits, in range: NSRange, of text: NSMutableAttributedString) {
        text.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            guard let font = value as? UIFont else { return }
            let descriptor = font.fontDescriptor
            let hasTrait = descriptor.symbolicTraits.contains(trait)

            if hasTrait {
                if let newDescriptor = descriptor.withSymbolicTraits(descriptor.symbolicTraits.subtracting(trait)) {
                    text.addAttribute(.font, value: UIFont(descriptor: newDescriptor, size: font.pointSize), range: subRange)
                }
            } else {
                if let newDescriptor = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(trait)) {
                    text.addAttribute(.font, value: UIFont(descriptor: newDescriptor, size: font.pointSize), range: subRange)
                }
            }
        }
    }

    private func toggleAttribute(_ key: NSAttributedString.Key, value: Any, in range: NSRange, of text: NSMutableAttributedString) {
        let existing = text.attribute(key, at: range.location, effectiveRange: nil)
        if existing != nil {
            text.removeAttribute(key, range: range)
        } else {
            text.addAttribute(key, value: value, range: range)
        }
    }

    private func insertListPrefix(_ prefix: String, in text: NSMutableAttributedString) {
        let insertionPoint = selectedRange.location
        let lineRange = (text.string as NSString).lineRange(for: NSRange(location: insertionPoint, length: 0))
        let prefixAttr = NSAttributedString(string: prefix, attributes: [.font: UIFont.systemFont(ofSize: 16)])
        text.insert(prefixAttr, at: lineRange.location)
        attributedText = text
        selectedRange = NSRange(location: lineRange.location + prefix.count, length: 0)
    }
}
