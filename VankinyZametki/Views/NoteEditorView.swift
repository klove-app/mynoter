import SwiftUI
import PhotosUI

struct NoteEditorView: View {
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var folderStore: FolderStore
    @EnvironmentObject private var tagStore: TagStore
    @Environment(\.dismiss) private var dismiss

    @State private var note: Note
    @State private var title: String
    @State private var htmlContent: String
    @State private var noteTags: [Tag]
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var isNewNote: Bool
    @State private var isSaving = false
    @State private var saveTask: Task<Void, Never>?
    @State private var showSaved = false
    @State private var showFolderPicker = false
    @State private var showDeleteConfirm = false
    @State private var showVoiceAppend = false
    @State private var pendingVoiceHTML: String?
    @State private var showCreateTag = false
    @State private var newTagName = ""
    @State private var newTagColor: TagColor = .blue
    @State private var showSlashMenu = false
    @State private var showImagePicker = false
    @State private var showTableEditor = false
    @State private var editingTableData: TableData?
    @State private var isUploadingImage = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showDrawingCanvas = false
    @State private var isNormalizing = false
    @State private var showDiagramInput = false
    @State private var diagramDescription = ""
    @State private var isGeneratingDiagram = false
    @State private var showDiagramEditor = false
    @State private var editingDiagramURL = ""
    @State private var editingDiagramMermaid = ""
    @State private var editingDiagramPosition = 0
    @State private var editingDiagramDescription = ""

    var bookContext: BookContext?
    private var isBookChapter: Bool { bookContext != nil }

    @State private var synopsis: String
    @State private var chapterStatus: ChapterStatus

    init(note: Note, bookContext: BookContext? = nil) {
        _note = State(initialValue: note)
        _title = State(initialValue: note.title)
        _htmlContent = State(initialValue: note.content)
        _noteTags = State(initialValue: note.tags)
        _isNewNote = State(initialValue: note.createdAt == note.updatedAt && note.content.isEmpty && note.title.isEmpty)
        _synopsis = State(initialValue: note.synopsis)
        _chapterStatus = State(initialValue: note.status)
        self.bookContext = bookContext
    }

    var body: some View {
        VStack(spacing: 0) {
            breadcrumbBar

            titleField

            if isBookChapter {
                synopsisField
            }

            if note.isVoiceNote, let audioUrl = note.audioUrl {
                AudioPlayerView(urlString: audioUrl)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            RichTextEditor(
                htmlContent: $htmlContent,
                selectedRange: $selectedRange,
                onTextChange: { scheduleAutoSave() },
                onSlashTriggered: { showSlashMenu = true },
                onDiagramFromSelection: { text, type, position in
                    generateDiagramFromSelection(text: text, type: type, insertPosition: position)
                },
                onDiagramClicked: { url, mermaid, position in
                    editingDiagramURL = url
                    editingDiagramMermaid = mermaid
                    editingDiagramPosition = position
                    editingDiagramDescription = ""
                    showDiagramEditor = true
                }
            )

            bottomBar
        }
        .safeAreaInset(edge: .bottom) {
            ZStack(alignment: .top) {
                FormattingToolbar { action in
                    handleFormatAction(action)
                }
                if isUploadingImage {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("Загрузка…")
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .offset(y: -8)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    saveTask?.cancel()
                    Task {
                        await saveNote()
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundStyle(.primary)
            }

            ToolbarItem(placement: .principal) {
                Group {
                    if showSaved {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.bold))
                            Text("Сохранено")
                                .font(.caption)
                        }
                        .foregroundStyle(.green)
                        .transition(.opacity)
                    } else if isSaving {
                        ProgressView()
                            .controlSize(.mini)
                    } else if isBookChapter, let ctx = bookContext {
                        Text("Глава \(ctx.currentIndex + 1) из \(ctx.chapters.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: showSaved)
                .animation(.easeInOut(duration: 0.25), value: isSaving)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if isBookChapter, let ctx = bookContext {
                    HStack(spacing: 4) {
                        Button {
                            navigateToChapter(ctx.currentIndex - 1)
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .disabled(ctx.currentIndex <= 0)

                        Button {
                            navigateToChapter(ctx.currentIndex + 1)
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .disabled(ctx.currentIndex >= ctx.chapters.count - 1)
                    }
                }

                Button { showVoiceAppend = true } label: {
                    Image(systemName: "mic.badge.plus")
                        .font(.system(size: 15))
                }

                Button {
                    normalizeFormatting()
                } label: {
                    if isNormalizing {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 15))
                    }
                }
                .disabled(isNormalizing || htmlContent.isEmpty)

                if !isBookChapter {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15))
                    }
                }

                moreMenu
            }
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerSheet(selectedFolderId: $note.folderId)
        }
        .sheet(isPresented: $showVoiceAppend, onDismiss: {
            guard let html = pendingVoiceHTML else { return }
            pendingVoiceHTML = nil
            findTextView()?.resignFirstResponder()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if htmlContent.isEmpty {
                    htmlContent = html
                } else {
                    htmlContent += "<hr>" + html
                }
                scheduleAutoSave()
            }
        }) {
            NavigationStack {
                VoiceRecorderView { appendedHTML in
                    pendingVoiceHTML = appendedHTML
                }
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCreateTag) {
            NavigationStack {
                Form {
                    Section("Название") {
                        TextField("Имя тега", text: $newTagName)
                    }
                    Section("Цвет") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach(TagColor.allCases, id: \.self) { color in
                                Button {
                                    newTagColor = color
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(color.swiftUIColor)
                                            .frame(width: 36, height: 36)
                                        if newTagColor == color {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .navigationTitle("Новый тег")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { showCreateTag = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Создать") {
                            guard !newTagName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            showCreateTag = false
                            Task {
                                if isNewNote {
                                    saveTask?.cancel()
                                    isSaving = false
                                    await saveNote()
                                }
                                guard let newTag = await tagStore.createTag(
                                    name: newTagName.trimmingCharacters(in: .whitespaces),
                                    color: newTagColor.rawValue
                                ) else { return }

                                noteTags.append(newTag)
                                let updated = await tagStore.addTag(newTag.id, toNote: note.id)
                                if !updated.isEmpty {
                                    noteTags = updated
                                }
                                if let idx = noteStore.notes.firstIndex(where: { $0.id == note.id }) {
                                    noteStore.notes[idx].tags = noteTags
                                }
                            }
                        }
                        .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSlashMenu) {
            iOSSlashCommandSheet { action in
                showSlashMenu = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    handleFormatAction(action)
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let item = newItem else { return }
            selectedPhotoItem = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                await uploadAndInsertImage(data: data, mimeType: "image/jpeg")
            }
        }
        .sheet(isPresented: $showTableEditor) {
            if let data = editingTableData {
                NavigationStack {
                    iOSTableEditorView(
                        tableData: data,
                        onSave: { savedTable in
                            showTableEditor = false
                            let tableHTML = savedTable.toHTML()
                            if htmlContent.isEmpty {
                                htmlContent = tableHTML
                            } else {
                                htmlContent += tableHTML
                            }
                            scheduleAutoSave()
                        },
                        onCancel: { showTableEditor = false }
                    )
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showDrawingCanvas) {
            NavigationStack {
                iOSDrawingView(
                    onSave: { pngData in
                        showDrawingCanvas = false
                        Task {
                            await uploadAndInsertImage(data: pngData, mimeType: "image/png")
                        }
                    },
                    onCancel: { showDrawingCanvas = false }
                )
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showDiagramInput) {
            diagramInputSheet
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showDiagramEditor) {
            diagramEditorSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert("Удалить заметку?", isPresented: $showDeleteConfirm) {
            Button("Удалить", role: .destructive) {
                Task {
                    await noteStore.deleteNote(note)
                    dismiss()
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие нельзя отменить")
        }
        .task {
            if folderStore.folders.isEmpty {
                await folderStore.loadFolders()
            }
        }
        .onChange(of: note.folderId) { _, _ in scheduleAutoSave() }
        .onChange(of: chapterStatus) { _, _ in scheduleAutoSave() }
    }

    // MARK: - Tags (compact, for bottom bar)

    private var noteTagsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
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
                    .onLongPressGesture {
                        Task {
                            let updated = await tagStore.removeTag(tag.id, fromNote: note.id)
                            noteTags = updated
                            if let idx = noteStore.notes.firstIndex(where: { $0.id == note.id }) {
                                noteStore.notes[idx].tags = updated
                            }
                        }
                    }
                }

                Menu {
                    let available = tagStore.tags.filter { tag in
                        !noteTags.contains(where: { $0.id == tag.id })
                    }
                    if !available.isEmpty {
                        Section("Добавить тег") {
                            ForEach(available) { tag in
                                Button {
                                    Task {
                                        if isNewNote {
                                            saveTask?.cancel()
                                            isSaving = false
                                            await saveNote()
                                        }
                                        noteTags.append(tag)
                                        let updated = await tagStore.addTag(tag.id, toNote: note.id)
                                        if !updated.isEmpty {
                                            noteTags = updated
                                        }
                                        if let idx = noteStore.notes.firstIndex(where: { $0.id == note.id }) {
                                            noteStore.notes[idx].tags = noteTags
                                        }
                                    }
                                } label: {
                                    Label(tag.name, systemImage: "tag.fill")
                                }
                            }
                        }
                    }

                    Section {
                        Button {
                            newTagName = ""
                            newTagColor = .blue
                            showCreateTag = true
                        } label: {
                            Label("Создать тег…", systemImage: "plus.circle")
                        }
                    }
                } label: {
                    Image(systemName: "tag")
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                }
            }
        }
    }

    // MARK: - Breadcrumb Bar

    private var breadcrumbBar: some View {
        HStack(spacing: 0) {
            Button { showFolderPicker = true } label: {
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
            }
            .buttonStyle(.plain)

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
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(.separator).opacity(0.08))
    }

    private var statusColor: Color {
        switch chapterStatus {
        case .draft: return .gray
        case .inProgress: return .blue
        case .revised: return .orange
        case .final_: return .green
        }
    }

    // MARK: - Synopsis

    private var synopsisField: some View {
        TextField("Синопсис главы...", text: $synopsis, axis: .vertical)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1...3)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
            .onChange(of: synopsis) { _, _ in scheduleAutoSave() }
    }

    // MARK: - Bottom Bar (tags + status)

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Color(.separator).opacity(0.3).frame(height: 0.5)

            HStack(spacing: 8) {
                noteTagsBar

                Spacer(minLength: 4)

                let wc = computeWordCount()
                Text("\(wc) сл.")
                    .font(.system(size: 11).monospacedDigit())

                Text("·")
                    .font(.system(size: 11))

                Text(note.formattedDate)
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

    private var folderName: String {
        if let fid = note.folderId,
           let folder = folderStore.folders.first(where: { $0.id == fid }) {
            return folder.name
        }
        return "Без папки"
    }

    // MARK: - Title

    private var titleField: some View {
        TextField("Заголовок", text: $title)
            .font(.system(size: 24, weight: .bold))
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, isBookChapter ? 4 : 10)
            .onChange(of: title) { _, _ in scheduleAutoSave() }
    }

    // MARK: - More menu

    private var moreMenu: some View {
        Menu {
            if !isBookChapter {
                Button {
                    showFolderPicker = true
                } label: {
                    Label("Переместить в папку", systemImage: "folder")
                }
            }

            Button {
                Task { await duplicateNote() }
            } label: {
                Label("Дублировать", systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 15))
        }
    }

    // MARK: - Share text

    private var shareText: String {
        let t = title.isEmpty ? "" : title + "\n\n"
        let body = htmlContent
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return t + body
    }

    // MARK: - AI Normalize

    private func normalizeFormatting() {
        guard !htmlContent.isEmpty, !isNormalizing else { return }
        isNormalizing = true
        findTextView()?.resignFirstResponder()
        Task {
            defer { isNormalizing = false }
            do {
                let normalized = try await APIService.shared.normalizeContent(html: htmlContent)
                htmlContent = normalized
                scheduleAutoSave()
            } catch {
                print("Normalize error: \(error)")
            }
        }
    }

    // MARK: - Diagram Generation

    private var diagramInputSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Опишите что нужно изобразить — процесс, схему, структуру")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextEditor(text: $diagramDescription)
                    .font(.body)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator)))

                Text("Примеры: «процесс оформления заказа», «структура БД», «взаимодействие сервисов»")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding()
            .navigationTitle("Создать диаграмму")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        showDiagramInput = false
                        diagramDescription = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        generateDiagram()
                    } label: {
                        if isGeneratingDiagram {
                            ProgressView().controlSize(.mini)
                        } else {
                            Text("Создать")
                        }
                    }
                    .disabled(diagramDescription.trimmingCharacters(in: .whitespaces).isEmpty || isGeneratingDiagram)
                }
            }
        }
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

    private func generateDiagramFromSelection(text: String, type: String, insertPosition: Int) {
        isGeneratingDiagram = true
        Task {
            defer { isGeneratingDiagram = false }
            do {
                let result = try await APIService.shared.generateDiagram(description: text, type: type)
                insertDiagramAtPosition(url: result.url, mermaidCode: result.mermaidCode, position: insertPosition)
            } catch {
                print("Diagram from selection error: \(error)")
            }
        }
    }

    private func insertDiagramAtPosition(url: String, mermaidCode: String, position: Int) {
        guard let tv = findTextView() else { return }
        let storage = tv.textStorage

        let safePos = min(position, storage.length)

        let placeholder = NSTextAttachment()
        placeholder.image = UIImage(systemName: "arrow.triangle.branch")

        let mutable = NSMutableAttributedString(string: "\n")
        let imgStr = NSMutableAttributedString(attachment: placeholder)
        let imgRange = NSRange(location: 0, length: imgStr.length)
        imgStr.addAttribute(vzImageURLKey, value: url, range: imgRange)
        imgStr.addAttribute(vzDiagramMermaidKey, value: mermaidCode, range: imgRange)
        mutable.append(imgStr)
        mutable.append(NSAttributedString(string: "\n"))

        storage.insert(mutable, at: safePos)

        Task { @MainActor in
            guard let imageURL = URL(string: url) else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                guard let image = UIImage(data: data) else { return }

                let maxWidth: CGFloat = UIScreen.main.bounds.width - 48
                let scale = image.size.width > maxWidth ? maxWidth / image.size.width : 1.0
                let size = CGSize(
                    width: image.size.width * scale,
                    height: image.size.height * scale
                )

                let newAttachment = NSTextAttachment()
                newAttachment.image = image
                newAttachment.bounds = CGRect(origin: .zero, size: size)

                let attachRange = NSRange(location: safePos + 1, length: 1)
                guard attachRange.location + attachRange.length <= storage.length else { return }

                let replacement = NSMutableAttributedString(attachment: newAttachment)
                let repRange = NSRange(location: 0, length: replacement.length)
                replacement.addAttribute(vzImageURLKey, value: url, range: repRange)
                replacement.addAttribute(vzDiagramMermaidKey, value: mermaidCode, range: repRange)
                storage.replaceCharacters(in: attachRange, with: replacement)

                let html = HTMLConverter.html(from: tv.attributedText)
                htmlContent = html
                scheduleAutoSave()
            } catch {
                print("Failed to load diagram image: \(error)")
            }
        }

        scheduleAutoSave()
    }

    private var diagramEditorSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AsyncImage(url: URL(string: editingDiagramURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .cornerRadius(10)
                        case .failure:
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("Не удалось загрузить")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                        default:
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 200)
                        }
                    }

                    DisclosureGroup("Mermaid-код") {
                        ScrollView(.horizontal) {
                            Text(editingDiagramMermaid)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(8)
                        }
                        .frame(maxHeight: 120)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Опишите изменения:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $editingDiagramDescription)
                            .font(.body)
                            .frame(height: 80)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator)))
                    }
                }
                .padding()
            }
            .navigationTitle("Редактировать диаграмму")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        showDiagramEditor = false
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        deleteDiagramiOS()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        regenerateDiagramiOS()
                    } label: {
                        if isGeneratingDiagram {
                            ProgressView().controlSize(.mini)
                        } else {
                            Text("Перегенерировать")
                        }
                    }
                    .disabled(editingDiagramDescription.trimmingCharacters(in: .whitespaces).isEmpty || isGeneratingDiagram)
                }
            }
        }
    }

    private func regenerateDiagramiOS() {
        let desc = editingDiagramDescription.trimmingCharacters(in: .whitespaces)
        let prompt = desc.isEmpty ? editingDiagramMermaid : "\(editingDiagramMermaid)\n\nИзменения: \(desc)"
        isGeneratingDiagram = true
        let position = editingDiagramPosition

        Task {
            defer { isGeneratingDiagram = false }
            do {
                let result = try await APIService.shared.generateDiagram(description: prompt, type: "auto")
                editingDiagramURL = result.url
                editingDiagramMermaid = result.mermaidCode
                editingDiagramDescription = ""

                guard let tv = findTextView() else { return }
                let storage = tv.textStorage
                let range = NSRange(location: position, length: 1)
                guard range.location + range.length <= storage.length else { return }

                let (data, _) = try await URLSession.shared.data(from: URL(string: result.url)!)
                guard let image = UIImage(data: data) else { return }

                let maxWidth: CGFloat = UIScreen.main.bounds.width - 48
                let scale = image.size.width > maxWidth ? maxWidth / image.size.width : 1.0
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)

                let attachment = NSTextAttachment()
                attachment.image = image
                attachment.bounds = CGRect(origin: .zero, size: size)

                let replacement = NSMutableAttributedString(attachment: attachment)
                let repRange = NSRange(location: 0, length: replacement.length)
                replacement.addAttribute(vzImageURLKey, value: result.url, range: repRange)
                replacement.addAttribute(vzDiagramMermaidKey, value: result.mermaidCode, range: repRange)
                storage.replaceCharacters(in: range, with: replacement)

                htmlContent = HTMLConverter.html(from: tv.attributedText)
                scheduleAutoSave()
            } catch {
                print("Diagram regeneration error: \(error)")
            }
        }
    }

    private func deleteDiagramiOS() {
        showDiagramEditor = false
        guard let tv = findTextView() else { return }
        let storage = tv.textStorage
        let start = max(0, editingDiagramPosition - 1)
        let length = min(3, storage.length - start)
        guard length > 0 else { return }
        storage.deleteCharacters(in: NSRange(location: start, length: length))
        htmlContent = HTMLConverter.html(from: tv.attributedText)
        scheduleAutoSave()
    }

    private func insertDiagramImage(url: String) {
        findTextView()?.resignFirstResponder()
        let imgTag = "<img src=\"\(url)\" style=\"max-width:100%;height:auto;\">"
        if htmlContent.isEmpty {
            htmlContent = imgTag
        } else {
            htmlContent += "<br>" + imgTag
        }
        scheduleAutoSave()
    }

    // MARK: - Format Actions

    private func handleFormatAction(_ action: TextFormatAction) {
        switch action {
        case .insertImage:
            showImagePicker = true
        case .insertTable:
            editingTableData = TableData.empty(rows: 3, columns: 3)
            showTableEditor = true
        case .insertDrawing:
            showDrawingCanvas = true
        case .insertDiagram:
            showDiagramInput = true
        default:
            guard let tv = findTextView() else { return }
            tv.becomeFirstResponder()
            tv.applyFormat(action)
        }
    }

    private func uploadAndInsertImage(data: Data, mimeType: String) async {
        isUploadingImage = true
        defer { isUploadingImage = false }
        do {
            let result = try await APIService.shared.uploadImage(data: data, mimeType: mimeType)
            let imgTag = "<img src=\"\(result.url)\" style=\"max-width:100%;height:auto;\">"
            if htmlContent.isEmpty {
                htmlContent = imgTag
            } else {
                htmlContent += "<br>" + imgTag
            }
            scheduleAutoSave()
        } catch {
            print("Image upload error: \(error)")
        }
    }

    // MARK: - Duplicate

    private func duplicateNote() async {
        let newNote = await noteStore.createNote(
            title: title.isEmpty ? "" : title + " (копия)",
            content: htmlContent,
            folderId: note.folderId
        )
        if newNote != nil {
            dismiss()
        }
    }

    // MARK: - Navigation

    private func navigateToChapter(_ index: Int) {
        guard let ctx = bookContext,
              index >= 0, index < ctx.chapters.count else { return }
        saveTask?.cancel()
        Task {
            await saveNote()
            dismiss()
        }
    }

    // MARK: - Word Count

    private func computeWordCount() -> Int {
        htmlContent
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .count
    }

    // MARK: - Auto-save

    private func scheduleAutoSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(2))
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

        if isNewNote {
            if let created = await noteStore.createNote(
                title: note.title,
                content: note.content,
                folderId: note.folderId,
                sortOrder: note.sortOrder
            ) {
                note = created
                isNewNote = false
            }
        } else {
            await noteStore.updateNote(note)
        }
    }

    private func findTextView() -> UITextView? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return nil }
        return findTextViewInView(window)
    }

    private func findTextViewInView(_ view: UIView) -> UITextView? {
        if let tv = view as? UITextView, tv.isEditable { return tv }
        for sub in view.subviews {
            if let found = findTextViewInView(sub) { return found }
        }
        return nil
    }
}

// MARK: - Folder Picker

struct FolderPickerSheet: View {
    @EnvironmentObject private var folderStore: FolderStore
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFolderId: UUID?

    var body: some View {
        NavigationStack {
            List {
                Button {
                    selectedFolderId = nil
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "tray")
                            .foregroundStyle(.secondary)
                        Text("Без папки")
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedFolderId == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }

                ForEach(folderStore.regularFolders) { folder in
                    Button {
                        selectedFolderId = folder.id
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                                .foregroundStyle(.secondary)
                            Text(folder.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedFolderId == folder.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Выбрать папку")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
