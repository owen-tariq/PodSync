# Syncing Music to Your iPod

There are several ways to get music from your library onto your iPod.

## Drag and Drop

The simplest way to sync music:

1. **Select tracks** in your library (⌘-click for multiple, Shift-click for a range)
2. **Drag** the selected tracks to your iPod in the sidebar
3. **Drop** when the iPod row highlights

You can drag from any view — Songs, Albums, Artists, or Playlists.

> **Tip:** You can also drag entire albums from the Albums grid view.

## Right-Click Menu

For more control, use the context menu:

1. **Select tracks** you want to sync
2. **Right-click** on the selection
3. Choose **Sync to [Device Name]**

If multiple devices are connected, the sync options are grouped under a **Sync to...** submenu.

> **Note:** Right-click sync works for any connected device — iPods, iPhones and iPads, and external devices.

## Syncing Playlists (iPod Only)

To sync an entire playlist to an iPod:

1. **Right-click** on a playlist in the sidebar
2. Select **Sync to [Device Name]** — the sync starts immediately

If some of the playlist's tracks are already on the device, a duplicate-resolution dialog appears so you can choose what to do with them.

> **Note:** Playlist sync from the sidebar is available for iPods. For external devices, drag individual tracks to the device in the sidebar.

## What Happens During Sync

When you sync tracks, PodCenter:

1. **Checks compatibility** — Verifies the audio format works with your iPod
2. **Converts if needed** — Automatically converts incompatible formats
3. **Copies the file** — Transfers the audio to your iPod
4. **Updates the database** — Adds the track to your iPod's library

### Automatic Format Conversion

If your iPod doesn't support a track's format, PodCenter automatically converts it to a compatible format based on your settings in **Settings → Audio Conversion**.

> **Tip:** Enable **"Keep converted versions"** in Settings to cache converted files. This speeds up future syncs by reusing conversions instead of re-converting each time. See the [Cached Versions](guide://cached-versions) guide for details.

## Monitoring Progress

During sync, a progress bar appears at the bottom of the window showing:

- Current operation (copying, converting)
- Track being processed
- Overall progress

You can cancel an in-progress sync using the button in the progress bar.

## Confirmation Dialog

By default, PodCenter asks for confirmation before syncing. The dialog shows how many tracks will be added.

You can check "Don't show this again" to skip the confirmation dialog in the future.

## Rockbox Sync

If your iPod has [Rockbox](https://www.rockbox.org) installed, PodCenter detects it automatically and creates a separate **"[iPod Name] (Rockbox)"** entry under **Devices** in the sidebar. To sync music for Rockbox, drag tracks to this entry instead of the iPod entry.

When syncing to the Rockbox entry:

- **Files are copied directly** to a folder you choose (default: `/Music`) using a readable folder structure like `Artist/Album/Track.mp3`
- **No database or hash signing** — Rockbox reads metadata directly from the files, so there's no iTunesDB to manage
- **Duplicate detection** checks against the Rockbox music folder, not the iPod firmware's library
- **Format conversion** still works — PodCenter converts incompatible formats before copying

The iPod firmware library and Rockbox library are completely independent. You can sync different music to each, or the same music to both.

For more details, see the [Rockbox Setup Guide](guide://rockbox-setup).

## External Sync (Unsupported Devices)

Some devices use a database format PodCenter can't write to directly. This includes certain iPod Shuffles and other unsupported models. For these devices:

1. Select tracks and choose **Prepare for External Sync...** from the context menu
2. Choose a destination folder
3. PodCenter converts the tracks to a compatible format
4. Use Finder to copy the converted files to your device

## Troubleshooting

### "Track already exists on iPod"

PodCenter checks for duplicates before syncing. If a track is already on your iPod, it won't be copied again.

### Sync seems slow

Large files or format conversion take extra time. Files that need conversion take longer than simple copies, but this ensures your songs will play correctly on your iPod.

Enable **"Keep converted versions"** in Settings → Audio Conversion to cache conversions and speed up future syncs.

### Track doesn't appear on iPod

Try ejecting and reconnecting your iPod. Some older models need a moment to refresh their database after syncing.
