import SwiftUI
import AppKit

struct MacDrawingView: View {
    let onSave: (Data) -> Void
    let onCancel: () -> Void

    @State private var lines: [DrawingLine] = []
    @State private var currentLine: DrawingLine?
    @State private var selectedTool: DrawingTool = .pen
    @State private var selectedColor: Color = .primary
    @State private var lineWidth: CGFloat = 2

    enum DrawingTool: String, CaseIterable {
        case pen = "Карандаш"
        case line = "Линия"
        case rectangle = "Прямоугольник"
        case ellipse = "Эллипс"
        case arrow = "Стрелка"
        case eraser = "Ластик"

        var icon: String {
            switch self {
            case .pen: return "pencil.tip"
            case .line: return "line.diagonal"
            case .rectangle: return "rectangle"
            case .ellipse: return "circle"
            case .arrow: return "arrow.right"
            case .eraser: return "eraser"
            }
        }
    }

    struct DrawingLine {
        var points: [CGPoint]
        var color: Color
        var lineWidth: CGFloat
        var tool: DrawingTool
    }

    private let colors: [Color] = [.primary, .red, .blue, .green, .orange, .purple, .cyan, .yellow]

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            ZStack {
                Color(nsColor: .textBackgroundColor)
                    .ignoresSafeArea()

                Canvas { ctx, size in
                    for line in lines {
                        drawLine(line, in: &ctx)
                    }
                    if let current = currentLine {
                        drawLine(current, in: &ctx)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let point = value.location
                            if currentLine == nil {
                                currentLine = DrawingLine(
                                    points: [point],
                                    color: selectedTool == .eraser ? Color(nsColor: .textBackgroundColor) : selectedColor,
                                    lineWidth: selectedTool == .eraser ? 20 : lineWidth,
                                    tool: selectedTool
                                )
                            } else {
                                currentLine?.points.append(point)
                            }
                        }
                        .onEnded { _ in
                            if let line = currentLine {
                                lines.append(line)
                                currentLine = nil
                            }
                        }
                )
            }

            Divider()

            footer
        }
        .frame(minWidth: 500, idealWidth: 700, minHeight: 400, idealHeight: 550)
        .background(.ultraThinMaterial)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            ForEach(DrawingTool.allCases, id: \.self) { tool in
                Button {
                    selectedTool = tool
                } label: {
                    Image(systemName: tool.icon)
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 28, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(selectedTool == tool ? Color.accentColor.opacity(0.15) : .clear)
                        )
                }
                .buttonStyle(.plain)
                .help(tool.rawValue)
            }

            Divider().frame(height: 16).padding(.horizontal, 4)

            ForEach(colors, id: \.self) { color in
                Button {
                    selectedColor = color
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .strokeBorder(selectedColor == color ? Color.accentColor : .clear, lineWidth: 2)
                                .frame(width: 20, height: 20)
                        )
                }
                .buttonStyle(.plain)
            }

            Divider().frame(height: 16).padding(.horizontal, 4)

            Slider(value: $lineWidth, in: 1...10, step: 0.5)
                .frame(width: 80)

            Text("\(lineWidth, specifier: "%.1f")")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28)

            Spacer()

            Button {
                lines.removeAll()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Очистить")

            Button {
                if !lines.isEmpty {
                    lines.removeLast()
                }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Отменить")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func drawLine(_ line: DrawingLine, in ctx: inout GraphicsContext) {
        guard !line.points.isEmpty else { return }

        let shading = GraphicsContext.Shading.color(line.color)

        switch line.tool {
        case .pen, .eraser:
            var path = Path()
            path.move(to: line.points[0])
            for point in line.points.dropFirst() {
                path.addLine(to: point)
            }
            ctx.stroke(path, with: shading, lineWidth: line.lineWidth)

        case .line:
            if line.points.count >= 2 {
                var path = Path()
                path.move(to: line.points.first!)
                path.addLine(to: line.points.last!)
                ctx.stroke(path, with: shading, lineWidth: line.lineWidth)
            }

        case .rectangle:
            if line.points.count >= 2 {
                let rect = CGRect(
                    x: min(line.points.first!.x, line.points.last!.x),
                    y: min(line.points.first!.y, line.points.last!.y),
                    width: abs(line.points.last!.x - line.points.first!.x),
                    height: abs(line.points.last!.y - line.points.first!.y)
                )
                ctx.stroke(Path(rect), with: shading, lineWidth: line.lineWidth)
            }

        case .ellipse:
            if line.points.count >= 2 {
                let rect = CGRect(
                    x: min(line.points.first!.x, line.points.last!.x),
                    y: min(line.points.first!.y, line.points.last!.y),
                    width: abs(line.points.last!.x - line.points.first!.x),
                    height: abs(line.points.last!.y - line.points.first!.y)
                )
                ctx.stroke(Path(ellipseIn: rect), with: shading, lineWidth: line.lineWidth)
            }

        case .arrow:
            if line.points.count >= 2 {
                let start = line.points.first!
                let end = line.points.last!
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)

                let angle = atan2(end.y - start.y, end.x - start.x)
                let headLength: CGFloat = 14
                let headAngle: CGFloat = .pi / 6
                path.move(to: end)
                path.addLine(to: CGPoint(
                    x: end.x - headLength * cos(angle - headAngle),
                    y: end.y - headLength * sin(angle - headAngle)
                ))
                path.move(to: end)
                path.addLine(to: CGPoint(
                    x: end.x - headLength * cos(angle + headAngle),
                    y: end.y - headLength * sin(angle + headAngle)
                ))

                ctx.stroke(path, with: shading, lineWidth: line.lineWidth)
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Отмена") { onCancel() }
                .keyboardShortcut(.cancelAction)
            Button("Сохранить как картинку") {
                exportAsPNG()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @MainActor
    private func exportAsPNG() {
        let size = CGSize(width: 800, height: 600)
        let renderer = ImageRenderer(content:
            Canvas { ctx, sz in
                ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .color(.white))
                for line in lines {
                    drawLine(line, in: &ctx)
                }
            }
            .frame(width: size.width, height: size.height)
        )
        renderer.scale = 2.0

        if let cgImage = renderer.cgImage {
            let nsImage = NSImage(cgImage: cgImage, size: size)
            if let tiffData = nsImage.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiffData),
               let pngData = rep.representation(using: .png, properties: [:]) {
                onSave(pngData)
                return
            }
        }
        onCancel()
    }
}
