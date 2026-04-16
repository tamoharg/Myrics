# Captions for Spotify

A macOS menu bar application that displays the current playing song from Spotify along with its lyrics. It lives right in your menu bar and has a beautiful, native-looking interface.

## Prerequisites
- macOS Tahoe (26.1) and above
- MacBook without the display notch - models introduced before october 2021.
- Spotify Desktop Application or web app must be running

## Directly download the Application 
Click on this  link
## Compilation
This project uses a custom compilation script instead of Xcode to remain lightweight. To build the project, run:

```bash
chmod +x build.sh
./build.sh
```

## Running the App
Once compiled, you will see a `Myrics.app` bundle generated in the root directory.

You can run it directly from your terminal:
```bash
open Myrics.app
```
Or you can navigate to the folder in Finder and double-click `Myrics.app`.

*(Note: If macOS prevents the app from running because it's from an "unidentified developer", you can Right-Click the app in Finder, click "Open", and then confirm you want to open it.)*

## Architecture
- `src/` contains all the Swift source files using AppKit for rendering.
- `SpotifyPoller.swift` interfaces with Spotify to fetch the current track and playback state using AppleScript.
- `Controller.swift` and `Overlay.swift` manage the Menu Bar and floating window logic.
- `build.sh` is used to create the `.app` bundle and compile the `.swift` files into an executable binary using `swiftc`.

--- Features to be implemented in v0.1 ---

>> create a one time window while installation to drag the application to applications folder

>> backwards compatibility ( to older versions of macOS like catalina)

>> minor improvements to improve user experience

>> have memory of it's position in each desktop

>> close it in the individual desktop ( not everywhere)

>> pop down UI window improvements

--- Features to be implemented in v0.2 ---

>> make it more lightweight

>> supports apple music

-- Features to be implemented in v0.3 ---

>> introduce this for MacBooks with the display notch.
