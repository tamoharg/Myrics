import Foundation

final class SpotifyPoller {
    var onTrackChanged: ((SpotifyTrack) -> Void)?
    var onPositionUpdate: ((Int, Bool) -> Void)?
    var onSpotifyQuit: (() -> Void)?

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.captions.SpotifyPoller", qos: .userInteractive)
    private var lastTrackId: String?
    private var wasRunning = false

    func start() {
        if timer != nil { return }
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: 0.35)
        timer?.setEventHandler { [weak self] in self?.poll() }
        timer?.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        lastTrackId = nil
    }

    private func poll() {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify"
                try
                    set tState to player state as string
                    set tPos to player position * 1000
                    set tId to id of current track
                    set tName to name of current track
                    set tArtist to artist of current track
                    set tAlbum to album of current track
                    set tDur to duration of current track
                    set tArt to artwork url of current track
                    return tState & "|||" & tPos & "|||" & tId & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tDur & "|||" & tArt
                on error
                    return "ERROR"
                end try
            end tell
        else
            return "NOT_RUNNING"
        end if
        """
        guard let output = runAppleScript(script)?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }

        if output == "NOT_RUNNING" || output == "ERROR" {
            if wasRunning {
                wasRunning = false
                DispatchQueue.main.async { self.onSpotifyQuit?() }
            }
            return
        }

        wasRunning = true
        let parts = output.components(separatedBy: "|||")
        guard parts.count == 8 else { return }

        let isPlaying = parts[0] == "playing"
        let positionMs = Int(Double(parts[1]) ?? 0)
        let id = parts[2]
        
        let track = SpotifyTrack(
            id: id, name: parts[3], artist: parts[4], album: parts[5],
            durationMs: Int(parts[6]) ?? 0, positionMs: positionMs,
            artworkUrl: URL(string: parts[7])
        )

        DispatchQueue.main.async {
            if self.lastTrackId != track.id {
                self.lastTrackId = track.id
                self.onTrackChanged?(track)
            }
            self.onPositionUpdate?(positionMs, isPlaying)
        }
    }

    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: source) {
            let output = scriptObject.executeAndReturnError(&error)
            if error == nil { return output.stringValue }
        }
        return nil
    }
}
