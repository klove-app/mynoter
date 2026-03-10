import SwiftUI

struct MacNewTagView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedColor: TagColor = .blue

    var onCreate: (String, TagColor) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Новый тег")
                .font(.headline)

            TextField("Название тега", text: $name)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Цвет")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach(TagColor.allCases, id: \.self) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(color.swiftUIColor)
                                    .frame(width: 28, height: 28)
                                if selectedColor == color {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .help(color.displayName)
                    }
                }
            }

            HStack(spacing: 8) {
                if !name.isEmpty {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(selectedColor.swiftUIColor)
                            .frame(width: 8, height: 8)
                        Text(name)
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(selectedColor.swiftUIColor.opacity(0.15), in: Capsule())
                }
                Spacer()
            }

            HStack {
                Button("Отмена") { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Создать") {
                    guard !name.isEmpty else { return }
                    onCreate(name, selectedColor)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}
