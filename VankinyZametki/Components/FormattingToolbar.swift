import SwiftUI

struct FormattingToolbar: View {
    let onAction: (TextFormatAction) -> Void
    @State private var showHeadingPicker = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                Group {
                    formatButton(icon: "bold", action: .bold)
                    formatButton(icon: "italic", action: .italic)
                    formatButton(icon: "underline", action: .underline)
                    formatButton(icon: "strikethrough", action: .strikethrough)
                }

                pill

                Button {
                    showHeadingPicker.toggle()
                } label: {
                    Image(systemName: "textformat.size")
                        .frame(width: 40, height: 40)
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
                    highlightButton
                    formatButton(icon: "chevron.left.forwardslash.chevron.right", action: .code)
                }

                pill

                Button {
                    onAction(.clearFormatting)
                } label: {
                    Image(systemName: "eraser")
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 48)
        .background(
            Rectangle()
                .fill(.bar)
                .shadow(color: .black.opacity(0.06), radius: 4, y: -2)
        )
    }

    private var pill: some View {
        Capsule()
            .fill(.quaternary)
            .frame(width: 1, height: 20)
            .padding(.horizontal, 4)
    }

    private func formatButton(icon: String, action: TextFormatAction) -> some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onAction(action)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15))
                .frame(width: 40, height: 40)
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

    private var highlightButton: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onAction(.highlight)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.yellow.opacity(0.35))
                    .frame(width: 22, height: 18)
                Text("A")
                    .font(.system(size: 13, weight: .semibold))
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
    }
}
