# Captions for Spotify

A macOS menu bar application that displays the current playing song from Spotify along with its lyrics. It lives right in your menu bar and has a beautiful, native-looking interface.

## Prerequisites
- macOS
- Spotify Desktop Application must be running

## Compilation
This project uses a custom compilation script instead of Xcode to remain lightweight. To build the project, run:

```bash
chmod +x build.sh
./build.sh
```

## Running the App
Once compiled, you will see a `Captions.app` bundle generated in the root directory.

You can run it directly from your terminal:
```bash
open Captions.app
```
Or you can navigate to the folder in Finder and double-click `Captions.app`.

*(Note: If macOS prevents the app from running because it's from an "unidentified developer", you can Right-Click the app in Finder, click "Open", and then confirm you want to open it.)*

## Architecture
- `src/` contains all the Swift source files using AppKit for rendering.
- `SpotifyPoller.swift` interfaces with Spotify to fetch the current track and playback state using AppleScript.
- `Controller.swift` and `Overlay.swift` manage the Menu Bar and floating window logic.
- `build.sh` is used to create the `.app` bundle and compile the `.swift` files into an executable binary using `swiftc`.
