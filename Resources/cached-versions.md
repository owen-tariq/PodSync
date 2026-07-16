# Cached Versions

When syncing music to your iPod, PodCenter often needs to convert audio files to formats your iPod supports. **Cached versions** save these converted files so you don't have to wait for conversion again on future syncs.

## How It Works

1. **During sync**, if a track needs conversion (e.g., FLAC to AAC), PodCenter converts it
2. **If caching is enabled**, the converted file is saved to a cache folder
3. **On future syncs**, PodCenter checks the cache first and uses the existing conversion instead of re-converting

This can significantly speed up syncs, especially for large libraries with many lossless files.

## Enabling Cached Versions

1. Open **Settings** (⌘,)
2. Go to the **Audio Conversion** section
3. Enable **"Keep converted versions"**

Once enabled, converted files are automatically cached during sync.

## Cache Settings

When caching is enabled, you can configure:

| Setting | Description |
|---------|-------------|
| **Cache limit** | Maximum storage for cached versions. Set to 0 for unlimited, or choose 1-50 GB. When the limit is reached, older unused versions are removed to make space. |

## Viewing Cached Versions

You can see which cached versions exist for any track:

1. Select a track in your library
2. Open the **Inspector** (View → Show Inspector, or ⌘⌥I)
3. Look for the **Cached Versions** section

Each cached version shows:
- **Format** (e.g., AAC, MP3)
- **Bitrate** (e.g., 192kbps, 256kbps)
- **Sample rate** (e.g., 44.1kHz)
- **Quality indicator** (Lossless, High, Medium, Good, or Basic)
- **File size**

For example: `AAC 192kbps 44.1kHz High (3.2 MB)`

Click the arrow button next to any version to reveal it in Finder.

## Storage Location

By default, cached versions are stored in:

```
~/Library/Application Support/PodCenter/Versions/
```

You can move the cache elsewhere from **Settings → Audio Conversion** using the **Choose...** button next to "Cache location" (a reset button restores the default). Changing the location takes effect after restarting PodCenter.

Files are organized by artist, album, and track name:

```
Versions/
  Artists/
    Artist Name/
      Album Name/
        Track Name/
          aac_192kbps_44100hz.m4a
```

You can open this folder directly from Settings using the **"Show in Finder"** button.

## Managing Cache Storage

### Check Usage

In **Settings → Audio Conversion**, you can see:
- Current storage used by cached versions
- Percentage of your cache limit used (if a limit is set)

### Clear All Cached Versions

To remove all cached versions:

1. Open **Settings** (⌘,)
2. Go to **Audio Conversion**
3. Click **"Clear Cache"**

This permanently deletes all cached conversions. They'll be re-created as needed during future syncs.

## When Caching Helps Most

Cached versions provide the biggest benefit when:

- You have **lossless files** (FLAC, ALAC, WAV) that need conversion
- You sync **frequently** to the same or different iPods
- You sync the **same tracks** to multiple devices
- Conversion takes a long time due to **large files** or **older hardware**

## Cache Matching

PodCenter matches cached versions by comparing:
- Target format (AAC, MP3, etc.)
- Bitrate
- Sample rate
- Quality settings

If your conversion settings change, existing cached versions may not match, and new conversions will be created.

## Tips

- **Start with a reasonable cache limit** (5-10 GB) and adjust based on your needs
- **Check the Inspector** to verify tracks have cached versions before a long sync
- **Clear the cache** if you change quality settings significantly and want to re-convert everything
- Cached versions are **independent of your original files** - deleting a cached version doesn't affect your music library
