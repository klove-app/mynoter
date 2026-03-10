import SwiftUI

struct FormattingToolbar: View {
    let onAction: (TextFormatAction) -> Void
    @State private var showHeadingPicker = false
    @State private var showHighlightPicker = false
    @State private var showFontPicker = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                fontPickerButton

                pill

                Group {
                    formatButton(icon: "bold", action: .bold)
                    formatButton(icon: "italic", action: .italic)
                    formatButton(icon: "underline", action: .underline)
                    formatButton(icon: "strikethrough", action: .strikethrough)
                }

                pill

                highlightButton

                pill

                Button {
                    showHeadingPicker.toggle()
                } label: {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 14))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showHeadingPicker) {
                    VStack(spacing: 0) {
                        headingButton("Заголовок 1", level: 1)
                        Divider()
                        headingButton("Заголовок 2", level: 2)
                        Divider()
                        headingButton("Заголовок 3", level: 3)
                    }
                    .frame(width: 200)
                    .presentationCompactAdaptation(.popover)
                }

                pill

                Group {
                    formatButton(icon: "list.bullet", action: .bulletList)
                    formatButton(icon: "list.number", action: .numberedList)
                }

                pill

                Group {
                    formatButton(icon: "text.quote", action: .blockquote)
                    formatButton(icon: "chevron.left.forwardslash.chevron.right", action: .code)
                    formatButton(icon: "minus", action: .separator)
                }

                pill

                Group {
                    formatButton(icon: "photo", action: .insertImage)
                    formatButton(icon: "tablecells", action: .insertTable)
                    formatButton(icon: "arrow.triangle.branch", action: .insertDiagram)
                }

                pill

                Group {
                    formatButton(icon: "paintbrush", action: .cleanPaste)
                    formatButton(icon: "eraser", action: .clearFormatting)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 42)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.04), radius: 4, y: -1)
        )
    }

    // MARK: - Highlight Color Picker

    private var highlightButton: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            showHighlightPicker.toggle()
        } label: {
            ZStack {
                HStack(spacing: 1.5) {
                    ForEach([Color.yellow, .green, .blue, .pink, .orange, .purple], id: \.self) { c in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(c.opacity(0.6))
                            .frame(width: 3, height: 14)
                    }
                }
                .frame(width: 26, height: 18)
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showHighlightPicker) {
            highlightPickerContent
                .presentationCompactAdaptation(.popover)
        }
    }

    private var highlightPickerContent: some View {
        VStack(spacing: 0) {
            Text("Выделить цветом")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 12)
                .padding(.bottom, 8)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(52), spacing: 8), count: 3), spacing: 10) {
                ForEach(iOSHighlightColor.allCases, id: \.self) { color in
                    Button {
                        showHighlightPicker = false
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        onAction(.highlight(color))
                    } label: {
                        VStack(spacing: 3) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(color.swiftUIColor.opacity(0.4))
                                    .frame(width: 48, height: 32)
                                Text("Аа")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.primary.opacity(0.7))
                            }
                            Text(color.displayName)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)

            Divider()
                .padding(.top, 10)

            Button {
                showHighlightPicker = false
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                onAction(.removeHighlight)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("Убрать выделение")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 200)
    }

    // MARK: - Font Picker

    private var fontPickerButton: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            showFontPicker.toggle()
        } label: {
            Text("Aa")
                .font(.system(size: 13, weight: .medium, design: .serif))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showFontPicker) {
            VStack(spacing: 0) {
                ForEach(iOSNoteFont.allCases, id: \.self) { noteFont in
                    Button {
                        showFontPicker = false
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        onAction(.setFont(noteFont))
                    } label: {
                        HStack {
                            Text("Пример")
                                .font(Font(noteFont.uiFont(size: 16)))
                            Spacer()
                            Text(noteFont.displayName)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if noteFont != iOSNoteFont.allCases.last { Divider() }
                }
            }
            .frame(width: 220)
            .presentationCompactAdaptation(.popover)
        }
    }

    // MARK: - Common

    private var pill: some View {
        Capsule()
            .fill(.quaternary)
            .frame(width: 1, height: 16)
            .padding(.horizontal, 3)
    }

    private func formatButton(icon: String, action: TextFormatAction) -> some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onAction(action)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func headingButton(_ title: String, level: Int) -> some View {
        Button {
            showHeadingPicker = false
            onAction(.heading(level))
        } label: {
            Text(title)
                .font(.system(size: CGFloat(22 - level * 2), weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
