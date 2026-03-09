import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 0) {
                    tabContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    HStack(spacing: 0) {
                        tabBtn("doc.text", "doc.text.fill", "Заметки", 0)
                        tabBtn("folder", "folder.fill", "Папки", 1)
                        tabBtn("gearshape", "gearshape.fill", "Настройки", 2)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 2)
                    .background(Color(.systemBackground))
                }
            }
    }

    @ViewBuilder
    private var tabContent: some View {
        ZStack {
            NoteListView()
                .opacity(selectedTab == 0 ? 1 : 0)
                .allowsHitTesting(selectedTab == 0)

            FolderListView()
                .opacity(selectedTab == 1 ? 1 : 0)
                .allowsHitTesting(selectedTab == 1)

            SettingsView()
                .opacity(selectedTab == 2 ? 1 : 0)
                .allowsHitTesting(selectedTab == 2)
        }
    }

    private func tabBtn(_ icon: String, _ active: String, _ label: String, _ tag: Int) -> some View {
        Button {
            selectedTab = tag
        } label: {
            VStack(spacing: 2) {
                Image(systemName: selectedTab == tag ? active : icon)
                    .font(.system(size: 18))
                    .frame(height: 22)
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundStyle(selectedTab == tag ? Color.accentColor : .secondary)
            .frame(maxWidth: .infinity)
        }
    }
}
