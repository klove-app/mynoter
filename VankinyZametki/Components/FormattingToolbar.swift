import SwiftUI

struct FormattingToolbar: View {
    let onAction: (TextFormatAction) -> Void
    @State private var showHeadingPicker = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                formatButton(icon: "bold", action: .bold)
                formatButton(icon: "italic", action: .italic)
                formatButton(icon: "underline", action: .underline)
                formatButton(icon: "strikethrough", action: .strikethrough)

                Divider()
                    .frame(height: 24)

                Button {
                    showHeadingPicker.toggle()
                } label: {
                    Image(systemName: "textformat.size")
                        .frame(width: 36, height: 36)
                }
                .popover(isPresented: $showHeadingPicker) {
                    VStack(spacing: 0) {
                        headingButton("Заголовок 1", level: 1)
                        Divider()
                        headingButton("Заголовок 2", level: 2)
                        Divider()
                        headingButton("Заголовок 3", level: 3)
                    }
                    .frame(width: 180)
                    .presentationCompactAdaptation(.popover)
                }

                Divider()
                    .frame(height: 24)

                formatButton(icon: "list.bullet", action: .bulletList)
                formatButton(icon: "list.number", action: .numberedList)

                Divider()
                    .frame(height: 24)

                highlightButton
                formatButton(icon: "chevron.left.forwardslash.chevron.right", action: .code)

                Divider()
                    .frame(height: 24)

                Button {
                    onAction(.clearFormatting)
                } label: {
                    Image(systemName: "textformat")
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .offset(x: 10, y: -8)
                        )
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 44)
        .background(.ultraThinMaterial)
    }

    private func formatButton(icon: String, action: TextFormatAction) -> some View {
        Button {
            onAction(action)
        } label: {
            Image(systemName: icon)
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
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private var highlightButton: some View {
        Button {
            onAction(.highlight)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.yellow.opacity(0.4))
                    .frame(width: 24, height: 20)
                Text("A")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }
}
