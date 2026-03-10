import SwiftUI

@main
struct VankinyZametkiMacApp: App {
    @StateObject private var noteStore = NoteStore()
    @StateObject private var folderStore = FolderStore()
    @StateObject private var tagStore = TagStore()

    var body: some Scene {
        WindowGroup {
            MacContentView()
                .environmentObject(noteStore)
                .environmentObject(folderStore)
                .environmentObject(tagStore)
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Новая заметка") {
                    NotificationCenter.default.post(name: .newNote, object: nil)
                }
                .keyboardShortcut("n")

                Button("Голосовая заметка") {
                    NotificationCenter.default.post(name: .newVoiceNote, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(after: .toolbar) {
                Button("Режим фокуса") {
                    NotificationCenter.default.post(name: .toggleDistractionFree, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }

            CommandMenu("Формат") {
                Button("Жирный") {
                    NotificationCenter.default.post(name: .formatBold, object: nil)
                }
                .keyboardShortcut("b")

                Button("Курсив") {
                    NotificationCenter.default.post(name: .formatItalic, object: nil)
                }
                .keyboardShortcut("i")

                Button("Подчёркнутый") {
                    NotificationCenter.default.post(name: .formatUnderline, object: nil)
                }
                .keyboardShortcut("u")

                Divider()

                Button("Сохранить") {
                    NotificationCenter.default.post(name: .saveNote, object: nil)
                }
                .keyboardShortcut("s")
            }
        }
    }
}

extension Notification.Name {
    static let newNote = Notification.Name("newNote")
    static let newVoiceNote = Notification.Name("newVoiceNote")
    static let toggleDistractionFree = Notification.Name("toggleDistractionFree")
    static let formatBold = Notification.Name("formatBold")
    static let formatItalic = Notification.Name("formatItalic")
    static let formatUnderline = Notification.Name("formatUnderline")
    static let saveNote = Notification.Name("saveNote")
}
