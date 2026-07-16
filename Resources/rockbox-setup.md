# Rockbox Support

PodCenter works with iPods that have [Rockbox](https://www.rockbox.org) firmware installed alongside the original Apple firmware (dual-boot). When Rockbox is detected, a separate sidebar entry is created so you can manage each library independently.

## Detection

PodCenter automatically detects Rockbox when your iPod connects. If a valid Rockbox install is present (a `.rockbox` folder containing `rockbox-info.txt`), you'll see:

- Your iPod's normal entry in the sidebar (for the Apple firmware library)
- A second entry named **"[iPod Name] (Rockbox)"** under Devices
- A **Rockbox version badge** in the iPod's device info card

No setup is required — just connect your iPod.

## Two Sidebar Entries, Two Libraries

When Rockbox is detected, PodCenter creates two independent entries:

### iPod Entry (under Devices)

This is the standard iPod entry. It manages the iPod's native database (iTunesDB) and stores music in `iPod_Control/Music`. This is what the original Apple firmware reads.

### Rockbox Entry (under Devices)

This entry manages a separate music folder for Rockbox. Music is copied directly to the filesystem in a readable folder structure. Rockbox reads metadata from the files themselves, so there's no database to manage and no hash signing required.

When you select the Rockbox entry:

- **Track list** shows files scanned from your Rockbox music folder
- **Drag and drop** copies files to the Rockbox music folder
- **Duplicate detection** checks against Rockbox files, not the iPod database
- **Deletion** removes files from the filesystem directly

The two libraries don't interfere with each other. You can sync different music to each, the same music to both, or only use one.

## Music Folder

By default, PodCenter syncs Rockbox music to a `Music` folder on the root of your iPod. You can change this in the device overview when the Rockbox entry is selected.

### Folder Organization

Choose how synced files are organized:

| Option | Structure |
|--------|-----------|
| Artist / Album | `Music/Pink Floyd/The Wall/Comfortably Numb.mp3` |
| Album Artist / Album | `Music/Pink Floyd/The Wall/Comfortably Numb.mp3` (groups compilations under the album artist) |
| Album | `Music/The Wall/Comfortably Numb.mp3` |
| Artist - Album | `Music/Pink Floyd - The Wall/Comfortably Numb.mp3` |
| Preserve folder structure | Mirrors the original folder layout of your source files |
| Flat (no folders) | `Music/Comfortably Numb.mp3` |

**Artist / Album** is recommended — it matches how most Rockbox users organize their music and works well with Rockbox's file browser.

## Scrobbling

If you use the **Last.fm Scrobbler** plugin in Rockbox, PodCenter can import your listening history. Rockbox writes a `.scrobbler.log` file to your iPod as you listen to music.

When you connect your iPod, the Rockbox sidebar entry shows a **Scrobble Log** card with how many scrobbles are ready to import. Click **Import Scrobbles** to send them to Last.fm and/or ListenBrainz.

You can also import scrobbles from the Rockbox entry's right-click context menu in the sidebar.

Rockbox scrobbles have real timestamps (unlike iPod scrobbles, which are estimated from play counts), so your listening history will be accurate.

> **Note:** Make sure the Last.fm Scrobbler plugin is running in Rockbox (Plugins > Apps > Last.fm Scrobbler). It runs in the background and writes to the log as you listen.

See the [Scrobbling guide](guide://scrobbling-setup) for service setup.

## Format Support

Rockbox supports many audio formats natively, including FLAC, Ogg Vorbis, Opus, and APE — formats the original iPod firmware can't play. PodCenter's conversion settings still apply when syncing to the Rockbox entry, so you can choose whether to convert or copy files as-is.

> **Tip:** If you're only using Rockbox (not the Apple firmware), you can skip conversion entirely and sync lossless files directly. Rockbox handles them natively.

## Storage

The storage bar in the iPod's device overview breaks down space into separate categories:

- **Audio** — music managed by the iPod firmware (iTunesDB)
- **Audio (Rockbox)** — music in your Rockbox music folder
- **Rockbox System** — the `.rockbox` directory (firmware, codecs, themes, database)
- **System** — iPod OS and database files
- **Free** — available space
