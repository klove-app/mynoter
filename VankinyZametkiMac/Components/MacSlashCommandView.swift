import SwiftUI

struct SlashCommandItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let category: SlashCategory
    let action: SlashAction

    enum SlashCategory: String {
        case tags = "Теги"
        case blocks = "Блоки"
        case lists = "Списки"
        case insert = "Вставка"
    }

    enum SlashAction {
        case insertTag(Tag)
        case createTag
        case heading(Int)
        case bulletList
        case numberedList
        case blockquote
        case codeBlock
        case separator
        case footnote
        case image
        case table
        case drawing
        case diagram
    }

    var iconColor: Color {
        switch action {
        case .insertTag(let tag): return tag.swiftUIColor
        case .createTag: return .purple
        case .heading: return .blue
        case .bulletList, .numberedList: return .green
        case .blockquote: return .orange
        case .codeBlock: return .pink
        case .separator: return .gray
        case .footnote: return .indigo
        case .image: return .teal
        case .table: return .cyan
        case .drawing: return .mint
        case .diagram: return .purple
        }
    }
}

struct MacSlashCommandView: View {
    let items: [SlashCommandItem]
    let searchText: String
    let selectedIndex: Int
    let onSelect: (SlashCommandItem) -> Void

    private var filtered: [SlashCommandItem] {
        guard !searchText.isEmpty else { return items }
        let q = searchText.lowercased()
        return items.filter {
            $0.title.lowercased().contains(q) ||
            $0.subtitle.lowercased().contains(q) ||
            $0.category.rawValue.lowercased().contains(q)
        }
    }

    private static let categoryOrder: [SlashCommandItem.SlashCategory] = [.tags, .blocks, .lists, .insert]

    private var grouped: [(String, [IndexedItem])] {
        var result: [(String, [IndexedItem])] = []
        var globalIdx = 0
        for cat in Self.categoryOrder {
            let catItems = filtered.filter { $0.category == cat }
            guard !catItems.isEmpty else { continue }
            let indexed = catItems.map { item -> IndexedItem in
                let i = IndexedItem(index: globalIdx, item: item)
                globalIdx += 1
                return i
            }
            result.append((cat.rawValue, indexed))
        }
        return result
    }

    struct IndexedItem: Identifiable {
        let index: Int
        let item: SlashCommandItem
        var id: UUID { item.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchHeader

            if filtered.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(grouped.enumerated()), id: \.element.0) { groupIdx, group in
                                let (category, indexedItems) = group

                                if groupIdx > 0 {
                                    Divider()
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                }

                                Text(category.uppercased())
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.quaternary)
                                    .kerning(0.8)
                                    .padding(.horizontal, 14)
                                    .padding(.top, groupIdx == 0 ? 4 : 2)
                                    .padding(.bottom, 2)

                                ForEach(indexedItems) { entry in
                                    slashRow(entry.item, isSelected: entry.index == selectedIndex)
                                        .id(entry.index)
                                        .onTapGesture { onSelect(entry.item) }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: selectedIndex) { _, newIdx in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(newIdx, anchor: .center)
                        }
                    }
                }
            }

            footer
        }
        .frame(width: 280)
        .frame(maxHeight: min(CGFloat(filtered.count) * 42 + 70, 360))
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var searchHeader: some View {
        if !searchText.isEmpty {
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.quaternary)
                Text("/\(searchText)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(filtered.count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.quaternary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.05)))
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            Divider()
                .padding(.horizontal, 10)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 20))
                .foregroundStyle(.quaternary)
            Text("Ничего не найдено")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            HStack(spacing: 3) {
                keyHint("↑↓")
                Text("навигация")
            }
            HStack(spacing: 3) {
                keyHint("↵")
                Text("выбрать")
            }
            HStack(spacing: 3) {
                keyHint("esc")
                Text("закрыть")
            }
            Spacer()
        }
        .font(.system(size: 9.5))
        .foregroundStyle(.quaternary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.02))
    }

    private func keyHint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
    }

    private func slashRow(_ item: SlashCommandItem, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            iconView(for: item, isSelected: isSelected)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.85))
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? selectionGradient(for: item) : AnyShapeStyle(.clear))
                .padding(.horizontal, 6)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func iconView(for item: SlashCommandItem, isSelected: Bool) -> some View {
        if case .insertTag(let tag) = item.action {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(tag.swiftUIColor.opacity(isSelected ? 0.2 : 0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: "tag.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(tag.swiftUIColor)
            }
        } else if case .createTag = item.action {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.purple.opacity(isSelected ? 0.2 : 0.1))
                    .frame(width: 30, height: 30)
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.purple)
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(item.iconColor.opacity(isSelected ? 0.18 : 0.08))
                    .frame(width: 30, height: 30)
                Image(systemName: item.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(item.iconColor.opacity(isSelected ? 1 : 0.7))
            }
        }
    }

    private func selectionGradient(for item: SlashCommandItem) -> AnyShapeStyle {
        AnyShapeStyle(
            LinearGradient(
                colors: [
                    item.iconColor.opacity(0.08),
                    item.iconColor.opacity(0.04)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    var filteredCount: Int { filtered.count }
}
