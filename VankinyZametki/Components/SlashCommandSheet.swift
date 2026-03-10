import SwiftUI

struct iOSSlashCommandSheet: View {
    let onSelect: (TextFormatAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private struct CommandItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
        let color: Color
        let category: String
        let action: TextFormatAction
    }

    private var allCommands: [CommandItem] {
        [
            CommandItem(icon: "textformat.size.larger", title: "Заголовок 1", subtitle: "Большой заголовок", color: .blue, category: "Блоки", action: .heading(1)),
            CommandItem(icon: "textformat.size", title: "Заголовок 2", subtitle: "Средний заголовок", color: .blue, category: "Блоки", action: .heading(2)),
            CommandItem(icon: "textformat.size.smaller", title: "Заголовок 3", subtitle: "Маленький заголовок", color: .blue, category: "Блоки", action: .heading(3)),
            CommandItem(icon: "text.quote", title: "Цитата", subtitle: "Блок цитаты", color: .orange, category: "Блоки", action: .blockquote),
            CommandItem(icon: "chevron.left.forwardslash.chevron.right", title: "Код", subtitle: "Моноширинный блок", color: .pink, category: "Блоки", action: .code),
            CommandItem(icon: "list.bullet", title: "Маркерный список", subtitle: "Список с точками", color: .green, category: "Списки", action: .bulletList),
            CommandItem(icon: "list.number", title: "Нумерованный список", subtitle: "Список с цифрами", color: .green, category: "Списки", action: .numberedList),
            CommandItem(icon: "minus", title: "Разделитель", subtitle: "Горизонтальная линия", color: .gray, category: "Вставка", action: .separator),
            CommandItem(icon: "photo", title: "Картинка", subtitle: "Вставить изображение", color: .teal, category: "Вставка", action: .insertImage),
            CommandItem(icon: "tablecells", title: "Таблица", subtitle: "Создать таблицу", color: .cyan, category: "Вставка", action: .insertTable),
            CommandItem(icon: "scribble.variable", title: "Рисунок", subtitle: "Нарисовать схему", color: .mint, category: "Вставка", action: .insertDrawing),
            CommandItem(icon: "arrow.triangle.branch", title: "Диаграмма", subtitle: "Сгенерировать из описания", color: .purple, category: "Вставка", action: .insertDiagram),
        ]
    }

    private var filtered: [CommandItem] {
        guard !searchText.isEmpty else { return allCommands }
        let q = searchText.lowercased()
        return allCommands.filter {
            $0.title.lowercased().contains(q) ||
            $0.subtitle.lowercased().contains(q)
        }
    }

    private var grouped: [(String, [CommandItem])] {
        let categoryOrder = ["Блоки", "Списки", "Вставка"]
        var result: [(String, [CommandItem])] = []
        for cat in categoryOrder {
            let items = filtered.filter { $0.category == cat }
            if !items.isEmpty {
                result.append((cat, items))
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                    TextField("Поиск команды…", text: $searchText)
                        .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if filtered.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "text.magnifyingglass")
                            .font(.system(size: 28))
                            .foregroundStyle(.quaternary)
                        Text("Ничего не найдено")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(grouped, id: \.0) { category, items in
                            Section {
                                ForEach(items) { item in
                                    Button {
                                        let impact = UIImpactFeedbackGenerator(style: .light)
                                        impact.impactOccurred()
                                        onSelect(item.action)
                                    } label: {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(item.color.opacity(0.12))
                                                    .frame(width: 36, height: 36)
                                                Image(systemName: item.icon)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundStyle(item.color)
                                            }

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.title)
                                                    .font(.body.weight(.medium))
                                                    .foregroundStyle(.primary)
                                                Text(item.subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            } header: {
                                Text(category.uppercased())
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .kerning(0.5)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Команды")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}
