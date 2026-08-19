<div align="center">
  <img src="logo.png" alt="PodSync Logo" width="200" />
  <h1>PodSync</h1>
  <p>A free, open-source macOS application to sync your modern music library to classic iPods.</p>
</div>

## Why PodSync?

There are some fantastic tools out there for managing classic iPods—like Podcenter—that offer excellent functionality. However, many of these solutions are paid. 

I created PodSync because I believe that keeping classic hardware alive shouldn't have to cost money. PodSync provides a modern, native macOS experience for syncing your music and scrobbling your iPod listens to Last.fm—completely free and open source. Syncing your iPod is dead simple.

## Features

### Syncing
- ✨ **True Drag-and-Drop Syncing:** Grab a folder of music from your Mac, drag it into the iPod's library inside PodSync, and watch it sync.
- 📋 **Sync Plan Preview:** Before anything is written, review exactly what will be added, converted, and skipped as a duplicate — then confirm.
- 🎬 **Movies, Podcasts, and Audiobooks:** All media types your classic iPod natively supports, automatically sorted into their correct menus on the device.
- 🎵 **Audio Conversion:** FLAC/WAV/AIFF convert to AAC using macOS's built-in encoder — no extra installs. With [ffmpeg](https://formulae.brew.sh/formula/ffmpeg) installed (`brew install ffmpeg`), OGG/Opus/WMA input and MP3 output work too.
- **Duplicate Detection:** Detects songs already on your device before syncing.
- 💾 **Persistent Library:** Your chosen music folders are remembered and rescanned automatically every launch.

### Podcasts
- 🎙️ **Full Podcast Manager:** Search the podcast directory, subscribe to any show (or paste an RSS URL), browse and download episodes, and sync them straight into the iPod's Podcasts menu — with proper episode dates, descriptions, and unplayed dots.
- 🧹 **Retention:** Keep only the latest N episodes of a show on the iPod; old ones are removed automatically when new ones sync.

### Playlists & Mixes
- 📝 **Playlists:** Create, rename, and delete playlists on the iPod; add tracks by right-click or picker.
- ⚙️ **Smart Playlists:** Rule-based playlists (artist / album / genre / year / rating / play count) materialized onto the device.
- 🎛️ **Auto Mixes (local "Spotify"):** Daily Mix 1–4, Discover Weekly, Release Radar, On Repeat, Repeat Rewind, Your Time Capsule, Your Top Songs, decade mixes, and "This Is <artist>" — all generated from your own library with a fresh shuffle every day. One click writes them to the iPod.
- 🪄 **Genius Mix:** Right-click any song → "Genius Mix from This Song" builds a similarity-based playlist around it.

### Library & Editing
- ✏️ **Metadata Editing:** Edit title, artist, album, genre, year, rating, and artwork on device tracks — including batch edits across a selection.
- 🖼️ **Artwork Lookup:** One-click cover-art search for tracks missing artwork.
- 🔍 **Search & Sort:** Sortable columns (title/artist/album/genre/year/rating/plays) and instant search.

### More
- **Native macOS Interface:** Built entirely with SwiftUI.
- **Last.fm Integration:** Automatically extracts your play history from the iPod and scrobbles it to Last.fm.
- **Settings (⌘,):** Conversion format & bitrate, sync-plan toggle, podcast defaults.
- **Open Source:** Free to use, inspect, and modify forever.

## Screenshots
<p align="center">
  <img src="Screenshots/1.png" width="400" />
  <img src="Screenshots/2.png" width="400" />
  <img src="Screenshots/3.png" width="400" />
  <img src="Screenshots/4.png" width="400" />
  <img src="Screenshots/5.png" width="400" />
</p>

## Requirements
- macOS 13.0 or later
- A classic iPod (e.g., iPod Classic, iPod Nano)

*(Tested and verified working on a MacBook Air M2 2023 and an iPod Classic 7th Gen)*

## Installation

1. Go to the [Releases page](https://github.com/owen-tariq/PodSync/releases) and download the latest `PodSync.dmg`.
2. Open the `.dmg` file and drag **PodSync** into your `Applications` folder.

### Bypassing the "Apple could not verify" Warning
Because PodSync is a free and open-source application, it does not use a paid Apple Developer certificate. When you launch it for the first time, macOS Gatekeeper may show a warning that says:
> *"Apple could not verify “PodSync.app” is free of malware..."*

**To fix this and open the app:**
Open your **Terminal** app and run the following command to remove the quarantine flag:

```bash
xattr -cr /Applications/PodSync.app
```

After running this command, you can open PodSync normally from your Applications folder.

## License
This project is open-source and free to use.
