import SwiftUI

struct MacFormattingToolbar: View {
    var onAction: (MacFormatAction) -> Void

    @State private var showHighlightPicker = false
    @State private var showFontPicker = false

    var body: some View {
        HStack(spacing: 2) {
            fontPickerButton

            toolbarDivider

            Group {
                formatButton("bold", tooltip: "Жирный (⌘B)") { onAction(.bold) }
                formatButton("italic", tooltip: "Курсив (⌘I)") { onAction(.italic) }
                formatButton("underline", tooltip: "Подчёркнутый (⌘U)") { onAction(.underline) }
                formatButton("strikethrough", tooltip: "Зачёркнутый") { onAction(.strikethrough) }
            }

            toolbarDivider

            highlightButton

            toolbarDivider

            Group {
                headingButton(1)
                headingButton(2)
                headingButton(3)
            }

            toolbarDivider

            Group {
                formatButton("list.bullet", tooltip: "Маркированный список") { onAction(.bulletList) }
                formatButton("list.number", tooltip: "Нумерованный список") { onAction(.numberedList) }
            }

            toolbarDivider

            Group {
                formatButton("text.quote", tooltip: "Цитата") { onAction(.blockquote) }
                formatButton("chevron.left.forwardslash.chevron.right", tooltip: "Код") { onAction(.codeBlock) }
            }

            toolbarDivider

            Group {
                formatButton("photo", tooltip: "Вставить изображение") { onAction(.insertImage) }
                formatButton("tablecells", tooltip: "Вставить таблицу") { onAction(.insertTable) }
                formatButton("arrow.triangle.branch", tooltip: "Создать диаграмму") { onAction(.insertDiagram) }
            }

            toolbarDivider

            Group {
                formatButton("minus", tooltip: "Разделитель") { onAction(.separator) }
                formatButton("paintbrush", tooltip: "Упростить форматирование") { onAction(.cleanPaste) }
                formatButton("eraser", tooltip: "Очистить всё форматирование") { onAction(.clearFormatting) }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(Color.clear)
        .overlay(alignment: .top) {
            Color.ds.separator.opacity(0.2).frame(height: 0.5)
        }
    }

    // MARK: - Font Picker

    private var fontPickerButton: some View {
        Button {
            showFontPicker.toggle()
        } label: {
            ZStack {
                HStack(spacing: 2) {
                    Text("Aa")
                        .font(.system(size: 11, weight: .medium, design: .serif))
                    Triangle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 5, height: 3)
                }
                .frame(width: 34, height: 22)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(ToolbarHoverButtonStyle())
        .help("Шрифт")
        .popover(isPresented: $showFontPicker, arrowEdge: .bottom) {
            fontPickerContent
        }
    }

    private var fontPickerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Шрифт")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            ForEach(NoteFont.allCases, id: \.self) { noteFont in
                Button {
                    showFontPicker = false
                    onAction(.setFont(noteFont))
                } label: {
                    HStack {
                        Text("Пример текста")
                            .font(.init(noteFont.nsFont(size: 14)))
                        Spacer()
                        Text(noteFont.displayName)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(FontRowStyle())
            }
        }
        .frame(width: 220)
        .padding(.bottom, 6)
    }

    // MARK: - Highlight Color Picker

    private var highlightButton: some View {
        Button {
            showHighlightPicker.toggle()
        } label: {
            ZStack {
                Image(systemName: "highlighter")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 26, height: 22)
                    .contentShape(Rectangle())

                Triangle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 5, height: 3)
                    .offset(x: 10, y: 8)
            }
        }
        .buttonStyle(ToolbarHoverButtonStyle())
        .help("Выделение цветом")
        .popover(isPresented: $showHighlightPicker, arrowEdge: .bottom) {
            highlightPickerContent
        }
    }

    private var highlightPickerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Выделить цветом")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 8), count: 3), spacing: 8) {
                ForEach(HighlightColor.allCases, id: \.self) { color in
                    highlightColorCell(color)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            Button {
                showHighlightPicker = false
                onAction(.removeHighlight)
            } label: {
                HStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                            .frame(width: 28, height: 28)
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text("Убрать")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 168)
    }

    private func highlightColorCell(_ color: HighlightColor) -> some View {
        Button {
            showHighlightPicker = false
            onAction(.highlight(color))
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.swiftUIColor.opacity(0.35))
                        .frame(width: 40, height: 28)
                    Text("Аа")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.7))
                }
                Text(color.shortName)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ColorCellButtonStyle())
    }

    // MARK: - Heading Buttons

    private func headingButton(_ level: Int) -> some View {
        Button { onAction(.heading(level)) } label: {
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text("H")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Text("\(level)")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
            }
            .frame(width: 26, height: 22)
            .background(.quaternary.opacity(0.01), in: RoundedRectangle(cornerRadius: 4))
            .contentShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(ToolbarHoverButtonStyle())
        .help("Заголовок \(level)")
    }

    // MARK: - Button Styles

    private func formatButton(_ systemName: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 26, height: 22)
                .background(.quaternary.opacity(0.01), in: RoundedRectangle(cornerRadius: 4))
                .contentShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(ToolbarHoverButtonStyle())
        .help(tooltip)
    }

    private var toolbarDivider: some View {
        Divider()
            .frame(height: 14)
            .padding(.horizontal, 3)
    }
}

// MARK: - Supporting Types

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}

struct ToolbarHoverButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.12) : isHovered ? Color.primary.opacity(0.07) : .clear)
            )
            .onHover { isHovered = $0 }
            .animation(.spring(duration: 0.2, bounce: 0.3), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

struct ColorCellButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.primary.opacity(0.06) : .clear)
                    .padding(-2)
            )
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct FontRowStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.primary.opacity(0.06) : .clear)
                    .padding(.horizontal, 4)
            )
            .onHover { isHovered = $0 }
    }
}

// MARK: - HighlightColor Extension

extension HighlightColor {
    var shortName: String {
        switch self {
        case .yellow:  return "Жёлт."
        case .green:   return "Зелён."
        case .blue:    return "Голуб."
        case .pink:    return "Розов."
        case .orange:  return "Оранж."
        case .purple:  return "Фиол."
        }
    }
}
