import SwiftUI
import AppKit

enum HighlightColor: String, CaseIterable, Equatable {
    case yellow, green, blue, pink, orange, purple

    var nsColor: NSColor {
        switch self {
        case .yellow:  return NSColor(red: 1.0, green: 0.95, blue: 0.36, alpha: 0.55)
        case .green:   return NSColor(red: 0.52, green: 0.90, blue: 0.52, alpha: 0.45)
        case .blue:    return NSColor(red: 0.53, green: 0.76, blue: 1.0, alpha: 0.45)
        case .pink:    return NSColor(red: 1.0, green: 0.55, blue: 0.75, alpha: 0.45)
        case .orange:  return NSColor(red: 1.0, green: 0.75, blue: 0.35, alpha: 0.50)
        case .purple:  return NSColor(red: 0.75, green: 0.55, blue: 1.0, alpha: 0.40)
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
        case .yellow:  return "Жёлтый"
        case .green:   return "Зелёный"
        case .blue:    return "Голубой"
        case .pink:    return "Розовый"
        case .orange:  return "Оранжевый"
        case .purple:  return "Фиолетовый"
        }
    }

    var cssColor: String {
        switch self {
        case .yellow:  return "rgba(255,242,92,0.55)"
        case .green:   return "rgba(133,230,133,0.45)"
        case .blue:    return "rgba(135,194,255,0.45)"
        case .pink:    return "rgba(255,140,191,0.45)"
        case .orange:  return "rgba(255,191,89,0.50)"
        case .purple:  return "rgba(191,140,255,0.40)"
        }
    }
}

enum NoteFont: String, CaseIterable, Equatable {
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

    func nsFont(size: CGFloat, bold: Bool = false) -> NSFont {
        switch self {
        case .system:
            return bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        case .serif:
            let name = bold ? "Georgia-Bold" : "Georgia"
            return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size)
        case .newYork:
            let desc = NSFontDescriptor(fontAttributes: [
                .family: "New York",
                .traits: [NSFontDescriptor.TraitKey.weight: bold ? NSFont.Weight.bold : NSFont.Weight.regular]
            ])
            return NSFont(descriptor: desc, size: size) ?? NSFont.systemFont(ofSize: size)
        case .mono:
            return NSFont.monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
        case .palatino:
            let name = bold ? "Palatino-Bold" : "Palatino"
            return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size)
        }
    }
}

enum MacFormatAction: Equatable {
    case bold, italic, underline, strikethrough
    case heading(Int)
    case bulletList, numberedList
    case blockquote, codeBlock
    case separator
    case highlight(HighlightColor)
    case removeHighlight
    case footnote
    case clearFormatting
    case setFont(NoteFont)
    case cleanPaste
    case insertImage
    case insertTable
    case insertDiagram
    case insertImageData(Data, String)
    case forceReload

    static func == (lhs: MacFormatAction, rhs: MacFormatAction) -> Bool {
        switch (lhs, rhs) {
        case (.bold, .bold), (.italic, .italic), (.underline, .underline),
             (.strikethrough, .strikethrough), (.bulletList, .bulletList),
             (.numberedList, .numberedList), (.blockquote, .blockquote),
             (.codeBlock, .codeBlock), (.separator, .separator),
             (.removeHighlight, .removeHighlight), (.footnote, .footnote),
             (.clearFormatting, .clearFormatting), (.cleanPaste, .cleanPaste),
             (.insertImage, .insertImage), (.insertTable, .insertTable),
             (.insertDiagram, .insertDiagram), (.forceReload, .forceReload):
            return true
        case (.heading(let a), .heading(let b)):
            return a == b
        case (.highlight(let a), .highlight(let b)):
            return a == b
        case (.setFont(let a), .setFont(let b)):
            return a == b
        case (.insertImageData(_, let a), .insertImageData(_, let b)):
            return a == b
        default:
            return false
        }
    }
}

struct MacRichTextEditor: NSViewRepresentable {
    @Binding var htmlContent: String
    var onTextChange: (() -> Void)?
    var formatAction: MacFormatAction? = nil
    var availableTags: [Tag] = []
    var onSlashCommand: ((SlashCommandItem.SlashAction) -> Void)?
    var onImagePasted: ((Data, String) -> Void)?
    var onTableInsert: (() -> Void)?
    var onDiagramFromSelection: ((String, String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.drawsBackground = false

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFontPanel = true
        textView.usesRuler = false
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.font = NSFont.systemFont(ofSize: 16)
        textView.textContainerInset = NSSize(width: 32, height: 20)
        textView.drawsBackground = false

        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        context.coordinator.textView = textView
        context.coordinator.loadHTML(htmlContent, into: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator

        if let action = formatAction {
            DispatchQueue.main.async {
                coordinator.applyFormat(action)
            }
        }

        guard !coordinator.isEditing else { return }

        if htmlContent != coordinator.lastSetHTML {
            if let textView = scrollView.documentView as? NSTextView {
                coordinator.loadHTML(htmlContent, into: textView)
            }
        }
    }

    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacRichTextEditor
        var isEditing = false
        var isProgrammaticUpdate = false
        var lastSetHTML: String = ""
        weak var textView: NSTextView?

        var slashActive = false
        var slashStartLocation: Int = 0
        var slashPanel: NSPanel?
        var slashHostingView: NSHostingView<AnyView>?
        var slashSelectedIndex = 0
        var slashSearchText = ""
        var scrollObserver: NSObjectProtocol?

        init(_ parent: MacRichTextEditor) {
            self.parent = parent
        }

        func loadHTML(_ html: String, into textView: NSTextView) {
            lastSetHTML = html
            guard !html.isEmpty else { return }
            isProgrammaticUpdate = true
            let attributed = MacHTMLConverter.attributedString(from: html)
            textView.textStorage?.setAttributedString(attributed)
            isProgrammaticUpdate = false
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            if replacementString == nil {
                let pb = NSPasteboard.general
                if let imgData = imageDataFromPasteboard(pb) {
                    handleImagePaste(imgData.data, mimeType: imgData.mime, in: textView)
                    return false
                }
            }
            return true
        }

        private func imageDataFromPasteboard(_ pb: NSPasteboard) -> (data: Data, mime: String)? {
            let imageTypes: [(NSPasteboard.PasteboardType, String)] = [
                (.png, "image/png"),
                (.tiff, "image/png"),
            ]
            for (type, mime) in imageTypes {
                if let data = pb.data(forType: type) {
                    if type == .tiff, let img = NSImage(data: data), let tiffData = img.tiffRepresentation,
                       let rep = NSBitmapImageRep(data: tiffData),
                       let pngData = rep.representation(using: .png, properties: [:]) {
                        return (pngData, "image/png")
                    }
                    return (data, mime)
                }
            }
            if pb.canReadItem(withDataConformingToTypes: ["public.jpeg"]),
               let data = pb.data(forType: NSPasteboard.PasteboardType("public.jpeg")) {
                return (data, "image/jpeg")
            }
            return nil
        }

        private func handleImagePaste(_ data: Data, mimeType: String, in tv: NSTextView) {
            parent.onImagePasted?(data, mimeType)
        }

        // MARK: - Context Menu with Diagram

        func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu {
            let range = view.selectedRange()
            guard range.length > 0,
                  let storage = view.textStorage,
                  range.location + range.length <= storage.length else {
                return menu
            }

            let selectedText = (storage.string as NSString).substring(with: range)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !selectedText.isEmpty else { return menu }

            let diagramTypes: [(id: String, title: String, icon: String)] = [
                ("auto", "Авто (определить тип)", "sparkles"),
                ("flowchart", "Блок-схема / Процесс", "arrow.triangle.branch"),
                ("sequence", "Диаграмма взаимодействия", "person.2.wave.2"),
                ("mindmap", "Карта идей", "brain.head.profile"),
                ("er", "Схема базы данных", "cylinder"),
                ("state", "Диаграмма состояний", "circle.hexagongrid"),
                ("class", "Структура данных", "square.stack.3d.up"),
                ("gantt", "Таймлайн", "calendar.badge.clock"),
                ("pie", "Распределение", "chart.pie"),
            ]

            let diagramMenu = NSMenu()
            for dtype in diagramTypes {
                let item = NSMenuItem(
                    title: dtype.title,
                    action: #selector(diagramContextAction(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = (selectedText, dtype.id)
                item.image = NSImage(systemSymbolName: dtype.icon, accessibilityDescription: dtype.title)?
                    .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
                diagramMenu.addItem(item)
            }

            let parentItem = NSMenuItem(title: "Создать диаграмму", action: nil, keyEquivalent: "")
            parentItem.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "Диаграмма")?
                .withSymbolConfiguration(.init(pointSize: 13, weight: .medium))
            parentItem.submenu = diagramMenu

            menu.insertItem(.separator(), at: 0)
            menu.insertItem(parentItem, at: 0)

            return menu
        }

        @objc func diagramContextAction(_ sender: NSMenuItem) {
            guard let (text, type) = sender.representedObject as? (String, String) else { return }
            parent.onDiagramFromSelection?(text, type)
        }

        func textDidBeginEditing(_ notification: Notification) {
            isEditing = true
        }

        func textDidEndEditing(_ notification: Notification) {
            isEditing = false
            dismissSlashMenu()
            guard let textView = notification.object as? NSTextView else { return }
            let html = MacHTMLConverter.html(from: textView.attributedString())
            lastSetHTML = html
            parent.htmlContent = html
        }

        func textDidChange(_ notification: Notification) {
            guard !isProgrammaticUpdate else { return }
            guard let tv = notification.object as? NSTextView else { return }

            if slashActive {
                updateSlashSearch(in: tv)
            } else {
                checkForSlashTrigger(in: tv)
            }

            let html = MacHTMLConverter.html(from: tv.attributedString())
            lastSetHTML = html
            parent.htmlContent = html
            parent.onTextChange?()
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard slashActive else { return false }

            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                let count = filteredSlashItems().count
                if count > 0 {
                    slashSelectedIndex = min(slashSelectedIndex + 1, count - 1)
                    refreshSlashPanel()
                }
                return true
            }
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                slashSelectedIndex = max(slashSelectedIndex - 1, 0)
                refreshSlashPanel()
                return true
            }
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                let items = filteredSlashItems()
                if !items.isEmpty && slashSelectedIndex < items.count {
                    executeSlashCommand(items[slashSelectedIndex])
                }
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let items = filteredSlashItems()
                if !items.isEmpty && slashSelectedIndex < items.count {
                    executeSlashCommand(items[slashSelectedIndex])
                }
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) ||
               commandSelector == #selector(NSResponder.complete(_:)) {
                dismissSlashMenu()
                return true
            }
            if commandSelector == #selector(NSResponder.deleteBackward(_:)) {
                if let tv = self.textView {
                    let cursor = tv.selectedRange().location
                    if cursor <= slashStartLocation {
                        dismissSlashMenu()
                    }
                }
                return false
            }
            return false
        }

        // MARK: - Slash Command Logic

        private func checkForSlashTrigger(in tv: NSTextView) {
            guard let storage = tv.textStorage else { return }
            let cursorLocation = tv.selectedRange().location
            guard cursorLocation > 0 else { return }

            let charIndex = cursorLocation - 1
            let char = (storage.string as NSString).substring(with: NSRange(location: charIndex, length: 1))
            guard char == "/" else { return }

            let isAtStart = charIndex == 0
            let prevIsNewlineOrSpace: Bool
            if charIndex > 0 {
                let prev = (storage.string as NSString).substring(with: NSRange(location: charIndex - 1, length: 1))
                prevIsNewlineOrSpace = prev.rangeOfCharacter(from: .whitespacesAndNewlines) != nil
            } else {
                prevIsNewlineOrSpace = true
            }

            guard isAtStart || prevIsNewlineOrSpace else { return }

            slashActive = true
            slashStartLocation = charIndex
            slashSearchText = ""
            slashSelectedIndex = 0
            showSlashPanel(in: tv)
        }

        private func updateSlashSearch(in tv: NSTextView) {
            guard let storage = tv.textStorage else { dismissSlashMenu(); return }
            let cursorLocation = tv.selectedRange().location

            if cursorLocation <= slashStartLocation {
                dismissSlashMenu()
                return
            }

            let queryRange = NSRange(location: slashStartLocation + 1, length: cursorLocation - slashStartLocation - 1)
            guard queryRange.location + queryRange.length <= storage.length else {
                dismissSlashMenu()
                return
            }

            let newSearch = (storage.string as NSString).substring(with: queryRange)

            if newSearch.contains("\n") || (newSearch.contains(" ") && newSearch.count > 25) {
                dismissSlashMenu()
                return
            }

            if filteredSlashItemsFor(newSearch).isEmpty && newSearch.count > 3 {
                dismissSlashMenu()
                return
            }

            slashSearchText = newSearch
            slashSelectedIndex = 0
            refreshSlashPanel()
            repositionPanel(in: tv)
        }

        private func buildSlashItems() -> [SlashCommandItem] {
            var items: [SlashCommandItem] = []

            for tag in parent.availableTags {
                items.append(SlashCommandItem(
                    icon: "tag.fill",
                    title: tag.name,
                    subtitle: "Вставить тег в текст",
                    category: .tags,
                    action: .insertTag(tag)
                ))
            }

            items.append(SlashCommandItem(
                icon: "plus.circle",
                title: "Создать тег…",
                subtitle: "Новый тег и вставить",
                category: .tags,
                action: .createTag
            ))

            items.append(contentsOf: [
                SlashCommandItem(icon: "textformat.size.larger", title: "Заголовок 1", subtitle: "Большой заголовок", category: .blocks, action: .heading(1)),
                SlashCommandItem(icon: "textformat.size", title: "Заголовок 2", subtitle: "Средний заголовок", category: .blocks, action: .heading(2)),
                SlashCommandItem(icon: "textformat.size.smaller", title: "Заголовок 3", subtitle: "Маленький заголовок", category: .blocks, action: .heading(3)),
                SlashCommandItem(icon: "text.quote", title: "Цитата", subtitle: "Блок цитаты", category: .blocks, action: .blockquote),
                SlashCommandItem(icon: "chevron.left.forwardslash.chevron.right", title: "Код", subtitle: "Блок кода", category: .blocks, action: .codeBlock),
                SlashCommandItem(icon: "list.bullet", title: "Маркерный список", subtitle: "Список с точками", category: .lists, action: .bulletList),
                SlashCommandItem(icon: "list.number", title: "Нумерованный список", subtitle: "Список с цифрами", category: .lists, action: .numberedList),
                SlashCommandItem(icon: "minus", title: "Разделитель", subtitle: "Горизонтальная линия", category: .insert, action: .separator),
                SlashCommandItem(icon: "note.text", title: "Сноска", subtitle: "Добавить сноску", category: .insert, action: .footnote),
                SlashCommandItem(icon: "photo", title: "Картинка", subtitle: "Вставить изображение", category: .insert, action: .image),
                SlashCommandItem(icon: "tablecells", title: "Таблица", subtitle: "Создать таблицу", category: .insert, action: .table),
                SlashCommandItem(icon: "scribble.variable", title: "Рисунок", subtitle: "Нарисовать схему", category: .insert, action: .drawing),
                SlashCommandItem(icon: "arrow.triangle.branch", title: "Диаграмма", subtitle: "Сгенерировать из описания", category: .insert, action: .diagram),
            ])

            return items
        }

        private func filteredSlashItems() -> [SlashCommandItem] {
            displayOrderItems(for: slashSearchText)
        }

        private func filteredSlashItemsFor(_ search: String) -> [SlashCommandItem] {
            displayOrderItems(for: search)
        }

        private func displayOrderItems(for search: String) -> [SlashCommandItem] {
            let all = buildSlashItems()
            let filtered: [SlashCommandItem]
            if search.isEmpty {
                filtered = all
            } else {
                let q = search.lowercased()
                filtered = all.filter {
                    $0.title.lowercased().contains(q) ||
                    $0.subtitle.lowercased().contains(q) ||
                    $0.category.rawValue.lowercased().contains(q)
                }
            }

            let categoryOrder: [SlashCommandItem.SlashCategory] = [.tags, .blocks, .lists, .insert]
            var result: [SlashCommandItem] = []
            for cat in categoryOrder {
                result.append(contentsOf: filtered.filter { $0.category == cat })
            }
            return result
        }

        // MARK: - Panel Management

        private func showSlashPanel(in tv: NSTextView) {
            guard let window = tv.window else { return }
            cleanupExistingPanel()

            let panelW: CGFloat = 280
            let panelH: CGFloat = 360

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: panelW, height: panelH),
                styleMask: [.nonactivatingPanel],
                backing: .buffered,
                defer: true
            )
            panel.isFloatingPanel = true
            panel.level = .popUpMenu
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true

            if let shadowLayer = panel.contentView?.superview?.layer {
                shadowLayer.shadowColor = NSColor.black.cgColor
                shadowLayer.shadowOpacity = 0.18
                shadowLayer.shadowRadius = 16
                shadowLayer.shadowOffset = CGSize(width: 0, height: -4)
            }

            let blur = NSVisualEffectView()
            blur.material = .popover
            blur.state = .active
            blur.blendingMode = .behindWindow
            blur.wantsLayer = true
            blur.layer?.cornerRadius = 12
            blur.layer?.masksToBounds = true
            blur.layer?.borderWidth = 0.5
            blur.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor

            let hostingView = NSHostingView(rootView: AnyView(
                MacSlashCommandView(
                    items: displayOrderItems(for: ""),
                    searchText: slashSearchText,
                    selectedIndex: slashSelectedIndex,
                    onSelect: { [weak self] item in
                        self?.executeSlashCommand(item)
                    }
                )
            ))

            blur.frame = NSRect(x: 0, y: 0, width: panelW, height: panelH)
            hostingView.frame = blur.bounds
            hostingView.autoresizingMask = [.width, .height]
            blur.addSubview(hostingView)

            panel.contentView = blur
            self.slashPanel = panel
            self.slashHostingView = hostingView

            positionPanelAtCursor(panel, in: tv, window: window)

            panel.alphaValue = 0
            window.addChildWindow(panel, ordered: .above)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }

            if let scrollView = tv.enclosingScrollView {
                scrollObserver = NotificationCenter.default.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: scrollView.contentView,
                    queue: .main
                ) { [weak self, weak tv] _ in
                    guard let self, let tv else { return }
                    Task { @MainActor in
                        self.repositionPanel(in: tv)
                    }
                }
            }
        }

        private func refreshSlashPanel() {
            guard let hostingView = slashHostingView else { return }
            hostingView.rootView = AnyView(
                MacSlashCommandView(
                    items: displayOrderItems(for: ""),
                    searchText: slashSearchText,
                    selectedIndex: slashSelectedIndex,
                    onSelect: { [weak self] item in
                        self?.executeSlashCommand(item)
                    }
                )
            )
        }

        private func repositionPanel(in tv: NSTextView) {
            guard let panel = slashPanel, let window = tv.window else { return }
            positionPanelAtCursor(panel, in: tv, window: window)
        }

        private func positionPanelAtCursor(_ panel: NSPanel, in tv: NSTextView, window: NSWindow) {
            let charRange = NSRange(location: slashStartLocation, length: 1)
            var actualRange = charRange
            let screenRect = tv.firstRect(forCharacterRange: charRange, actualRange: &actualRange)

            guard screenRect != .zero else { return }

            let panelSize = panel.frame.size
            let lineHeight: CGFloat = 20

            guard let screen = window.screen ?? NSScreen.main else { return }
            let screenFrame = screen.visibleFrame

            let spaceBelow = screenRect.origin.y - screenFrame.origin.y
            let spaceAbove = screenFrame.maxY - (screenRect.origin.y + lineHeight)

            let panelOrigin: NSPoint
            if spaceBelow > panelSize.height + 4 {
                panelOrigin = NSPoint(
                    x: screenRect.origin.x,
                    y: screenRect.origin.y - panelSize.height - 4
                )
            } else if spaceAbove > panelSize.height + 4 {
                panelOrigin = NSPoint(
                    x: screenRect.origin.x,
                    y: screenRect.origin.y + lineHeight + 4
                )
            } else {
                panelOrigin = NSPoint(
                    x: screenRect.origin.x,
                    y: screenRect.origin.y - panelSize.height - 4
                )
            }

            let clampedX = min(max(panelOrigin.x, screenFrame.origin.x),
                               screenFrame.maxX - panelSize.width)

            panel.setFrameOrigin(NSPoint(x: clampedX, y: panelOrigin.y))
        }

        // MARK: - Command Execution

        private func executeSlashCommand(_ item: SlashCommandItem) {
            guard let tv = textView, let storage = tv.textStorage else { return }

            let cursorLocation = tv.selectedRange().location
            let removeRange = NSRange(location: slashStartLocation, length: cursorLocation - slashStartLocation)

            switch item.action {
            case .insertTag(let tag):
                let tagText = NSMutableAttributedString(string: " #\(tag.name) ")
                let bgColor = nsBackgroundColor(for: tag.tagColor)
                let fgColor = nsForegroundColor(for: tag.tagColor)

                tagText.addAttributes([
                    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: fgColor,
                    .backgroundColor: bgColor,
                    .toolTip: "tag:\(tag.id.uuidString)",
                ], range: NSRange(location: 0, length: tagText.length))

                storage.replaceCharacters(in: removeRange, with: tagText)
                tv.setSelectedRange(NSRange(location: slashStartLocation + tagText.length, length: 0))
                parent.onSlashCommand?(.insertTag(tag))

            case .createTag:
                storage.replaceCharacters(in: removeRange, with: "")
                tv.setSelectedRange(NSRange(location: slashStartLocation, length: 0))
                parent.onSlashCommand?(.createTag)

            default:
                storage.replaceCharacters(in: removeRange, with: "")
                tv.setSelectedRange(NSRange(location: slashStartLocation, length: 0))
                switch item.action {
                case .heading(let level): applyFormat(.heading(level))
                case .bulletList: applyFormat(.bulletList)
                case .numberedList: applyFormat(.numberedList)
                case .blockquote: applyFormat(.blockquote)
                case .codeBlock: applyFormat(.codeBlock)
                case .separator: applyFormat(.separator)
                case .footnote: applyFormat(.footnote)
                case .image: applyFormat(.insertImage)
                case .table: applyFormat(.insertTable)
                case .drawing: parent.onSlashCommand?(.drawing)
                case .diagram: parent.onSlashCommand?(.diagram)
                default: break
                }
            }

            dismissSlashMenu()
            syncHTML(from: tv)
        }

        private func nsBackgroundColor(for color: TagColor) -> NSColor {
            switch color {
            case .red: return NSColor.systemRed.withAlphaComponent(0.12)
            case .orange: return NSColor.systemOrange.withAlphaComponent(0.12)
            case .yellow: return NSColor.systemYellow.withAlphaComponent(0.12)
            case .green: return NSColor.systemGreen.withAlphaComponent(0.12)
            case .blue: return NSColor.systemBlue.withAlphaComponent(0.12)
            case .purple: return NSColor.systemPurple.withAlphaComponent(0.12)
            case .pink: return NSColor.systemPink.withAlphaComponent(0.12)
            case .teal: return NSColor.systemTeal.withAlphaComponent(0.12)
            }
        }

        private func nsForegroundColor(for color: TagColor) -> NSColor {
            switch color {
            case .red: return .systemRed
            case .orange: return .systemOrange
            case .yellow: return NSColor(red: 0.7, green: 0.6, blue: 0.0, alpha: 1.0)
            case .green: return .systemGreen
            case .blue: return .systemBlue
            case .purple: return .systemPurple
            case .pink: return .systemPink
            case .teal: return .systemTeal
            }
        }

        private func cleanupExistingPanel() {
            if let observer = scrollObserver {
                NotificationCenter.default.removeObserver(observer)
                scrollObserver = nil
            }
            if let panel = slashPanel {
                panel.parent?.removeChildWindow(panel)
                panel.orderOut(nil)
            }
            slashPanel = nil
            slashHostingView = nil
        }

        func dismissSlashMenu() {
            guard slashActive || slashPanel != nil else { return }
            slashActive = false

            if let observer = scrollObserver {
                NotificationCenter.default.removeObserver(observer)
                scrollObserver = nil
            }

            if let panel = slashPanel {
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.1
                    panel.animator().alphaValue = 0
                }, completionHandler: {
                    Task { @MainActor in
                        panel.parent?.removeChildWindow(panel)
                        panel.orderOut(nil)
                    }
                })
            }

            slashPanel = nil
            slashHostingView = nil
        }

        func applyFormat(_ action: MacFormatAction) {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let range = tv.selectedRange()

            tv.breakUndoCoalescing()

            switch action {
            case .bold:
                tv.setFont(toggleTrait(.boldFontMask, in: tv), range: range)

            case .italic:
                tv.setFont(toggleTrait(.italicFontMask, in: tv), range: range)

            case .underline:
                undoableAttrChange(in: tv) {
                    toggleInlineAttr(.underlineStyle, onValue: NSUnderlineStyle.single.rawValue, offValue: 0, in: tv, range: range)
                }

            case .strikethrough:
                undoableAttrChange(in: tv) {
                    toggleInlineAttr(.strikethroughStyle, onValue: NSUnderlineStyle.single.rawValue, offValue: 0, in: tv, range: range)
                }

            case .heading(let level):
                let sizes: [Int: CGFloat] = [1: 26, 2: 22, 3: 18]
                let size = sizes[level] ?? 15
                let font = NSFont.boldSystemFont(ofSize: size)
                let lineRange = (storage.string as NSString).lineRange(for: range)
                let lineText = (storage.string as NSString).substring(with: lineRange).trimmingCharacters(in: .newlines)
                if lineText.isEmpty {
                    tv.typingAttributes[.font] = font
                } else {
                    undoableAttrChange(in: tv) {
                        storage.addAttribute(.font, value: font, range: lineRange)
                    }
                }

            case .bulletList:
                let lineRange = (storage.string as NSString).lineRange(for: range)
                let lineText = (storage.string as NSString).substring(with: lineRange).trimmingCharacters(in: .newlines)
                if lineText.isEmpty {
                    tv.insertText("• ", replacementRange: range)
                } else {
                    insertPrefix("• ", in: tv)
                }

            case .numberedList:
                let lineRange = (storage.string as NSString).lineRange(for: range)
                let lineText = (storage.string as NSString).substring(with: lineRange).trimmingCharacters(in: .newlines)
                if lineText.isEmpty {
                    tv.insertText("1. ", replacementRange: range)
                } else {
                    insertPrefix("1. ", in: tv)
                }

            case .blockquote:
                let lineRange = (storage.string as NSString).lineRange(for: range)
                let lineText = (storage.string as NSString).substring(with: lineRange).trimmingCharacters(in: .newlines)
                if lineText.isEmpty {
                    let pStyle = NSMutableParagraphStyle()
                    pStyle.headIndent = 20
                    pStyle.firstLineHeadIndent = 20
                    pStyle.paragraphSpacingBefore = 6
                    pStyle.paragraphSpacing = 6
                    let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    let quoteColor: NSColor = isDark ? .init(white: 0.7, alpha: 1) : .init(white: 0.4, alpha: 1)
                    tv.typingAttributes[.paragraphStyle] = pStyle
                    tv.typingAttributes[.foregroundColor] = quoteColor
                } else {
                    undoableAttrChange(in: tv) {
                        applyBlockquote(in: tv)
                    }
                }

            case .codeBlock:
                let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                if range.length > 0 {
                    undoableAttrChange(in: tv) {
                        storage.addAttribute(.font, value: font, range: range)
                        storage.addAttribute(.backgroundColor, value: NSColor.quaternaryLabelColor, range: range)
                    }
                } else {
                    tv.typingAttributes[.font] = font
                    tv.typingAttributes[.backgroundColor] = NSColor.quaternaryLabelColor
                }

            case .separator:
                tv.insertText("\n---\n", replacementRange: range)

            case .highlight(let color):
                if range.length > 0 {
                    undoableAttrChange(in: tv) {
                        storage.addAttribute(.backgroundColor, value: color.nsColor, range: range)
                    }
                } else {
                    tv.typingAttributes[.backgroundColor] = color.nsColor
                }

            case .removeHighlight:
                if range.length > 0 {
                    undoableAttrChange(in: tv) {
                        storage.removeAttribute(.backgroundColor, range: range)
                    }
                } else {
                    tv.typingAttributes.removeValue(forKey: .backgroundColor)
                }

            case .footnote:
                insertFootnote(in: tv)

            case .clearFormatting:
                clearAllFormatting(in: tv)

            case .setFont(let noteFont):
                applyNoteFont(noteFont, in: tv, range: range)

            case .cleanPaste:
                cleanPasteFormatting(in: tv)

            case .insertImage:
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.png, .jpeg, .gif, .webP]
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                if panel.runModal() == .OK, let url = panel.url,
                   let data = try? Data(contentsOf: url) {
                    let mimeType = url.pathExtension.lowercased() == "png" ? "image/png"
                        : url.pathExtension.lowercased() == "gif" ? "image/gif"
                        : url.pathExtension.lowercased() == "webp" ? "image/webp"
                        : "image/jpeg"
                    parent.onImagePasted?(data, mimeType)
                }
                return

            case .insertTable:
                parent.onTableInsert?()
                return

            case .insertDiagram:
                return

            case .insertImageData(let data, let mimeType):
                insertUploadedImage(data: data, mimeType: mimeType, in: tv)

            case .forceReload:
                isEditing = false
                loadHTML(parent.htmlContent, into: tv)
                return
            }

            syncHTML(from: tv)
        }

        private func applyNoteFont(_ noteFont: NoteFont, in tv: NSTextView, range: NSRange) {
            guard let storage = tv.textStorage else { return }
            let fullRange = range.length > 0 ? range : NSRange(location: 0, length: storage.length)
            guard fullRange.length > 0 else {
                tv.typingAttributes[.font] = noteFont.nsFont(size: 15)
                return
            }
            undoableAttrChange(in: tv) {
                storage.enumerateAttribute(.font, in: fullRange, options: []) { value, subRange, _ in
                    let oldFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: 15)
                    let isBold = oldFont.fontDescriptor.symbolicTraits.contains(.bold)
                    let size = oldFont.pointSize
                    let newFont = noteFont.nsFont(size: size, bold: isBold)
                    storage.addAttribute(.font, value: newFont, range: subRange)
                }
            }
        }

        private func cleanPasteFormatting(in tv: NSTextView) {
            guard let storage = tv.textStorage else { return }
            let range = tv.selectedRange()
            let cleanRange = range.length > 0 ? range : NSRange(location: 0, length: storage.length)
            guard cleanRange.length > 0 else { return }

            tv.breakUndoCoalescing()
            undoableAttrChange(in: tv) {
                let defaultFont = NSFont.systemFont(ofSize: 15)
                let headingThreshold: CGFloat = 18

                storage.enumerateAttributes(in: cleanRange, options: []) { attrs, subRange, _ in
                    let font = (attrs[.font] as? NSFont) ?? defaultFont
                    let isBold = font.fontDescriptor.symbolicTraits.contains(.bold)
                    let isItalic = font.fontDescriptor.symbolicTraits.contains(.italic)
                    let isLargeText = font.pointSize >= headingThreshold

                    var newFont: NSFont
                    if isLargeText && isBold {
                        let headingSize: CGFloat = font.pointSize >= 24 ? 26 : font.pointSize >= 20 ? 22 : 18
                        newFont = NSFont.boldSystemFont(ofSize: headingSize)
                    } else if isBold && isItalic {
                        var traits: NSFontDescriptor.SymbolicTraits = [.bold, .italic]
                        let desc = NSFont.systemFont(ofSize: 15).fontDescriptor.withSymbolicTraits(traits)
                        newFont = NSFont(descriptor: desc, size: 15) ?? defaultFont
                    } else if isBold {
                        newFont = NSFont.boldSystemFont(ofSize: 15)
                    } else if isItalic {
                        let desc = defaultFont.fontDescriptor.withSymbolicTraits(.italic)
                        newFont = NSFont(descriptor: desc, size: 15) ?? defaultFont
                    } else {
                        newFont = defaultFont
                    }

                    storage.setAttributes([
                        .font: newFont,
                        .foregroundColor: NSColor.textColor
                    ], range: subRange)

                    if let underline = attrs[.underlineStyle] as? Int, underline != 0 {
                        storage.addAttribute(.underlineStyle, value: underline, range: subRange)
                    }
                    if let strike = attrs[.strikethroughStyle] as? Int, strike != 0 {
                        storage.addAttribute(.strikethroughStyle, value: strike, range: subRange)
                    }
                }
            }
        }

        private func undoableAttrChange(in tv: NSTextView, _ block: () -> Void) {
            guard let storage = tv.textStorage else { return }
            let before = storage.attributedSubstring(from: NSRange(location: 0, length: storage.length)).copy() as! NSAttributedString

            storage.beginEditing()
            block()
            storage.endEditing()

            tv.undoManager?.registerUndo(withTarget: tv) { [weak self] textView in
                textView.textStorage?.setAttributedString(before)
                self?.syncHTML(from: textView)
            }
        }

        // MARK: - Helpers

        private func syncHTML(from tv: NSTextView) {
            let html = MacHTMLConverter.html(from: tv.attributedString())
            lastSetHTML = html
            parent.htmlContent = html
            parent.onTextChange?()
        }

        private func toggleInlineAttr(_ key: NSAttributedString.Key, onValue: Any, offValue: Any, in tv: NSTextView, range: NSRange) {
            guard let storage = tv.textStorage else { return }
            if range.length > 0 {
                let attrs = storage.attributes(at: range.location, effectiveRange: nil)
                let current = attrs[key] as? Int ?? 0
                let newVal = current == 0 ? onValue : offValue
                storage.addAttribute(key, value: newVal, range: range)
            } else {
                let current = tv.typingAttributes[key] as? Int ?? 0
                tv.typingAttributes[key] = current == 0 ? onValue : offValue
            }
        }

        private func toggleTrait(_ trait: NSFontTraitMask, in tv: NSTextView) -> NSFont {
            let fm = NSFontManager.shared
            let range = tv.selectedRange()
            let currentFont: NSFont
            if range.length > 0, let storage = tv.textStorage {
                currentFont = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
                    ?? NSFont.systemFont(ofSize: 15)
            } else {
                currentFont = tv.typingAttributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 15)
            }
            let traits = fm.traits(of: currentFont)
            if traits.contains(trait) {
                return fm.convert(currentFont, toNotHaveTrait: trait)
            } else {
                return fm.convert(currentFont, toHaveTrait: trait)
            }
        }

        private func insertPrefix(_ prefix: String, in tv: NSTextView) {
            guard let storage = tv.textStorage else { return }
            let range = tv.selectedRange()
            let lineRange = (storage.string as NSString).lineRange(for: range)
            let lineText = (storage.string as NSString).substring(with: lineRange)
            let lines = lineText.components(separatedBy: "\n")
            let prefixed = lines.map { $0.isEmpty ? $0 : prefix + $0 }.joined(separator: "\n")
            tv.insertText(prefixed, replacementRange: lineRange)
        }

        private func applyBlockquote(in tv: NSTextView) {
            guard let storage = tv.textStorage else { return }
            let range = tv.selectedRange()
            let lineRange = (storage.string as NSString).lineRange(for: range)

            let pStyle = NSMutableParagraphStyle()
            pStyle.headIndent = 20
            pStyle.firstLineHeadIndent = 20
            pStyle.paragraphSpacingBefore = 6
            pStyle.paragraphSpacing = 6

            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let quoteColor: NSColor = isDark ? .init(white: 0.7, alpha: 1) : .init(white: 0.4, alpha: 1)

            storage.addAttribute(.paragraphStyle, value: pStyle, range: lineRange)
            storage.addAttribute(.foregroundColor, value: quoteColor, range: lineRange)
        }

        private func insertFootnote(in tv: NSTextView) {
            guard let storage = tv.textStorage else { return }
            let text = storage.string

            var footnoteCount = 0
            let pattern = "\\[\\^(\\d+)\\]"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.count))
                var ids = Set<Int>()
                for match in matches {
                    if match.numberOfRanges > 1, let numRange = Range(match.range(at: 1), in: text) {
                        if let num = Int(text[numRange]) { ids.insert(num) }
                    }
                }
                footnoteCount = ids.count
            }

            let num = footnoteCount + 1
            let range = tv.selectedRange()

            let superRef = NSMutableAttributedString(string: "[\(num)]")
            superRef.addAttributes([
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .superscript: 1,
                .foregroundColor: NSColor.systemBlue
            ], range: NSRange(location: 0, length: superRef.length))

            storage.insert(superRef, at: range.location)

            let footerSep = "\n\n---\n"
            let footerNote = "[\(num)] "
            let footer = NSMutableAttributedString(string: footerSep + footerNote)
            footer.addAttributes([
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.secondaryLabelColor
            ], range: NSRange(location: 0, length: footer.length))

            storage.append(footer)
            tv.setSelectedRange(NSRange(location: storage.length, length: 0))
        }

        private func insertUploadedImage(data: Data, mimeType: String, in tv: NSTextView) {
            Task {
                do {
                    let result = try await APIService.shared.uploadImage(data: data, mimeType: mimeType)
                    guard let image = NSImage(data: data) else { return }
                    let attachment = MacHTMLConverter.insertImageAttachment(url: result.url, image: image)
                    let range = tv.selectedRange()
                    tv.textStorage?.insert(attachment, at: range.location)
                    tv.setSelectedRange(NSRange(location: range.location + attachment.length, length: 0))
                    syncHTML(from: tv)
                } catch {
                    print("Image upload error: \(error)")
                }
            }
        }

        func insertTableHTML(_ tableHTML: String, tableData: TableData) {
            guard let tv = textView else { return }
            let placeholder = MacHTMLConverter.insertTablePlaceholder(tableHTML: tableHTML, tableData: tableData)
            let range = tv.selectedRange()
            tv.textStorage?.insert(placeholder, at: range.location)
            tv.setSelectedRange(NSRange(location: range.location + placeholder.length, length: 0))
            syncHTML(from: tv)
        }

        private func clearAllFormatting(in tv: NSTextView) {
            guard let storage = tv.textStorage else { return }
            let range = tv.selectedRange()
            guard range.length > 0 else { return }

            let plainText = storage.attributedSubstring(from: range).string
            let clean = NSAttributedString(string: plainText, attributes: [
                .font: NSFont.systemFont(ofSize: 15),
                .foregroundColor: NSColor.labelColor
            ])
            storage.replaceCharacters(in: range, with: clean)
        }
    }
}

