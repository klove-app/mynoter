import UIKit

let vzImageURLKey = NSAttributedString.Key("VZImageURL")
let vzTableHTMLKey = NSAttributedString.Key("VZTableHTML")
let vzDiagramMermaidKey = NSAttributedString.Key("VZDiagramMermaid")

enum HTMLConverter {
    static func attributedString(from html: String) -> NSAttributedString {
        guard !html.isEmpty else { return NSAttributedString() }

        let isDark = UITraitCollection.current.userInterfaceStyle == .dark
        let textColor = isDark ? "#FFFFFF" : "#000000"
        let codeBg = isDark ? "#2C2C2E" : "#F0F0F0"
        let preBg = isDark ? "#1C1C1E" : "#F5F5F5"
        let borderColor = isDark ? "#555" : "#CCC"
        let quoteColor = isDark ? "#AAA" : "#666"
        let markBg = isDark ? "#B8860B" : "#FFEF5C"
        let tableBg = isDark ? "#1E1E20" : "#FAFAFA"
        let tableHeaderBg = isDark ? "#2A2A2E" : "#F0F0F2"

        let styled = """
        <style>
            body {
                font-family: -apple-system, SF Pro Text, system-ui;
                font-size: 17px;
                color: \(textColor);
                line-height: 1.65;
                -webkit-font-smoothing: antialiased;
            }
            p { margin: 0 0 0.55em 0; }
            h1 {
                font-size: 28px; font-weight: 700;
                margin: 20px 0 8px; letter-spacing: -0.02em;
            }
            h2 {
                font-size: 24px; font-weight: 700;
                margin: 18px 0 6px; letter-spacing: -0.015em;
            }
            h3 {
                font-size: 20px; font-weight: 600;
                margin: 14px 0 4px; letter-spacing: -0.01em;
            }
            mark { background-color: \(markBg); padding: 2px 4px; border-radius: 3px; }
            code {
                font-family: SF Mono, Menlo, monospace;
                font-size: 15px;
                background-color: \(codeBg);
                padding: 2px 6px; border-radius: 4px;
            }
            pre {
                font-family: SF Mono, Menlo, monospace;
                font-size: 15px;
                background-color: \(preBg);
                padding: 12px 14px; border-radius: 8px;
                overflow-x: auto; line-height: 1.5;
            }
            blockquote {
                border-left: 3px solid \(borderColor);
                padding: 6px 14px;
                margin: 10px 0;
                color: \(quoteColor);
                font-style: italic;
                background-color: \(isDark ? "rgba(255,255,255,0.02)" : "rgba(0,0,0,0.02)");
                border-radius: 0 6px 6px 0;
            }
            ul, ol { padding-left: 22px; margin: 4px 0; }
            li { margin: 5px 0; line-height: 1.55; }
            img {
                max-width: 100%; height: auto;
                border-radius: 8px; margin: 6px 0;
            }
            table[data-vz-table] {
                border-collapse: collapse;
                width: 100%;
                margin: 10px 0;
                font-size: 15px;
                background-color: \(tableBg);
                border-radius: 6px;
            }
            table[data-vz-table] th, table[data-vz-table] td {
                border: 1px solid \(borderColor);
                padding: 8px 12px;
                text-align: left;
            }
            table[data-vz-table] th {
                background-color: \(tableHeaderBg);
                font-weight: 600;
                font-size: 14px;
            }
            hr {
                border: none;
                border-top: 1px solid \(borderColor);
                margin: 16px 0;
            }
        </style>
        <body>\(html)</body>
        """

        guard let data = styled.data(using: .utf8),
              let result = try? NSMutableAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else {
            return NSAttributedString(string: html)
        }

        flattenNestedTextLists(in: result)
        postProcessImages(in: result, html: html)

        return result
    }

    private static func flattenNestedTextLists(in attrString: NSMutableAttributedString) {
        let fullRange = NSRange(location: 0, length: attrString.length)
        var fixes: [(NSRange, NSMutableParagraphStyle)] = []

        attrString.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { value, range, _ in
            guard let paraStyle = value as? NSParagraphStyle else { return }
            guard !paraStyle.textLists.isEmpty else { return }

            let mutableStyle = (paraStyle.mutableCopy() as! NSMutableParagraphStyle)
            mutableStyle.textLists = []
            mutableStyle.headIndent = 24
            mutableStyle.firstLineHeadIndent = 4
            mutableStyle.tabStops = [NSTextTab(textAlignment: .natural, location: 24)]
            mutableStyle.paragraphSpacingBefore = 2

            fixes.append((range, mutableStyle))
        }

        for (range, style) in fixes {
            attrString.addAttribute(.paragraphStyle, value: style, range: range)
        }
    }

    static func html(from attributedString: NSAttributedString) -> String {
        guard attributedString.length > 0 else { return "" }

        var imageMap: [Int: String] = [:]
        var diagramMermaidMap: [Int: String] = [:]
        var tableMap: [Int: String] = [:]

        attributedString.enumerateAttributes(
            in: NSRange(location: 0, length: attributedString.length),
            options: []
        ) { attrs, range, _ in
            if let url = attrs[vzImageURLKey] as? String {
                imageMap[range.location] = url
            }
            if let mermaid = attrs[vzDiagramMermaidKey] as? String {
                diagramMermaidMap[range.location] = mermaid
            }
            if let tableHTML = attrs[vzTableHTMLKey] as? String {
                tableMap[range.location] = tableHTML
            }
        }

        guard let data = try? attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
        ) else {
            return attributedString.string
        }

        var html = String(data: data, encoding: .utf8) ?? attributedString.string

        if let bodyStart = html.range(of: "<body", options: .caseInsensitive),
           let bodyTagEnd = html[bodyStart.upperBound...].range(of: ">"),
           let bodyClose = html.range(of: "</body>", options: .caseInsensitive) {
            html = String(html[bodyTagEnd.upperBound..<bodyClose.lowerBound])
        }

        for (offset, url) in imageMap.sorted(by: { $0.key < $1.key }) {
            if let base64Range = html.range(of: "<img[^>]*src=\"data:image[^\"]*\"[^>]*>",
                                             options: .regularExpression) {
                var attrs = "src=\"\(url)\" style=\"max-width:100%;height:auto;\""
                if let mermaid = diagramMermaidMap[offset] {
                    let b64 = Data(mermaid.utf8).base64EncodedString()
                    attrs += " data-mermaid-b64=\"\(b64)\" class=\"vz-diagram\""
                }
                html = html.replacingCharacters(in: base64Range, with: "<img \(attrs)>")
            }
        }

        for (_, tableHTML) in tableMap {
            if let placeholder = html.range(of: "\\[📊[^\\]]*\\]", options: .regularExpression) {
                html = html.replacingCharacters(in: placeholder, with: tableHTML)
            }
        }

        html = flattenNestedListHTML(html)
        return html.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func flattenNestedListHTML(_ html: String) -> String {
        var result = html
        for _ in 0..<5 {
            let pattern = "<ul[^>]*>\\s*<li[^>]*>\\s*<ul[^>]*>(.*?)</ul>\\s*</li>\\s*</ul>"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { break }
            let range = NSRange(result.startIndex..., in: result)
            let newResult = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "<ul>$1</ul>")
            if newResult == result { break }
            result = newResult
        }
        for _ in 0..<5 {
            let pattern = "<li[^>]*>\\s*<ul[^>]*>\\s*<li([^>]*)>(.*?)</li>\\s*</ul>\\s*</li>"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { break }
            let range = NSRange(result.startIndex..., in: result)
            let newResult = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "<li$1>$2</li>")
            if newResult == result { break }
            result = newResult
        }
        return result
    }

    // MARK: - Post-processing

    private static func postProcessImages(in attrString: NSMutableAttributedString, html: String) {
        let imgPattern = "<img[^>]+src=\"([^\"]+)\"[^>]*>"
        guard let regex = try? NSRegularExpression(pattern: imgPattern, options: .caseInsensitive) else { return }
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))

        struct ImageInfo {
            let url: String
            let mermaidCode: String?
        }

        var images: [ImageInfo] = []
        let b64Regex = try? NSRegularExpression(pattern: "data-mermaid-b64=\"([^\"]+)\"", options: .caseInsensitive)
        let legacyRegex = try? NSRegularExpression(pattern: "data-mermaid=\"([^\"]+)\"", options: .caseInsensitive)
        for match in matches {
            if let urlRange = Range(match.range(at: 1), in: html) {
                let url = String(html[urlRange])
                guard !url.hasPrefix("data:") else { continue }
                var mermaid: String?
                if let fullRange = Range(match.range, in: html) {
                    let tag = String(html[fullRange])
                    if let b64Match = b64Regex?.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
                       let mRange = Range(b64Match.range(at: 1), in: tag),
                       let decoded = Data(base64Encoded: String(tag[mRange])),
                       let code = String(data: decoded, encoding: .utf8) {
                        mermaid = code
                    } else if let legacyMatch = legacyRegex?.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
                              let mRange = Range(legacyMatch.range(at: 1), in: tag) {
                        mermaid = String(tag[mRange]).replacingOccurrences(of: "&quot;", with: "\"")
                    }
                }
                images.append(ImageInfo(url: url, mermaidCode: mermaid))
            }
        }

        guard !images.isEmpty else { return }

        var imgIndex = 0
        let fullRange = NSRange(location: 0, length: attrString.length)
        attrString.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            guard value is NSTextAttachment, imgIndex < images.count else { return }
            let info = images[imgIndex]
            attrString.addAttribute(vzImageURLKey, value: info.url, range: range)
            if let mermaid = info.mermaidCode {
                attrString.addAttribute(vzDiagramMermaidKey, value: mermaid, range: range)
            }
            imgIndex += 1
        }

        for info in images {
            loadRemoteImage(url: info.url, into: attrString)
        }
    }

    private static func loadRemoteImage(url urlString: String, into attrString: NSMutableAttributedString) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                let fullRange = NSRange(location: 0, length: attrString.length)
                attrString.enumerateAttribute(vzImageURLKey, in: fullRange, options: []) { value, range, stop in
                    guard let stored = value as? String, stored == urlString else { return }
                    let existingMermaid = attrString.attribute(vzDiagramMermaidKey, at: range.location, effectiveRange: nil) as? String
                    let attachment = NSTextAttachment()
                    let maxWidth: CGFloat = UIScreen.main.bounds.width - 48
                    let scale = image.size.width > maxWidth ? maxWidth / image.size.width : 1.0
                    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    attachment.image = image
                    attachment.bounds = CGRect(origin: .zero, size: size)
                    let replacement = NSMutableAttributedString(attachment: attachment)
                    let repRange = NSRange(location: 0, length: replacement.length)
                    replacement.addAttribute(vzImageURLKey, value: urlString, range: repRange)
                    if let mermaid = existingMermaid {
                        replacement.addAttribute(vzDiagramMermaidKey, value: mermaid, range: repRange)
                    }
                    attrString.replaceCharacters(in: range, with: replacement)
                    stop.pointee = true
                }
            }
        }.resume()
    }

    // MARK: - Insertion helpers

    static func insertImageAttachment(url: String, image: UIImage, maxWidth: CGFloat? = nil) -> NSAttributedString {
        let attachment = NSTextAttachment()
        let effectiveMaxWidth = maxWidth ?? (UIScreen.main.bounds.width - 48)
        let scale = image.size.width > effectiveMaxWidth ? effectiveMaxWidth / image.size.width : 1.0
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        attachment.image = image
        attachment.bounds = CGRect(origin: .zero, size: size)

        let result = NSMutableAttributedString(string: "\n")
        let imgStr = NSMutableAttributedString(attachment: attachment)
        imgStr.addAttribute(vzImageURLKey, value: url, range: NSRange(location: 0, length: imgStr.length))
        result.append(imgStr)
        result.append(NSAttributedString(string: "\n"))
        return result
    }

    static func insertTablePlaceholder(tableHTML: String, tableData: TableData) -> NSAttributedString {
        let preview = tablePreviewString(from: tableData)
        let result = NSMutableAttributedString(string: "\n" + preview + "\n")
        let pRange = NSRange(location: 1, length: preview.count)
        result.addAttributes([
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: UIColor.secondaryLabel,
            .backgroundColor: UIColor.quaternarySystemFill,
            vzTableHTMLKey: tableHTML
        ], range: pRange)
        return result
    }

    private static func tablePreviewString(from table: TableData) -> String {
        let cols = table.columnCount
        let rows = table.rowCount
        var preview = "[📊 Таблица \(rows)×\(cols)"
        if let firstRow = table.rows.first, !firstRow.isEmpty {
            let headers = firstRow.prefix(3).map { $0.text.isEmpty ? "…" : $0.text }
            preview += ": " + headers.joined(separator: " | ")
            if firstRow.count > 3 { preview += " | …" }
        }
        preview += "]"
        return preview
    }
}
