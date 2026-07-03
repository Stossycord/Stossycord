import Foundation

actor TenorMediaResolver {
    static let shared = TenorMediaResolver()

    private var cache: [URL: URL] = [:]

    func mediaURL(for url: URL) async -> URL {
        guard url.isTenorPageURL else {
            return url
        }

        if let cachedURL = cache[url] {
            return cachedURL
        }

        guard let resolvedURL = await resolveMediaURL(from: url) else {
            return url
        }

        cache[url] = resolvedURL
        return resolvedURL
    }

    private func resolveMediaURL(from url: URL) async -> URL? {
        var request = URLRequest(url: url)
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let html = String(data: data, encoding: .utf8) else {
                return nil
            }

            return Self.extractMediaURL(from: html)
        } catch {
            return nil
        }
    }

    private static func extractMediaURL(from html: String) -> URL? {
        for property in ["og:image", "twitter:image", "og:image:url", "twitter:image:src"] {
            if let content = metaContent(named: property, in: html),
               let url = URL(string: content.decodingHTMLEntities),
               !url.isTenorPageURL {
                return url
            }
        }

        return nil
    }

    private static func metaContent(named name: String, in html: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let patterns = [
            #"<meta\b(?=[^>]*(?:property|name)\s*=\s*["']"# + escapedName + #"\s*["'])(?=[^>]*content\s*=\s*["']([^"']+)["'])[^>]*>"#,
            #"<meta\b(?=[^>]*content\s*=\s*["']([^"']+)["'])(?=[^>]*(?:property|name)\s*=\s*["']"# + escapedName + #"\s*["'])[^>]*>"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            guard let match = regex.firstMatch(in: html, range: range),
                  let contentRange = Range(match.range(at: 1), in: html) else {
                continue
            }

            return String(html[contentRange])
        }

        return nil
    }
}

private extension String {
    var decodingHTMLEntities: String {
        guard let data = data(using: .utf8),
              let attributedString = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else {
            return self
        }

        return attributedString.string
    }
}
