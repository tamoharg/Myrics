import Foundation

final class LyricsFetcher {
    func fetchLyrics(trackName: String, artistName: String, albumName: String) async -> [LyricLine]? {
        let q = "\(trackName) \(artistName)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://lrclib.net/api/search?q=\(q)") else { return nil }
        
        do {
            var req = URLRequest(url: url)
            req.setValue("Captions macOS App", forHTTPHeaderField: "User-Agent")
            let (data, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse {
                NSLog("[Captions] LRCLIB search for '\(trackName)' — '\(artistName)': HTTP \(http.statusCode)")
            }
            
            if let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for item in items {
                    if let syncedLyrics = item["syncedLyrics"] as? String, !syncedLyrics.isEmpty {
                        let lines = parseLRC(syncedLyrics)
                        if !lines.isEmpty {
                            NSLog("[Captions] Found \(lines.count) synced lyric lines for '\(trackName)'")
                            return lines
                        }
                    }
                }
            }
        } catch {
            NSLog("[Captions] LRCLIB request failed: \(error.localizedDescription)")
        }
        return nil
    }

    private func parseLRC(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let regex = try! NSRegularExpression(pattern: "\\[(\\d{2}):(\\d{2})\\.(\\d{2})\\](.*)")
        
        for line in lrc.components(separatedBy: .newlines) {
            if let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                let m = Int((line as NSString).substring(with: match.range(at: 1))) ?? 0
                let s = Int((line as NSString).substring(with: match.range(at: 2))) ?? 0
                let msMatches = (line as NSString).substring(with: match.range(at: 3))
                let ms = Int(msMatches.padding(toLength: 3, withPad: "0", startingAt: 0)) ?? 0
                let text = (line as NSString).substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)
                let totalMs = (m * 60 * 1000) + (s * 1000) + ms
                lines.append(LyricLine(timeMs: totalMs, text: text))
            }
        }
        return lines.sorted { $0.timeMs < $1.timeMs }
    }
}
