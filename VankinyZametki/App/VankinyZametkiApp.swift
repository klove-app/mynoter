import SwiftUI

@main
struct VankinyZametkiApp: App {
    @StateObject private var noteStore = NoteStore()
    @StateObject private var folderStore = FolderStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(noteStore)
                .environmentObject(folderStore)
        }
    }
}
