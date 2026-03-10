import SwiftUI
import PencilKit

struct iOSDrawingView: View {
    let onSave: (Data) -> Void
    let onCancel: () -> Void

    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()

    var body: some View {
        VStack(spacing: 0) {
            CanvasRepresentable(canvasView: $canvasView, toolPicker: $toolPicker)
                .ignoresSafeArea(.keyboard)

            Divider()

            HStack {
                Button {
                    canvasView.drawing = PKDrawing()
                } label: {
                    Label("Очистить", systemImage: "trash")
                        .font(.caption)
                }

                Spacer()

                Button("Отмена") { onCancel() }

                Button("Сохранить") {
                    let image = canvasView.drawing.image(
                        from: canvasView.bounds,
                        scale: UIScreen.main.scale
                    )
                    if let data = image.pngData() {
                        onSave(data)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
        }
        .navigationTitle("Рисунок")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .systemBackground
        canvasView.isOpaque = true

        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
