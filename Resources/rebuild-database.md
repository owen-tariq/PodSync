# Rebuilding the iPod Database

The "Rebuild Database" feature scans your iPod for audio files and recreates the database from scratch using the metadata embedded in those files.

## When to Use This

Use this feature if:

- **Tracks appear in Finder but not in PodCenter** - Files exist on your iPod but aren't showing up in the track list
- **Database corruption** - Your iPod's database became corrupted and can't be read properly
- **Third-party sync issues** - Another app synced files without properly updating the database
- **Orphaned files** - Audio files were copied to the iPod manually without database entries

## What Happens

When you rebuild the database:

1. PodCenter scans the `iPod_Control/Music` folder for audio files
2. The existing database entries are cleared (but files are kept)
3. Each audio file is read and its embedded metadata is extracted
4. New database entries are created from the file metadata
5. The iPod database is saved with the rebuilt track list

## Important Notes

- **Your audio files are NOT deleted** - Only database entries are cleared and rebuilt
- **Metadata comes from files** - Track info is read from embedded metadata, not the old database
- **Playlists are lost** - Playlist associations cannot be recovered from files alone
- **This may take a few minutes** - Large libraries require time to scan and rebuild

## When NOT to Use This

Don't use this feature if:

- Your tracks are showing up correctly and everything is working
- You want to clear the iPod completely (use "Clear iPod" instead)
- You're trying to add new music (just sync normally)

## After Rebuilding

Once the rebuild completes:

- Check that your tracks appear in PodCenter
- Verify track metadata looks correct
- Re-create any playlists you need
- Eject and reconnect if tracks don't appear on the iPod itself
