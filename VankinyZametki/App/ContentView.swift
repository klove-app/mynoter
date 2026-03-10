import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var tagStore: TagStore
    @State private var selectedTab = 0

    var body: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
            .task { await tagStore.loadTags() }
            .overlay {
                VStack(spacing: 0) {
                    tabContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    tabBar
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
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabBtn("doc.text", "doc.text.fill", "Заметки", 0)
            tabBtn("folder", "folder.fill", "Папки", 1)
            tabBtn("gearshape", "gearshape.fill", "Настройки", 2)
        }
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, 2)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private func tabBtn(_ icon: String, _ active: String, _ label: String, _ tag: Int) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                selectedTab = tag
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: selectedTab == tag ? active : icon)
                    .font(.system(size: 20, weight: selectedTab == tag ? .semibold : .regular))
                    .symbolEffect(.bounce, value: selectedTab == tag)
                    .frame(height: 24)
                Text(label)
                    .font(.system(size: 10, weight: selectedTab == tag ? .medium : .regular))
            }
            .foregroundStyle(selectedTab == tag ? Color.accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
