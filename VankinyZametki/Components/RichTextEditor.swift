import SwiftUI
import UIKit

struct RichTextEditor: UIViewRepresentable {
    @Binding var htmlContent: String
    @Binding var selectedRange: NSRange
    var onTextChange: (() -> Void)?
    var onSlashTriggered: (() -> Void)?
    var onDiagramFromSelection: ((String, String, Int) -> Void)?
    var onDiagramClicked: ((String, String, Int, UIImage?) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isScrollEnabled = true
        textView.allowsEditingTextAttributes = true
        textView.font = .systemFont(ofSize: 17)
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 80, right: 16)
        textView.backgroundColor = .clear
        textView.autocorrectionType = .yes
        textView.spellCheckingType = .yes
        textView.smartQuotesType = .yes
        textView.smartDashesType = .yes
        textView.keyboardDismissMode = .interactiveWithAccessory
        textView.alwaysBounceVertical = true

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDiagramDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        textView.addGestureRecognizer(doubleTap)

        context.coordinator.textView = textView
        context.coordinator.loadHTML(htmlContent, into: textView)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let coordinator = context.coordinator
        guard !coordinator.isEditing else { return }

        if htmlContent != coordinator.lastSetHTML {
            coordinator.loadHTML(htmlContent, into: textView)
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        var isEditing = false
        var isProgrammaticUpdate = false
        var lastSetHTML: String = ""
        weak var textView: UITextView?

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        @objc func handleDiagramDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let tv = textView else { return }
            let point = gesture.location(in: tv)
            guard let position = tv.closestPosition(to: point) else { return }
            let offset = tv.offset(from: tv.beginningOfDocument, to: position)
            guard offset < tv.textStorage.length else { return }

            let attrs = tv.textStorage.attributes(at: offset, effectiveRange: nil)
            guard let mermaid = attrs[vzDiagramMermaidKey] as? String,
                  let imageURL = attrs[vzImageURLKey] as? String else { return }

            var img: UIImage?
            if let attachment = attrs[.attachment] as? NSTextAttachment {
                img = attachment.image
            }
            parent.onDiagramClicked?(imageURL, mermaid, offset, img)
        }

        func loadHTML(_ html: String, into textView: UITextView) {
            lastSetHTML = html
            guard !html.isEmpty else { return }
            DispatchQueue.main.async { [self] in
                self.isProgrammaticUpdate = true
                textView.attributedText = HTMLConverter.attributedString(from: html)
                self.isProgrammaticUpdate = false
            }
        }

        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            if range.length == 1, range.location < textView.textStorage.length {
                let attrs = textView.textStorage.attributes(at: range.location, effectiveRange: nil)
                if let mermaid = attrs[vzDiagramMermaidKey] as? String,
                   let imageURL = attrs[vzImageURLKey] as? String {
                    var img: UIImage?
                    if let attachment = attrs[.attachment] as? NSTextAttachment {
                        img = attachment.image
                    }
                    let editAction = UIAction(
                        title: "Редактировать диаграмму",
                        image: UIImage(systemName: "pencil.and.outline")
                    ) { [weak self] _ in
                        self?.parent.onDiagramClicked?(imageURL, mermaid, range.location, img)
                    }
                    let deleteAction = UIAction(
                        title: "Удалить диаграмму",
                        image: UIImage(systemName: "trash"),
                        attributes: .destructive
                    ) { _ in
                        let start = max(0, range.location - 1)
                        let length = min(range.length + 2, textView.textStorage.length - start)
                        textView.textStorage.deleteCharacters(in: NSRange(location: start, length: length))
                    }
                    return UIMenu(children: suggestedActions + [editAction, deleteAction])
                }
            }

            guard range.length > 0,
                  let text = (textView.text as NSString?)?.substring(with: range)
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                return UIMenu(children: suggestedActions)
            }

            let diagramTypes: [(id: String, title: String, icon: String)] = [
                ("auto", "Авто", "sparkles"),
                ("flowchart", "Блок-схема", "arrow.triangle.branch"),
                ("sequence", "Взаимодействие", "person.2.wave.2"),
                ("mindmap", "Карта идей", "brain.head.profile"),
                ("er", "Схема БД", "cylinder"),
                ("state", "Состояния", "circle.hexagongrid"),
                ("gantt", "Таймлайн", "calendar.badge.clock"),
            ]

            let insertPos = range.location + range.length
            let diagramActions = diagramTypes.map { dtype in
                UIAction(title: dtype.title, image: UIImage(systemName: dtype.icon)) { [weak self] _ in
                    self?.parent.onDiagramFromSelection?(text, dtype.id, insertPos)
                }
            }

            let diagramMenu = UIMenu(
                title: "Создать диаграмму",
                image: UIImage(systemName: "arrow.triangle.branch"),
                children: diagramActions
            )

            return UIMenu(children: suggestedActions + [diagramMenu])
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
            let html = HTMLConverter.html(from: textView.attributedText)
            lastSetHTML = html
            parent.htmlContent = html
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isProgrammaticUpdate else { return }
            let html = HTMLConverter.html(from: textView.attributedText)
            lastSetHTML = html
            parent.htmlContent = html
            parent.selectedRange = textView.selectedRange
            parent.onTextChange?()

            checkForSlashTrigger(in: textView)
        }

        private func checkForSlashTrigger(in textView: UITextView) {
            let cursor = textView.selectedRange.location
            guard cursor > 0 else { return }
            let text = (textView.text as NSString?) ?? NSString()
            let charBefore = text.substring(with: NSRange(location: cursor - 1, length: 1))
            guard charBefore == "/" else { return }

            let isAtLineStart = cursor == 1 || text.substring(with: NSRange(location: cursor - 2, length: 1)) == "\n"
            guard isAtLineStart else { return }

            let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
            mutable.replaceCharacters(in: NSRange(location: cursor - 1, length: 1), with: "")
            isProgrammaticUpdate = true
            textView.attributedText = mutable
            textView.selectedRange = NSRange(location: cursor - 1, length: 0)
            isProgrammaticUpdate = false

            let html = HTMLConverter.html(from: textView.attributedText)
            lastSetHTML = html
            parent.htmlContent = html
            parent.selectedRange = textView.selectedRange

            parent.onSlashTriggered?()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isProgrammaticUpdate else { return }
            parent.selectedRange = textView.selectedRange
        }
    }
}

// MARK: - Formatting Commands

enum iOSHighlightColor: String, CaseIterable, Equatable {
    case yellow, green, blue, pink, orange, purple

    var uiColor: UIColor {
        switch self {
        case .yellow:  return UIColor(red: 1.0, green: 0.95, blue: 0.36, alpha: 0.55)
        case .green:   return UIColor(red: 0.52, green: 0.90, blue: 0.52, alpha: 0.45)
        case .blue:    return UIColor(red: 0.53, green: 0.76, blue: 1.0, alpha: 0.45)
        case .pink:    return UIColor(red: 1.0, green: 0.55, blue: 0.75, alpha: 0.45)
        case .orange:  return UIColor(red: 1.0, green: 0.75, blue: 0.35, alpha: 0.50)
        case .purple:  return UIColor(red: 0.75, green: 0.55, blue: 1.0, alpha: 0.40)
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .yellow:  return .yellow
        case .green:   return .green
        case .blue:    return .blue
        case .pink:    return .pink
        case .orange:  return .orange
        case .purple:  return .purple
        }
    }

    var displayName: String {
        switch self {
        case .yellow:  return "Жёлт."
        case .green:   return "Зелён."
        case .blue:    return "Голуб."
        case .pink:    return "Розов."
        case .orange:  return "Оранж."
        case .purple:  return "Фиол."
        }
    }
}

enum iOSNoteFont: String, CaseIterable, Equatable {
    case system = "System"
    case serif = "Georgia"
    case newYork = "New York"
    case mono = "SF Mono"
    case palatino = "Palatino"

    var displayName: String {
        switch self {
        case .system:   return "Системный"
        case .serif:    return "Georgia"
        case .newYork:  return "New York"
        case .mono:     return "Моно"
        case .palatino: return "Palatino"
        }
    }

    func uiFont(size: CGFloat, bold: Bool = false) -> UIFont {
        switch self {
        case .system:
            return bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size)
        case .serif:
            let name = bold ? "Georgia-Bold" : "Georgia"
            return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size)
        case .newYork:
            let desc = UIFontDescriptor(fontAttributes: [
                .family: "New York",
                .traits: [UIFontDescriptor.TraitKey.weight: bold ? UIFont.Weight.bold : UIFont.Weight.regular]
            ])
            return UIFont(descriptor: desc, size: size)
        case .mono:
            return UIFont.monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
        case .palatino:
            let name = bold ? "Palatino-Bold" : "Palatino"
            return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size)
        }
    }
}

enum TextFormatAction: Equatable {
    case bold, italic, underline, strikethrough
    case heading(Int)
    case bulletList, numberedList
    case highlight(iOSHighlightColor)
    case removeHighlight
    case blockquote
    case separator
    case code
    case clearFormatting
    case setFont(iOSNoteFont)
    case cleanPaste
    case insertImage
    case insertTable
    case insertDrawing
    case insertDiagram
    case insertDiagramResult(url: String, mermaidCode: String)
}

extension UITextView {
    func applyFormat(_ action: TextFormatAction) {
        let range = selectedRange

        if range.length == 0 {
            switch action {
            case .heading(let level):
                let size: CGFloat = level == 1 ? 28 : level == 2 ? 24 : 20
                var attrs = typingAttributes
                attrs[.font] = UIFont.systemFont(ofSize: size, weight: .bold)
                typingAttributes = attrs
                return
            case .code:
                var attrs = typingAttributes
                attrs[.font] = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
                attrs[.backgroundColor] = UIColor.systemGray5
                typingAttributes = attrs
                return
            case .bold:
                toggleTypingTrait(.traitBold)
                return
            case .italic:
                toggleTypingTrait(.traitItalic)
                return
            case .bulletList, .numberedList, .blockquote, .separator:
                break
            default:
                return
            }
        }

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
        case .highlight(let color):
            mutable.addAttribute(.backgroundColor, value: color.uiColor, range: range)
        case .removeHighlight:
            mutable.removeAttribute(.backgroundColor, range: range)
        case .blockquote:
            applyBlockquote(in: mutable)
        case .separator:
            insertSeparator(in: mutable)
        case .code:
            let monoFont = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
            mutable.addAttribute(.font, value: monoFont, range: range)
            mutable.addAttribute(.backgroundColor, value: UIColor.systemGray5, range: range)
        case .clearFormatting:
            let plain = mutable.string
            let cleaned = NSMutableAttributedString(string: plain, attributes: [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.label
            ])
            mutable.replaceCharacters(in: NSRange(location: 0, length: mutable.length), with: cleaned)

        case .setFont(let noteFont):
            let applyRange = range.length > 0 ? range : NSRange(location: 0, length: mutable.length)
            if applyRange.length == 0 {
                typingAttributes[.font] = noteFont.uiFont(size: 17)
            } else {
                mutable.enumerateAttribute(.font, in: applyRange, options: []) { value, subRange, _ in
                    let old = (value as? UIFont) ?? UIFont.systemFont(ofSize: 17)
                    let isBold = old.fontDescriptor.symbolicTraits.contains(.traitBold)
                    mutable.addAttribute(.font, value: noteFont.uiFont(size: old.pointSize, bold: isBold), range: subRange)
                }
            }

        case .insertImage, .insertTable, .insertDrawing, .insertDiagram:
            return

        case .insertDiagramResult:
            return

        case .cleanPaste:
            let cleanRange = range.length > 0 ? range : NSRange(location: 0, length: mutable.length)
            guard cleanRange.length > 0 else { break }
            let defaultFont = UIFont.systemFont(ofSize: 17)
            mutable.enumerateAttributes(in: cleanRange, options: []) { attrs, subRange, _ in
                let font = (attrs[.font] as? UIFont) ?? defaultFont
                let isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
                let isItalic = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
                let isLargeText = font.pointSize >= 20
                var newFont: UIFont
                if isLargeText && isBold {
                    let sz: CGFloat = font.pointSize >= 26 ? 28 : font.pointSize >= 22 ? 24 : 20
                    newFont = UIFont.systemFont(ofSize: sz, weight: .bold)
                } else if isBold {
                    newFont = UIFont.boldSystemFont(ofSize: 17)
                } else if isItalic {
                    newFont = UIFont.italicSystemFont(ofSize: 17)
                } else {
                    newFont = defaultFont
                }
                mutable.setAttributes([.font: newFont, .foregroundColor: UIColor.label], range: subRange)
                if let u = attrs[.underlineStyle] as? Int, u != 0 { mutable.addAttribute(.underlineStyle, value: u, range: subRange) }
                if let s = attrs[.strikethroughStyle] as? Int, s != 0 { mutable.addAttribute(.strikethroughStyle, value: s, range: subRange) }
            }
        }

        attributedText = mutable
        selectedRange = range
    }

    private func toggleTypingTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        var attrs = typingAttributes
        let font = (attrs[.font] as? UIFont) ?? .systemFont(ofSize: 17)
        let descriptor = font.fontDescriptor
        if descriptor.symbolicTraits.contains(trait) {
            if let newDesc = descriptor.withSymbolicTraits(descriptor.symbolicTraits.subtracting(trait)) {
                attrs[.font] = UIFont(descriptor: newDesc, size: font.pointSize)
            }
        } else {
            if let newDesc = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(trait)) {
                attrs[.font] = UIFont(descriptor: newDesc, size: font.pointSize)
            }
        }
        typingAttributes = attrs
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
        let prefixAttr = NSAttributedString(string: prefix, attributes: [.font: UIFont.systemFont(ofSize: 17)])
        text.insert(prefixAttr, at: lineRange.location)
        attributedText = text
        selectedRange = NSRange(location: lineRange.location + prefix.count, length: 0)
    }

    private func applyBlockquote(in text: NSMutableAttributedString) {
        let insertionPoint = selectedRange.location
        let lineRange = (text.string as NSString).lineRange(for: NSRange(location: insertionPoint, length: selectedRange.length > 0 ? selectedRange.length : 0))

        let style = NSMutableParagraphStyle()
        style.headIndent = 16
        style.firstLineHeadIndent = 16
        style.paragraphSpacingBefore = 6
        style.paragraphSpacing = 6

        text.addAttribute(.paragraphStyle, value: style, range: lineRange)
        text.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: lineRange)

        let barPrefix = NSAttributedString(string: "│ ", attributes: [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: UIColor.separator
        ])
        let lineText = (text.string as NSString).substring(with: lineRange)
        if !lineText.hasPrefix("│ ") {
            text.insert(barPrefix, at: lineRange.location)
        }

        attributedText = text
    }

    private func insertSeparator(in text: NSMutableAttributedString) {
        let insertionPoint = selectedRange.location
        let sep = NSAttributedString(string: "\n───────────\n", attributes: [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.separator,
            .strikethroughStyle: 0
        ])
        text.insert(sep, at: insertionPoint)
        attributedText = text
        selectedRange = NSRange(location: insertionPoint + sep.length, length: 0)
    }
}
