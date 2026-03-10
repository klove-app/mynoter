import SwiftUI

struct MacTableEditorView: View {
    @State var tableData: TableData
    let onSave: (TableData) -> Void
    let onCancel: () -> Void

    @State private var editingCell: CellID?
    @State private var editText = ""

    struct CellID: Equatable {
        let row: Int
        let col: Int
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tableContent
            Divider()
            footer
        }
        .frame(width: 620, height: 440)
    }

    private var header: some View {
        HStack {
            Image(systemName: "tablecells")
                .foregroundStyle(.teal)
            Text("Редактор таблицы")
                .font(.headline)
            Spacer()
            Text("\(tableData.rowCount) × \(tableData.columnCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.secondary.opacity(0.1)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var tableContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<tableData.rowCount, id: \.self) { row in
                    HStack(spacing: 0) {
                        Text("\(row + 1)")
                            .font(.system(size: 9, weight: .medium).monospacedDigit())
                            .foregroundStyle(.quaternary)
                            .frame(width: 22)

                        ForEach(0..<tableData.columnCount, id: \.self) { col in
                            cellView(row: row, col: col)
                        }
                    }
                }

                HStack(spacing: 0) {
                    Color.clear.frame(width: 22)
                    Button {
                        tableData.addRow()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .medium))
                            Text("Добавить строку")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
    }

    private func cellView(row: Int, col: Int) -> some View {
        let cell = tableData.rows[row][col]
        let isEditing = editingCell == CellID(row: row, col: col)

        return VStack(spacing: 0) {
            if isEditing {
                TextField("", text: $editText, onCommit: {
                    commitEdit(row: row, col: col)
                })
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: cell.isBold ? .bold : .regular))
                .padding(6)
                .frame(width: 130, height: 34)
                .background(cellBg(cell: cell, row: row))
                .border(Color.accentColor.opacity(0.4), width: 1)
            } else {
                Text(cell.text.isEmpty ? " " : cell.text)
                    .font(.system(size: 13, weight: cell.isBold || cell.isHeader ? .bold : .regular))
                    .lineLimit(2)
                    .frame(width: 130, height: 34, alignment: cellAlignment(cell.alignment))
                    .padding(.horizontal, 6)
                    .background(cellBg(cell: cell, row: row))
                    .border(Color.secondary.opacity(0.15), width: 0.5)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let prev = editingCell {
                            commitEdit(row: prev.row, col: prev.col)
                        }
                        editingCell = CellID(row: row, col: col)
                        editText = cell.text
                    }
            }
        }
        .contextMenu { cellContextMenu(row: row, col: col) }
    }

    private func cellBg(cell: TableData.CellData, row: Int) -> Color {
        if cell.isHeader { return Color.secondary.opacity(0.08) }
        return row % 2 == 0 ? Color.clear : Color.secondary.opacity(0.03)
    }

    private func cellAlignment(_ a: TableData.CellAlignment) -> Alignment {
        switch a {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }

    private func commitEdit(row: Int, col: Int) {
        guard row < tableData.rows.count, col < tableData.rows[row].count else { return }
        tableData.rows[row][col].text = editText
        editingCell = nil
        editText = ""
    }

    @ViewBuilder
    private func cellContextMenu(row: Int, col: Int) -> some View {
        Button("Строку выше") { tableData.addRow(at: row) }
        Button("Строку ниже") { tableData.addRow(at: row + 1) }
        Divider()
        Button("Столбец слева") { tableData.addColumn(at: col) }
        Button("Столбец справа") { tableData.addColumn(at: col + 1) }
        Divider()
        Menu("Выравнивание") {
            Button("Лево") { tableData.rows[row][col].alignment = .left }
            Button("Центр") { tableData.rows[row][col].alignment = .center }
            Button("Право") { tableData.rows[row][col].alignment = .right }
        }
        Button(tableData.rows[row][col].isBold ? "Убрать жирный" : "Жирный") {
            tableData.rows[row][col].isBold.toggle()
        }
        Button(tableData.rows[row][col].isHeader ? "Обычная ячейка" : "Заголовок") {
            tableData.rows[row][col].isHeader.toggle()
            tableData.rows[row][col].isBold = tableData.rows[row][col].isHeader
        }
        Divider()
        if tableData.rowCount > 1 {
            Button("Удалить строку", role: .destructive) { tableData.deleteRow(at: row) }
        }
        if tableData.columnCount > 1 {
            Button("Удалить столбец", role: .destructive) { tableData.deleteColumn(at: col) }
        }
    }

    private var footer: some View {
        HStack {
            Button {
                tableData.addColumn()
            } label: {
                Label("Столбец", systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Отмена") { onCancel() }
                .keyboardShortcut(.cancelAction)
            Button("Сохранить") { onSave(tableData) }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

extension NSColor {
    convenience init?(cssHex: String) {
        var hex = cssHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let num = UInt64(hex, radix: 16) else { return nil }
        self.init(
            red: CGFloat((num >> 16) & 0xFF) / 255,
            green: CGFloat((num >> 8) & 0xFF) / 255,
            blue: CGFloat(num & 0xFF) / 255,
            alpha: 1.0
        )
    }
}
