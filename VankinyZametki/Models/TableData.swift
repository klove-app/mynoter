import Foundation

struct TableData: Codable, Equatable {
    var rows: [[CellData]]
    var columnWidths: [CGFloat]?

    struct CellData: Codable, Equatable, Identifiable {
        var id = UUID()
        var text: String
        var isHeader: Bool
        var isBold: Bool
        var alignment: CellAlignment
        var colSpan: Int
        var rowSpan: Int
        var backgroundColor: String?

        init(text: String = "", isHeader: Bool = false, isBold: Bool = false,
             alignment: CellAlignment = .left, colSpan: Int = 1, rowSpan: Int = 1,
             backgroundColor: String? = nil) {
            self.text = text
            self.isHeader = isHeader
            self.isBold = isBold
            self.alignment = alignment
            self.colSpan = colSpan
            self.rowSpan = rowSpan
            self.backgroundColor = backgroundColor
        }
    }

    enum CellAlignment: String, Codable, CaseIterable {
        case left, center, right
    }

    static func empty(rows: Int, columns: Int) -> TableData {
        let headerRow = (0..<columns).map { _ in
            CellData(isHeader: true, isBold: true)
        }
        let bodyRows = (1..<rows).map { _ in
            (0..<columns).map { _ in CellData() }
        }
        return TableData(rows: [headerRow] + bodyRows)
    }

    var columnCount: Int { rows.first?.count ?? 0 }
    var rowCount: Int { rows.count }

    mutating func addRow(at index: Int? = nil) {
        let newRow = (0..<columnCount).map { _ in CellData() }
        if let i = index, i < rows.count {
            rows.insert(newRow, at: i)
        } else {
            rows.append(newRow)
        }
    }

    mutating func addColumn(at index: Int? = nil) {
        for r in 0..<rows.count {
            let cell = CellData(isHeader: r == 0, isBold: r == 0)
            if let i = index, i < rows[r].count {
                rows[r].insert(cell, at: i)
            } else {
                rows[r].append(cell)
            }
        }
    }

    mutating func deleteRow(at index: Int) {
        guard rows.count > 1, index < rows.count else { return }
        rows.remove(at: index)
    }

    mutating func deleteColumn(at index: Int) {
        guard columnCount > 1 else { return }
        for r in 0..<rows.count {
            guard index < rows[r].count else { continue }
            rows[r].remove(at: index)
        }
    }

    func toHTML() -> String {
        var html = "<table data-vz-table=\"1\">\n"

        for (rowIdx, row) in rows.enumerated() {
            html += "  <tr>\n"
            for cell in row {
                let tag = cell.isHeader ? "th" : "td"
                var style = ""
                if cell.isBold && !cell.isHeader { style += "font-weight:bold;" }
                if cell.alignment != .left { style += "text-align:\(cell.alignment.rawValue);" }
                if let bg = cell.backgroundColor { style += "background-color:\(bg);" }

                var attrs = ""
                if !style.isEmpty { attrs += " style=\"\(style)\"" }
                if cell.colSpan > 1 { attrs += " colspan=\"\(cell.colSpan)\"" }
                if cell.rowSpan > 1 { attrs += " rowspan=\"\(cell.rowSpan)\"" }

                html += "    <\(tag)\(attrs)>\(cell.text)</\(tag)>\n"
            }
            html += "  </tr>\n"
        }

        html += "</table>"
        return html
    }

    static func from(html: String) -> TableData? {
        var rows: [[CellData]] = []

        let trPattern = "<tr[^>]*>(.*?)</tr>"
        guard let trRegex = try? NSRegularExpression(pattern: trPattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let trMatches = trRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))

        for trMatch in trMatches {
            guard let trRange = Range(trMatch.range(at: 1), in: html) else { continue }
            let trContent = String(html[trRange])

            var row: [CellData] = []
            let cellPattern = "<(th|td)([^>]*)>(.*?)</(?:th|td)>"
            guard let cellRegex = try? NSRegularExpression(pattern: cellPattern, options: [.dotMatchesLineSeparators]) else { continue }
            let cellMatches = cellRegex.matches(in: trContent, range: NSRange(trContent.startIndex..., in: trContent))

            for cellMatch in cellMatches {
                guard let tagRange = Range(cellMatch.range(at: 1), in: trContent),
                      let attrsRange = Range(cellMatch.range(at: 2), in: trContent),
                      let textRange = Range(cellMatch.range(at: 3), in: trContent) else { continue }

                let tag = String(trContent[tagRange])
                let attrs = String(trContent[attrsRange])
                let text = String(trContent[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)

                var cell = CellData(text: text, isHeader: tag == "th", isBold: tag == "th")

                if let style = extractAttribute("style", from: attrs) {
                    if style.contains("font-weight:bold") { cell.isBold = true }
                    if style.contains("text-align:center") { cell.alignment = .center }
                    else if style.contains("text-align:right") { cell.alignment = .right }
                    if let bg = extractCSSValue("background-color", from: style) { cell.backgroundColor = bg }
                }
                if let cs = extractAttribute("colspan", from: attrs), let v = Int(cs) { cell.colSpan = v }
                if let rs = extractAttribute("rowspan", from: attrs), let v = Int(rs) { cell.rowSpan = v }

                row.append(cell)
            }

            if !row.isEmpty { rows.append(row) }
        }

        guard !rows.isEmpty else { return nil }
        return TableData(rows: rows)
    }

    private static func extractAttribute(_ name: String, from attrs: String) -> String? {
        let pattern = "\(name)\\s*=\\s*\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: attrs, range: NSRange(attrs.startIndex..., in: attrs)),
              let range = Range(match.range(at: 1), in: attrs) else { return nil }
        return String(attrs[range])
    }

    private static func extractCSSValue(_ property: String, from style: String) -> String? {
        let pattern = "\(property)\\s*:\\s*([^;]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: style, range: NSRange(style.startIndex..., in: style)),
              let range = Range(match.range(at: 1), in: style) else { return nil }
        return String(style[range]).trimmingCharacters(in: .whitespaces)
    }
}
