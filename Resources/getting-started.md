# Getting Started with PodCenter

Welcome to PodCenter! This guide will help you set up your music library and start syncing to your iPod.

## Before You Begin: Enable Disk Use

For PodCenter to fully manage your iPod, you need to enable disk use mode. This allows PodCenter to access the iPod's database and sync music directly.

### In Finder (macOS Catalina and later)

1. **Connect your iPod** via USB
2. **Select it** in Finder's sidebar
3. **Check "Enable disk use"** in the Options section at the bottom
4. **Click Apply**

### In iTunes or Music app (if available)

1. **Connect your iPod** via USB
2. **Select it** in the sidebar
3. **Check "Enable disk use"** under Options
4. **Click Apply**

> **Note:** Without disk use enabled, your iPod mounts as a media device only, and PodCenter won't be able to read or write to its database.

## Step 1: Add Your Music Library

PodCenter needs to know where your music files are stored.

1. Click the **+** button next to "Libraries" in the sidebar
2. Select the folder containing your music
3. PodCenter scans the folder — including subfolders — and imports your tracks

The folder you select becomes a **Library** in PodCenter. We recommend using a single library that points to your main music folder, but you can add multiple libraries if your music is spread across different locations.

### Supported Formats

PodCenter supports these audio formats:

- **MP3** — Universal compatibility
- **AAC / M4A** — iTunes/Apple Music format
- **Apple Lossless (ALAC)** — Lossless audio (may require conversion depending on your iPod)
- **WAV / AIFF** — Uncompressed audio (may require conversion depending on your iPod)
- **FLAC** — Lossless audio (converted automatically for iPod)
- **OGG** — Open format (converted automatically for iPod)

## Step 2: Connect Your iPod

1. **Plug in** your iPod via USB
2. PodCenter **detects it automatically** and shows it in the sidebar
3. **Grant access** when prompted (click "Grant Access" on the iPod row, then approve in the macOS dialog)

Your iPod appears under "Devices" in the sidebar once connected and authorized.

### Supported iPod Models

**Full sync support:**
- iPod Classic (all generations)
- iPod Photo (4th generation)
- iPod Mini (1st and 2nd generation)
- iPod Nano (all generations, 1st–7th)
- iPod Shuffle (1st and 2nd generation)
- Original iPods (1st–4th generation)

**External sync (via Finder):**
- iPod Shuffle (3rd and 4th generation) — PodCenter can convert and prepare files; final transfer uses Finder

> **iPod Touch & iPhone:** PodCenter detects these devices but can't sync directly to them. You can use the **Prepare for External Sync** feature to convert your music into compatible formats, then sync the converted files using Finder or the Music app.

## Step 3: Sync Your Music

There are two ways to get music onto your iPod:

### Drag and Drop

1. **Select tracks** in your library (⌘-click for multiple)
2. **Drag** them to your iPod in the sidebar
3. **Drop** when the iPod row highlights

### Right-Click Menu

1. **Select tracks** in your library
2. **Right-click** on the selection
3. Choose **Sync to [Device Name]**

PodCenter handles format conversion automatically — incompatible formats like FLAC are converted on the fly.

## The Interface

### Sidebar (Left)

- **Libraries** — Your music collections
- **Devices** — Connected iPods

Click the **+** buttons to add libraries or create playlists.

### Main Content Area (Center)

Shows tracks, albums, or artists depending on what you've selected in the sidebar. Click Songs, Albums, or Artists under a library to switch views.

### Inspector Panel (Right)

Shows metadata for selected tracks. Open it with **⌘⌥I** or click the inspector button in the top bar.

Select a track to view its details. You can edit metadata directly in the inspector.

## Next Steps

- **Edit metadata** — Select tracks and use the inspector (⌘⌥I) to edit tags
- **Create playlists** — Click the + button next to "Playlists" in the sidebar
- **Sync playlists** — Right-click a playlist and choose "Sync to [Device]"
- **Customize settings** — Check Settings (⌘,) for conversion quality and other options
