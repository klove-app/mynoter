import SwiftUI

struct iOSTableEditorView: View {
    @State var tableData: TableData
    let onSave: (TableData) -> Void
    let onCancel: () -> Void

    @State private var editingCell: CellID?
    @State private var editText = ""
    @FocusState private var cellFocused: Bool

    struct CellID: Equatable, Hashable {
        let row: Int
        let col: Int
    }

    var body: some View {
        VStack(spacing: 0) {
            sizeBar

            ScrollView([.horizontal, .vertical]) {
                tableGrid
                    .padding(12)
            }

            actionBar
        }
        .navigationTitle("Таблица")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Отмена") { onCancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Готово") { onSave(tableData) }
                    .fontWeight(.semibold)
            }
        }
    }

    private var sizeBar: some View {
        HStack {
            Text("\(tableData.rowCount) строк × \(tableData.columnCount) столбцов")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if let editing = editingCell {
                Text("Ячейка [\(editing.row + 1), \(editing.col + 1)]")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.teal)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }

    private var tableGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<tableData.rowCount, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<tableData.columnCount, id: \.self) { col in
                        cellView(row: row, col: col)
                    }
                }
            }
        }
    }

    private func cellView(row: Int, col: Int) -> some View {
        let cell = tableData.rows[row][col]
        let isEditing = editingCell == CellID(row: row, col: col)

        return ZStack {
            Rectangle()
                .fill(cellBackground(cell: cell, row: row))
                .overlay(
                    Rectangle()
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
                )

            if isEditing {
                TextField("", text: $editText)
                    .focused($cellFocused)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: cell.isBold ? .bold : .regular))
                    .padding(8)
                    .onSubmit { commitEdit(row: row, col: col) }
            } else {
                Text(cell.text.isEmpty ? " " : cell.text)
                    .font(.system(size: 14, weight: cell.isBold || cell.isHeader ? .bold : .regular))
                    .frame(maxWidth: .infinity, alignment: alignment(for: cell.alignment))
                    .padding(8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let prev = editingCell {
                            commitEdit(row: prev.row, col: prev.col)
                        }
                        editingCell = CellID(row: row, col: col)
                        editText = cell.text
                        cellFocused = true
                    }
            }
        }
        .frame(minWidth: 100, minHeight: 44)
        .contextMenu {
            cellContextMenu(row: row, col: col)
        }
    }

    private func cellBackground(cell: TableData.CellData, row: Int) -> Color {
        if cell.isHeader {
            return Color(.tertiarySystemFill)
        }
        return row % 2 == 0 ? Color.clear : Color(.systemGray6).opacity(0.5)
    }

    private func alignment(for a: TableData.CellAlignment) -> Alignment {
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
        cellFocused = false
    }

    @ViewBuilder
    private func cellContextMenu(row: Int, col: Int) -> some View {
        Button { tableData.addRow(at: row) } label: {
            Label("Строка выше", systemImage: "arrow.up.to.line")
        }
        Button { tableData.addRow(at: row + 1) } label: {
            Label("Строка ниже", systemImage: "arrow.down.to.line")
        }
        Divider()
        Button { tableData.addColumn(at: col) } label: {
            Label("Столбец слева", systemImage: "arrow.left.to.line")
        }
        Button { tableData.addColumn(at: col + 1) } label: {
            Label("Столбец справа", systemImage: "arrow.right.to.line")
        }
        Divider()

        Menu("Выравнивание") {
            Button("Лево") { tableData.rows[row][col].alignment = .left }
            Button("Центр") { tableData.rows[row][col].alignment = .center }
            Button("Право") { tableData.rows[row][col].alignment = .right }
        }

        Button {
            tableData.rows[row][col].isBold.toggle()
        } label: {
            Label(tableData.rows[row][col].isBold ? "Убрать жирный" : "Жирный",
                  systemImage: "bold")
        }

        Button {
            tableData.rows[row][col].isHeader.toggle()
            tableData.rows[row][col].isBold = tableData.rows[row][col].isHeader
        } label: {
            Label(tableData.rows[row][col].isHeader ? "Обычная" : "Заголовок",
                  systemImage: "textformat")
        }

        Divider()

        if tableData.rowCount > 1 {
            Button(role: .destructive) { tableData.deleteRow(at: row) } label: {
                Label("Удалить строку", systemImage: "trash")
            }
        }
        if tableData.columnCount > 1 {
            Button(role: .destructive) { tableData.deleteColumn(at: col) } label: {
                Label("Удалить столбец", systemImage: "trash")
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 16) {
            Button {
                tableData.addRow()
            } label: {
                Label("Строка", systemImage: "plus")
                    .font(.caption)
            }

            Button {
                tableData.addColumn()
            } label: {
                Label("Столбец", systemImage: "plus")
                    .font(.caption)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }
}
