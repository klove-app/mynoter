import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .notes

    enum Tab {
        case notes, folders, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                NoteListView()
            }
            .tabItem {
                Label("Заметки", systemImage: "note.text")
            }
            .tag(Tab.notes)

            NavigationStack {
                FolderListView()
            }
            .tabItem {
                Label("Папки", systemImage: "folder")
            }
            .tag(Tab.folders)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Настройки", systemImage: "gearshape")
            }
            .tag(Tab.settings)
        }
        .tint(.accentColor)
    }
}
