import Foundation

enum UIMode {
    case menuBar
    case floating
}

struct SpotifyTrack: Equatable {
    let id: String
    let name: String
    let artist: String
    let album: String
    let durationMs: Int
    let positionMs: Int
    let artworkUrl: URL?
}

struct LyricLine {
    let timeMs: Int
    let text: String
}

enum DisplayState {
    case idle
    case intro(track: SpotifyTrack)
    case lyrics(track: SpotifyTrack, currentLine: String)
    case fallback(track: SpotifyTrack)
}
