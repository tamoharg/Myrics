import Foundation

final class LyricsEngine {
    private var lastIndex = 0

    func reset() {
        lastIndex = 0
    }

    func currentLine(for positionMs: Int, in lyrics: [LyricLine]) -> String? {
        if lyrics.isEmpty { return nil }
        var l = 0, r = lyrics.count - 1, b = -1
        while l <= r {
            let m = (l + r) / 2
            if lyrics[m].timeMs <= positionMs {
                b = m
                l = m + 1
            } else {
                r = m - 1
            }
        }
        if b != -1 && b != lastIndex {
            lastIndex = b
            return lyrics[b].text
        }
        return b == -1 ? nil : lyrics[b].text
    }
    
    func firstLyricTimeMs(in lyrics: [LyricLine]) -> Int? {
        return lyrics.first?.timeMs
    }
}

final class Transliterator {
    private func needsTransliteration(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            // Any character beyond standard extended latin (Devanagari, Cyrillic, CJK, etc.)
            if scalar.value > 0x02AF {
                return true
            }
        }
        return false
    }

    func transliterate(_ text: String) -> String {
        if !needsTransliteration(text) { return text }
        let ms = NSMutableString(string: text)
        CFStringTransform(ms as CFMutableString, nil, kCFStringTransformToLatin, false)
        CFStringTransform(ms as CFMutableString, nil, kCFStringTransformStripDiacritics, false)
        return (ms as String).lowercased()
    }
}
