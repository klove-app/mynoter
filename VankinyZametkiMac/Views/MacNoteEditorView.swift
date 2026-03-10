import SwiftUI

struct MacNoteEditorView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var folderStore: FolderStore
    @EnvironmentObject private var tagStore: TagStore

    @State private var note: Note
    @State private var title: String
    @State private var htmlContent: String
    @State private var synopsis: String
    @State private var chapterStatus: ChapterStatus
    @State private var noteTags: [Tag]
    @State private var isSaving = false
    @State private var saveTask: Task<Void, Never>?
    @State private var showSaved = false
    @State private var showVoiceAppend = false
    @State private var pendingVoiceHTML: String?
    @State private var currentFormatAction: MacFormatAction?
    @State private var showCreateTag = false
    @State private var showTableEditor = false
    @State private var editingTableData: TableData?
    @State private var isUploadingImage = false
    @State private var showDrawingCanvas = false
    @State private var isNormalizing = false
    @State private var showDiagramInput = false
    @State private var diagramDescription = ""
    @State private var isGeneratingDiagram = false
    @State private var showDiagramEditor = false
    @State private var editingDiagramURL = ""
    @State private var editingDiagramMermaid = ""
    @State private var editingDiagramRange = NSRange(location: 0, length: 0)
    @State private var editingDiagramDescription = ""
    @State private var editingDiagramImage: NSImage?

    var bookContext: MacBookContext?
    private var isBookChapter: Bool { bookContext != nil }

    init(note: Note, bookContext: MacBookContext? = nil) {
        _note = State(initialValue: note)
        _title = State(initialValue: note.title)
        _htmlContent = State(initialValue: note.content)
        _synopsis = State(initialValue: note.synopsis)
        _chapterStatus = State(initialValue: note.status)
        _noteTags = State(initialValue: note.tags)
        self.bookContext = bookContext
    }

    var body: some View {
        VStack(spacing: 0) {
            breadcrumbBar

            MacFormattingToolbar { action in
                handleFormatAction(action)
            }

            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    TextField("Заголовок", text: $title)
                        .font(.system(size: 26, weight: .bold))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 32)
                        .padding(.top, 20)
                        .padding(.bottom, isBookChapter ? 4 : 12)
                        .onChange(of: title) { _, _ in scheduleAutoSave() }
                        .frame(maxWidth: 740)
                        .frame(maxWidth: .infinity)

                    if isBookChapter {
                        TextField("Синопсис главы...", text: $synopsis)
                            .font(.callout)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 8)
                            .onChange(of: synopsis) { _, _ in scheduleAutoSave() }
                            .frame(maxWidth: 740)
                            .frame(maxWidth: .infinity)
                    }

                    if note.isVoiceNote, let audioUrl = note.audioUrl {
                        MacAudioPlayerView(urlString: audioUrl)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 12)
                            .frame(maxWidth: 740)
                            .frame(maxWidth: .infinity)
                    }

                    MacRichTextEditor(
                        htmlContent: $htmlContent,
                        onTextChange: { scheduleAutoSave() },
                        formatAction: currentFormatAction,
                        availableTags: tagStore.tags,
                        onSlashCommand: { action in
                            handleSlashCommand(action)
                        },
                        onImagePasted: { data, mimeType in
                            uploadAndInsertImage(data: data, mimeType: mimeType)
                        },
                        onTableInsert: {
                            editingTableData = TableData.empty(rows: 3, columns: 3)
                            showTableEditor = true
                        },
                        onDiagramFromSelection: { text, type in
                            generateDiagramFromSelection(text: text, type: type)
                        },
                        onDiagramClicked: { url, mermaid, range, image in
                            editingDiagramURL = url
                            editingDiagramMermaid = mermaid
                            editingDiagramRange = range
                            editingDiagramDescription = ""
                            editingDiagramImage = image
                            showDiagramEditor = true
                        }
                    )
                }

                if isUploadingImage {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Загрузка изображения…")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if showSaved {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 5, height: 5)
                        Text("Сохранено")
                            .font(.ds.caption)
                    }
                    .foregroundStyle(.secondary)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .animation(.spring(duration: 0.3), value: showSaved)
                } else if isSaving {
                    ProgressView()
                        .controlSize(.small)
                }

                if isBookChapter, let ctx = bookContext {
                    HStack(spacing: 2) {
                        Button {} label: {
                            Image(systemName: "chevron.up")
                        }
                        .disabled(ctx.currentIndex <= 0)

                        Text("Гл. \(ctx.currentIndex + 1)/\(ctx.chapters.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Button {} label: {
                            Image(systemName: "chevron.down")
                        }
                        .disabled(ctx.currentIndex >= ctx.chapters.count - 1)
                    }
                }

                Button { showVoiceAppend = true } label: {
                    Image(systemName: "mic.badge.plus")
                }
                .help("Добавить голосом")

                Button {
                    normalizeFormatting()
                } label: {
                    if isNormalizing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                }
                .help("AI-форматирование")
                .disabled(isNormalizing || htmlContent.isEmpty)

                Button {
                    NotificationCenter.default.post(name: .toggleDistractionFree, object: nil)
                } label: {
                    Image(systemName: "rectangle.expand.vertical")
                }
                .help("Режим фокуса ⇧⌘F")
            }
        }
        .sheet(isPresented: $showDrawingCanvas) {
            MacDrawingView(
                onSave: { pngData in
                    showDrawingCanvas = false
                    uploadAndInsertImage(data: pngData, mimeType: "image/png")
                },
                onCancel: { showDrawingCanvas = false }
            )
        }
        .sheet(isPresented: $showDiagramInput) {
            diagramInputSheet
        }
        .sheet(isPresented: $showDiagramEditor) {
            diagramEditorSheet
        }
        .sheet(isPresented: $showTableEditor) {
            MacTableEditorView(
                tableData: editingTableData ?? TableData.empty(rows: 3, columns: 3),
                onSave: { savedTable in
                    showTableEditor = false
                    let tableHTML = savedTable.toHTML()
                    if htmlContent.isEmpty {
                        htmlContent = tableHTML
                    } else {
                        htmlContent += "<br>" + tableHTML
                    }
                    scheduleAutoSave()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        triggerFormat(.forceReload)
                    }
                },
                onCancel: {
                    showTableEditor = false
                }
            )
        }
        .sheet(isPresented: $showVoiceAppend, onDismiss: {
            guard let html = pendingVoiceHTML else { return }
            pendingVoiceHTML = nil
            if htmlContent.isEmpty {
                htmlContent = html
            } else {
                htmlContent += "<hr>" + html
            }
            scheduleAutoSave()
        }) {
            MacVoiceAppendView { appendedHTML in
                pendingVoiceHTML = appendedHTML
            }
            .frame(width: 440, height: 380)
        }
        .task {
            if folderStore.folders.isEmpty {
                await folderStore.loadFolders()
            }
        }
        .onChange(of: chapterStatus) { _, _ in scheduleAutoSave() }
        .onReceive(NotificationCenter.default.publisher(for: .formatBold)) { _ in
            triggerFormat(.bold)
        }
        .onReceive(NotificationCenter.default.publisher(for: .formatItalic)) { _ in
            triggerFormat(.italic)
        }
        .onReceive(NotificationCenter.default.publisher(for: .formatUnderline)) { _ in
            triggerFormat(.underline)
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveNote)) { _ in
            Task { await saveNote() }
        }
    }

    // MARK: - Tags Bar

    private var noteTagsBar: some View {
        HStack(spacing: 4) {
            ForEach(noteTags) { tag in
                HStack(spacing: 2) {
                    Circle()
                        .fill(tag.swiftUIColor)
                        .frame(width: 5, height: 5)
                    Text(tag.name)
                        .font(.system(size: 11))
                }
                .foregroundStyle(.tertiary)
                .contextMenu {
                    Button("Убрать тег", role: .destructive) {
                        Task {
                            let updated = await tagStore.removeTag(tag.id, fromNote: note.id)
                            noteTags = updated
                            if let idx = noteStore.notes.firstIndex(where: { $0.id == note.id }) {
                                noteStore.notes[idx].tags = updated
                            }
                        }
                    }
                }
            }

            Menu {
                let available = tagStore.tags.filter { tag in
                    !noteTags.contains(where: { $0.id == tag.id })
                }
                if !available.isEmpty {
                    ForEach(available) { tag in
                        Button {
                            Task {
                                let updated = await tagStore.addTag(tag.id, toNote: note.id)
                                noteTags = updated
                                if let idx = noteStore.notes.firstIndex(where: { $0.id == note.id }) {
                                    noteStore.notes[idx].tags = updated
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Circle().fill(tag.swiftUIColor).frame(width: 8, height: 8)
                                Text(tag.name)
                            }
                        }
                    }
                    Divider()
                }
                Button {
                    showCreateTag = true
                } label: {
                    Label("Создать тег…", systemImage: "plus")
                }
            } label: {
                Image(systemName: "tag")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .sheet(isPresented: $showCreateTag) {
            MacNewTagView { name, color in
                Task {
                    if let newTag = await tagStore.createTag(name: name, color: color.rawValue) {
                        let updated = await tagStore.addTag(newTag.id, toNote: note.id)
                        noteTags = updated
                        if let idx = noteStore.notes.firstIndex(where: { $0.id == note.id }) {
                            noteStore.notes[idx].tags = updated
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bottom Bar (tags + status)

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Color.ds.separator.opacity(0.3).frame(height: 0.5)

            HStack(spacing: 8) {
                noteTagsBar

                Spacer(minLength: 4)

                let wc = computeWordCount()
                Text("\(wc) \(wordDeclension(wc))")
                    .font(.system(size: 11).monospacedDigit())

                Text("·")
                    .font(.system(size: 11))

                Text(formattedDate)
                    .font(.system(size: 11))

                if isBookChapter, let ctx = bookContext {
                    Text("·")
                        .font(.system(size: 11))
                    Text("Гл. \(ctx.currentIndex + 1)")
                        .font(.system(size: 11))
                }
            }
            .foregroundStyle(.quaternary)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Breadcrumb Bar

    private var breadcrumbBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: isBookChapter ? "book.closed.fill" : "folder.fill")
                    .font(.system(size: 10))
                Text(folderName)
                    .font(.system(size: 12))
                    .lineLimit(1)

                if !title.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.quaternary)
                    Text(title)
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(.tertiary)

            Spacer()

            if isBookChapter {
                Menu {
                    ForEach(ChapterStatus.allCases, id: \.self) { status in
                        Button {
                            chapterStatus = status
                        } label: {
                            HStack {
                                Image(systemName: status.icon)
                                Text(status.displayName)
                                if status == chapterStatus {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: chapterStatus.icon)
                            .font(.system(size: 9))
                        Text(chapterStatus.displayName)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.10), in: Capsule())
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.ds.separator.opacity(0.08))
    }

    private var statusColor: Color {
        switch chapterStatus {
        case .draft: return .gray
        case .inProgress: return .blue
        case .revised: return .orange
        case .final_: return .green
        }
    }

    private var folderName: String {
        if let fid = note.folderId,
           let folder = folderStore.folders.first(where: { $0.id == fid }) {
            return folder.name
        }
        return "Без папки"
    }

    // MARK: - Slash Commands

    private func handleSlashCommand(_ action: SlashCommandItem.SlashAction) {
        switch action {
        case .insertTag(let tag):
            Task {
                if !noteTags.contains(where: { $0.id == tag.id }) {
                    let updated = await tagStore.addTag(tag.id, toNote: note.id)
                    noteTags = updated
                    if let idx = noteStore.notes.firstIndex(where: { $0.id == note.id }) {
                        noteStore.notes[idx].tags = updated
                    }
                }
            }
        case .createTag:
            showCreateTag = true
        case .drawing:
            showDrawingCanvas = true
        case .diagram:
            showDiagramInput = true
        default:
            break
        }
    }

    // MARK: - AI Normalize

    private func normalizeFormatting() {
        guard !htmlContent.isEmpty, !isNormalizing else { return }
        isNormalizing = true
        Task {
            defer { isNormalizing = false }
            do {
                let normalized = try await APIService.shared.normalizeContent(html: htmlContent)
                htmlContent = normalized
                triggerFormat(.forceReload)
                scheduleAutoSave()
            } catch {
                print("Normalize error: \(error)")
            }
        }
    }

    // MARK: - Diagram Generation

    private var diagramInputSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(.purple)
                Text("Создать диаграмму")
                    .font(.headline)
                Spacer()
            }

            Text("Опишите что нужно изобразить — процесс, схему, структуру, взаимодействие")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextEditor(text: $diagramDescription)
                .font(.body)
                .frame(height: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))

            HStack(spacing: 12) {
                Text("Примеры: «процесс регистрации пользователя», «структура БД магазина», «взаимодействие микросервисов»")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)

                Spacer()

                Button("Отмена") {
                    showDiagramInput = false
                    diagramDescription = ""
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    generateDiagram()
                } label: {
                    if isGeneratingDiagram {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 60)
                    } else {
                        Text("Создать")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(diagramDescription.trimmingCharacters(in: .whitespaces).isEmpty || isGeneratingDiagram)
            }
        }
        .padding(20)
        .frame(width: 500)
    }

    private var diagramEditorSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "pencil.and.outline")
                    .foregroundStyle(.purple)
                Text("Редактировать диаграмму")
                    .font(.headline)
                Spacer()
                Button {
                    showDiagramEditor = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                if let nsImage = editingDiagramImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .cornerRadius(8)
                        .padding(20)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Изображение недоступно")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .padding(20)
                }
            }
            .frame(maxHeight: 400)

            Divider()

            VStack(spacing: 12) {
                DisclosureGroup("Mermaid-код") {
                    ScrollView {
                        Text(editingDiagramMermaid)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(maxHeight: 120)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text("Опишите изменения для перегенерации:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextEditor(text: $editingDiagramDescription)
                    .font(.body)
                    .frame(height: 80)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))

                HStack(spacing: 12) {
                    Spacer()

                    Button("Удалить") {
                        deleteDiagram()
                    }
                    .foregroundStyle(.red)

                    Button {
                        regenerateDiagram()
                    } label: {
                        if isGeneratingDiagram {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 100)
                        } else {
                            Text("Перегенерировать")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(editingDiagramDescription.trimmingCharacters(in: .whitespaces).isEmpty && !isGeneratingDiagram)
                }
            }
            .padding(20)
        }
        .frame(width: 650)
        .frame(minHeight: 500)
    }

    private func regenerateDiagram() {
        let desc = editingDiagramDescription.trimmingCharacters(in: .whitespaces)
        let prompt = desc.isEmpty ? editingDiagramMermaid : "\(editingDiagramMermaid)\n\nИзменения: \(desc)"
        isGeneratingDiagram = true
        let oldRange = editingDiagramRange

        Task {
            defer { isGeneratingDiagram = false }
            do {
                let result = try await APIService.shared.generateDiagram(description: prompt, type: "auto")
                editingDiagramURL = result.url
                editingDiagramMermaid = result.mermaidCode
                editingDiagramDescription = ""

                if let url = URL(string: result.url) {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    editingDiagramImage = NSImage(data: data)
                }

                replaceDiagramInEditor(at: oldRange, newURL: result.url, mermaidCode: result.mermaidCode)
                scheduleAutoSave()
            } catch {
                print("Diagram regeneration error: \(error)")
            }
        }
    }

    private func deleteDiagram() {
        showDiagramEditor = false
        triggerFormat(.deleteDiagramAt(editingDiagramRange))
        scheduleAutoSave()
    }

    private func replaceDiagramInEditor(at range: NSRange, newURL: String, mermaidCode: String) {
        triggerFormat(.replaceDiagram(range: range, url: newURL, mermaidCode: mermaidCode))
    }

    private func generateDiagram() {
        let desc = diagramDescription.trimmingCharacters(in: .whitespaces)
        guard !desc.isEmpty else { return }
        isGeneratingDiagram = true

        Task {
            defer { isGeneratingDiagram = false }
            do {
                let result = try await APIService.shared.generateDiagram(description: desc)
                showDiagramInput = false
                diagramDescription = ""
                insertDiagramImage(url: result.url)
            } catch {
                print("Diagram generation error: \(error)")
            }
        }
    }

    private func generateDiagramFromSelection(text: String, type: String) {
        isGeneratingDiagram = true
        Task {
            defer { isGeneratingDiagram = false }
            do {
                let result = try await APIService.shared.generateDiagram(description: text, type: type)
                triggerFormat(.insertDiagramResult(url: result.url, mermaidCode: result.mermaidCode))
            } catch {
                print("Diagram from selection error: \(error)")
            }
        }
    }

    private func insertDiagramImage(url: String) {
        let imgTag = "<img src=\"\(url)\" style=\"max-width:100%;height:auto;border-radius:6px;\">"
        if htmlContent.isEmpty {
            htmlContent = imgTag
        } else {
            htmlContent += "<br>" + imgTag
        }
        scheduleAutoSave()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            triggerFormat(.forceReload)
        }
    }

    // MARK: - Image Upload

    private func handleFormatAction(_ action: MacFormatAction) {
        switch action {
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
                uploadAndInsertImage(data: data, mimeType: mimeType)
            }
        case .insertTable:
            editingTableData = TableData.empty(rows: 3, columns: 3)
            showTableEditor = true
        case .insertDiagram:
            showDiagramInput = true
        default:
            triggerFormat(action)
        }
    }

    private func uploadAndInsertImage(data: Data, mimeType: String) {
        isUploadingImage = true
        Task {
            defer { isUploadingImage = false }
            do {
                let result = try await APIService.shared.uploadImage(data: data, mimeType: mimeType)
                let imgTag = "<img src=\"\(result.url)\" style=\"max-width:100%;height:auto;border-radius:6px;\">"
                if htmlContent.isEmpty {
                    htmlContent = imgTag
                } else {
                    htmlContent += "<br>" + imgTag
                }
                scheduleAutoSave()
                triggerFormat(.forceReload)
            } catch {
                print("Image upload error: \(error)")
            }
        }
    }

    // MARK: - Formatting

    private func triggerFormat(_ action: MacFormatAction) {
        currentFormatAction = action
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            currentFormatAction = nil
        }
    }

    // MARK: - Text Stats

    private var plainText: String {
        htmlContent.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    }

    private func computeWordCount() -> Int {
        plainText.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    private func computeCharCount() -> Int {
        plainText.filter { !$0.isWhitespace && !$0.isNewline }.count
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: note.updatedAt)
    }

    private func wordDeclension(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return "слово" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "слова" }
        return "слов"
    }

    private func charDeclension(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return "символ" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "символа" }
        return "символов"
    }

    // MARK: - Auto-save

    private func scheduleAutoSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await saveNote()
            showSaved = true
            try? await Task.sleep(for: .seconds(1.5))
            showSaved = false
        }
    }

    private func saveNote() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        note.title = title
        note.content = htmlContent
        note.synopsis = synopsis
        note.status = chapterStatus
        note.wordCount = computeWordCount()
        note.updatedAt = Date()
        await noteStore.updateNote(note)
    }
}
