# iPod Artwork Guide

## How Artwork Works on iPods

iPods with color screens display album artwork while you browse and play music. Artwork can come from two places:

1. **The iPod's display database** — A separate artwork store the iPod reads when showing cover art
2. **The audio files themselves** — Artwork embedded directly in each song file

For artwork to show on your iPod, it needs to be in the display database. PodCenter handles this automatically when you sync music.

## During Sync

When you sync tracks to your iPod, PodCenter:

1. Looks for artwork in your music files
2. If there's no embedded artwork, checks the album folder for images like `cover.jpg` or `album.png`
3. Adds the artwork to both the synced audio file and the iPod's display database

This means your synced music is self-contained - if you ever copy songs back from your iPod, the artwork comes with them.

## "Embed Artwork from Files" Feature

### What It Does

This feature scans your iPod for tracks that are missing artwork in the display database, then extracts artwork from the audio files and adds it so your iPod can show it.

### When to Use It

Use this feature when:

- Album art isn't showing on your iPod, but you know the songs have artwork
- You synced music with iTunes or another app and artwork didn't transfer
- You restored your iPod and artwork is missing
- Some albums show artwork and others don't

### How to Use It

> **Note:** This feature is available for iPods only, not external devices.

1. Connect your iPod to your Mac
2. Right-click on the iPod in PodCenter's sidebar
3. Select **Embed Artwork from Files...**
4. PodCenter will scan your iPod and show you:
   - How many tracks already have artwork
   - How many can have artwork added
   - How many have no artwork available
5. Click **Embed Artwork** to proceed

### What to Expect

- **"Can Embed"** - These tracks have artwork in their audio files that will be added to the display database
- **"No Artwork"** - These tracks don't have artwork in their audio files, so there's nothing to extract

## Supported Artwork Locations

PodCenter looks for artwork in these places:

**Inside audio files:**
- Embedded cover art in MP3, M4A, AAC, FLAC, and other formats

**In album folders (for your library, not iPod):**

The following filenames are checked in priority order (case-insensitive):
1. `folder.jpg` / `.jpeg` / `.png`
2. `cover.jpg` / `.jpeg` / `.png`
3. `album.jpg` / `.jpeg` / `.png`
4. `artwork.jpg` / `.jpeg` / `.png`
5. `front.jpg` / `.jpeg` / `.png`

These are the most common names — others such as `albumart.jpg`, `large_cover.jpg`, `cover-front.jpg`, and `disc.jpg` are also detected.

Supported image formats: JPEG, PNG, HEIC, WebP, TIFF, and BMP.

If none of the above filenames are found, PodCenter will automatically pick the best image in the folder based on dimensions, aspect ratio, and filename.

## Troubleshooting

### Artwork not showing on iPod

1. Try **Embed Artwork from Files** to scan and fix missing artwork
2. If tracks show "No Artwork", the source files don't have artwork embedded - you'll need to add it to your library first, then re-sync

### Artwork shows in PodCenter but not on iPod

The artwork is in the audio file but not the iPod's display database. Run **Embed Artwork from Files** to fix this.

### Many tracks show "No Artwork Available"

Your source music files don't have artwork embedded. To fix:
- Add artwork to your music files in your library
- Put a `cover.jpg` file in each album's folder
- Re-sync the affected tracks

## iPod Compatibility

| iPod Model | Artwork Display |
|------------|-----------------|
| iPod Classic (color) | Yes |
| iPod Nano (all generations) | Yes |
| iPod Mini | No (grayscale screen) |
| iPod Shuffle | No (no screen) |
| iPod Touch | N/A (syncs via Finder/Music app) |

> **iPod Touch & iPhone:** PodCenter doesn't sync directly to iOS devices, but you can use the **Prepare for External Sync** feature to convert your music into compatible formats, then sync the converted files using Finder or the Music app.

Even for iPods without screens, PodCenter still embeds artwork in the audio files so you'll have it if you ever move the music to a different device.
