import UIKit

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

        let styled = """
        <style>
            body {
                font-family: -apple-system, SF Pro Text;
                font-size: 16px;
                color: \(textColor);
                line-height: 1.5;
            }
            h1 { font-size: 28px; font-weight: bold; margin: 16px 0 8px; }
            h2 { font-size: 24px; font-weight: bold; margin: 14px 0 6px; }
            h3 { font-size: 20px; font-weight: bold; margin: 12px 0 4px; }
            mark { background-color: \(markBg); padding: 2px 4px; border-radius: 3px; }
            code { font-family: SF Mono, Menlo; font-size: 14px; background-color: \(codeBg); padding: 2px 6px; border-radius: 4px; }
            pre { font-family: SF Mono, Menlo; font-size: 14px; background-color: \(preBg); padding: 12px; border-radius: 8px; overflow-x: auto; }
            blockquote { border-left: 3px solid \(borderColor); padding-left: 12px; color: \(quoteColor); margin: 8px 0; }
            ul, ol { padding-left: 20px; }
            li { margin: 4px 0; }
        </style>
        <body>\(html)</body>
        """

        guard let data = styled.data(using: .utf8),
              let result = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else {
            return NSAttributedString(string: html)
        }
        return result
    }

    static func html(from attributedString: NSAttributedString) -> String {
        guard attributedString.length > 0 else { return "" }

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

        return html.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
