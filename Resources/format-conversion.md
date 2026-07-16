# Metadata & Format Conversion

PodCenter preserves your track's metadata (title, artist, album, artwork, etc.) during conversion. However, some metadata fields are format-specific and can't be transferred between all formats.

## What's Always Preserved

These fields are supported by all audio formats and are always preserved:

- Title, Artist, Album, Album Artist
- Track Number, Disc Number
- Year, Genre, Composer
- BPM
- Comments
- Artwork

## Format-Specific Limitations

Some metadata fields only exist in certain formats:

| Field | AAC/ALAC | MP3 | FLAC |
|-------|----------|-----|------|
| Copyright | Yes | Yes | Yes |
| Content Rating (Explicit/Clean) | Yes | Yes | Yes |
| Star Rating | No | Yes | Yes |

## What This Means for Conversions

**Converting FLAC to AAC:**
- Copyright **is preserved**
- Star ratings are **not preserved** (AAC doesn't support star ratings)

**Converting FLAC to MP3:**
- Copyright **is preserved**
- Star ratings **are preserved**

**Converting AAC/ALAC to MP3:**
- Content Rating (Explicit/Clean) **is preserved**
- Copyright **is preserved**

**Converting MP3 to AAC:**
- Most MP3 metadata **is preserved**
- Star ratings are **not preserved** (AAC doesn't support star ratings)

**Converting between AAC and ALAC:**
- **All metadata is preserved** - these formats share the same container

## Library vs. File Metadata

It's important to understand the difference:

- **Library metadata** is what PodCenter stores in its database
- **File metadata** is what's embedded in the audio file itself

When a field can't be written to a converted file (like star ratings on AAC), the data still exists in your PodCenter library. It just won't be embedded in the converted file itself.

**Note:** Star ratings always sync to your iPod regardless of format, because iPod sync uses the database - not the audio files - for ratings.

## Tips

- **Use AAC for best metadata support** - It preserves the most metadata fields
- **Keep your original files** - Format conversion always creates a new file and never modifies your source audio
- **Check the Inspector** - View a track's metadata before and after conversion
- **Rely on Explicit/Clean tags?** Content Rating is preserved across all supported formats
