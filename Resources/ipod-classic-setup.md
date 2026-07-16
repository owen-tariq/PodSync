# Setting Up iPod Classic (6th & 7th Generation)

iPod Classic 6th and 7th generation models require some extra setup to work properly with third-party software like PodCenter. This guide explains what's happening and how to ensure your Classic works correctly.

## Why Classics Need Special Setup

Unlike older iPods, the 6th and 7th generation Classics use a security feature that verifies the music database. For this verification to work, your iPod needs a special identifier called a **FireWire GUID** stored in its system files.

Without this identifier:
- Music you add may not appear on the iPod
- The iPod might show "No Music" even after syncing
- Database rebuilds might fail

## Automatic Setup

In most cases, PodCenter handles this automatically:

1. **Connect your iPod Classic** via USB
2. **Grant access** when prompted
3. PodCenter **detects the model** and configures everything

If your iPod is working normally, you don't need to do anything else!

## When Manual Setup Is Needed

You may need manual setup if:

- Your iPod was restored/reformatted without iTunes
- PodCenter shows a warning about missing device information
- Music syncs successfully but doesn't appear on the iPod
- You see "Unknown iPod Model" in the device panel

### How to Configure Manually

1. **Select your iPod** in the sidebar
2. Open **Device Settings** (click the gear icon or use the menu)
3. Look for **Model Configuration**
4. Select your **exact model** from the dropdown:
   - iPod Classic 80GB (6th Gen)
   - iPod Classic 120GB (6th Gen)
   - iPod Classic 160GB (6th Gen - thick)
   - iPod Classic 160GB (7th Gen - thin)
5. Click **Apply**

> **Tip:** Not sure which generation? The 7th gen 160GB is noticeably thinner than the 6th gen 160GB.

## Identifying Your iPod Classic

### 6th Generation (2007-2009)

| Capacity | Model Numbers |
|----------|---------------|
| 80GB | MB029 (silver), MB147 (black) |
| 120GB | MB562 (silver), MB565 (black) |
| 160GB (thick) | MB145 (silver), MB150 (black) |

**Characteristics:**
- Thicker body on 160GB model
- Rounded chrome back edges
- Released September 2007 through September 2009

### 7th Generation (2009-2014)

| Capacity | Model Numbers |
|----------|---------------|
| 160GB (thin) | MC293 (silver), MC297 (black) |

**Characteristics:**
- Thinner than 6th gen 160GB
- Same thickness as 6th gen 80GB/120GB
- Released September 2009
- Last iPod Classic produced

### Finding Your Model Number

Your model number is printed in tiny text on the back of your iPod, near the bottom. It starts with "M" (like MB029 or MC297).

> **Note:** Some iPods (especially engraved or personalized models) have a "P" prefix instead of "M" (e.g., PB029 instead of MB029). PodCenter handles this automatically — the hardware is identical.

You can also find it in **About** on the iPod itself:
1. Go to **Settings → About**
2. Scroll down to see the model

## Rebuilding the Database

If your iPod's music library becomes corrupted, you can rebuild it:

1. **Back up any music** on the iPod you want to keep
2. Select the iPod in PodCenter
3. Click **Rebuild Database** in the device panel
4. **Confirm** when prompted
5. Wait for the rebuild to complete
6. **Re-sync** your music

> **Warning:** Rebuilding the database removes all music from the iPod. Make sure you have copies of everything in your library before proceeding.

### What Rebuilding Does

When you rebuild the database, PodCenter:

1. **Creates new system files** with the correct device identifier
2. **Initializes a fresh database** in the format your iPod expects
3. **Sets up the folder structure** for music storage

After rebuilding, your iPod will be empty but ready for syncing.

## Troubleshooting

### "No Music" After Syncing

This usually means the device identifier is missing or incorrect.

**Solution:**
1. Check that PodCenter detected the correct model
2. If shown as "Unknown," configure the model manually
3. Try rebuilding the database

### Model Shows as "Unknown" or "Invalid"

Some 7th generation Classics don't report their model correctly.

**Solution:**
1. Go to Device Settings
2. Manually select "iPod Classic 160GB (7th Gen)"
3. Click Apply

### Admin Password Prompt

When first configuring a Classic, macOS may ask for your administrator password. This is needed to read device identification from USB.

**This is normal** — PodCenter needs to read a special file from your iPod to get the correct identifier.

### Sync Works But Music Disappears After Disconnect

This happens when the database checksum doesn't match what the iPod expects.

**Solution:**
1. Ensure the correct model is selected
2. Rebuild the database
3. Re-sync your music

## Technical Background

For those curious about why Classics are different:

The 6th and 7th generation iPod Classics include a **database verification system**. When the iPod starts up, it calculates a checksum of the music database and compares it to an expected value.

This checksum calculation uses a **unique identifier** (the FireWire GUID) that's specific to each iPod. If the identifier is missing or wrong, the checksum won't match, and the iPod ignores the database.

Older iPods (5th generation "Video" and earlier) don't have this verification system, so they work without any special configuration.

## Still Having Issues?

If your iPod Classic still isn't working correctly after following this guide:

1. **Try a different USB cable** — Some cables don't provide a reliable data connection
2. **Try a different USB port** — Avoid USB hubs; connect directly to your Mac
3. **Check free space** — Ensure your iPod has enough room for the music you're syncing
4. **Restart your iPod** — Hold Menu + Center button for 6-8 seconds until the Apple logo appears
