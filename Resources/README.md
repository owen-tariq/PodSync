# Selene UX Prototypes

This directory contains interactive UX prototypes for exploring different approaches to Selene metadata matching UI.

## Files

- **`SeleneUXMocks.swift`** - Mock data for testing (realistic scenarios like your "Struggle" track)
- **`SeleneVariantA_InlineExpansion.swift`** - Compact list with inline expansion (like Mail threads)
- **`SeleneVariantB_SideInspector.swift`** - List + detail inspector (like Xcode/Finder)
- **`SeleneVariantC_ThreeColumn.swift`** - Three-panel layout (max info density)
- **`SeleneVariantD_SideBySideMatches.swift`** - Compare top 2 matches side-by-side
- **`SeleneVariantE_DynamicContext.swift`** - Context panel adapts based on match quality
- **`SeleneVariantF_TwoColumn.swift`** - Just list + wide detail (no middle column)
- **`SeleneVariantG_PreviewPlayer.swift`** - Audio preview with playback controls
- **`SeleneVariantH_PickMatch.swift`** - Radio button picker with inline edit search
- **`SeleneUXTestHarness.swift`** - Test harness to switch between all variants

## How to Test

### Option 1: Test Harness (Recommended)
Open the Xcode canvas and use the `SeleneUXTestHarness` preview:
1. Open `SeleneUXTestHarness.swift`
2. Click the canvas preview button
3. Use the segmented control to switch between variants
4. Use the dropdown to test different scenarios

### Option 2: Individual Previews
Each variant file has its own previews at the bottom:
- Open any variant file
- Use Xcode's preview canvas
- Try different preview scenarios

## Test Scenarios

The mock data includes:

1. **Mixed Batch** - 8 tracks with various match qualities
2. **Problematic Match** - Your "Struggle" track (100% confident but wrong artist/album)
3. **Multiple Similar Matches** - "Time" by Pink Floyd with 4 similar versions
4. **No Match Found** - Track that Selene couldn't identify
5. **Perfect Match** - Already correct metadata

## Variant Comparison

### Variant A: Inline Expansion
**Feel:** Lightweight, quick
**Best for:** Batch processing with occasional detailed review
**Pros:** Minimal scrolling, quick overview, expand only what needs attention
**Cons:** Can feel cramped with many alternatives

### Variant B: Side Inspector
**Feel:** Focused, detailed
**Best for:** Careful one-by-one review
**Pros:** Keyboard navigation, plenty of space, easy to see all details
**Cons:** Can only see one track at a time

### Variant C: Three Column (Original)
**Feel:** Information-dense
**Best for:** Side-by-side comparison
**Pros:** All information visible at once
**Cons:** Middle column is redundant (your feedback!)

### Variant D: Side-by-Side Matches
**Feel:** Visual comparison
**Best for:** Choosing between similar options (like Time by Pink Floyd)
**Pros:** Compare top 2 matches visually, large album art placeholders, clear differences
**Cons:** Only shows 2 at a time

### Variant E: Dynamic Context
**Feel:** Adaptive, contextual
**Best for:** Mixed batch with varying confidence
**Pros:** Middle panel shows relevant info (file details when uncertain, similar tracks when confident)
**Cons:** More complexity, panel changes content

### Variant F: Two Column
**Feel:** Clean, spacious
**Best for:** Focus on one track without clutter
**Pros:** No redundant middle column, wider detail panel, expandable alternatives drawer
**Cons:** Alternatives hidden by default

### Variant G: Preview Player
**Feel:** Verification-focused
**Best for:** Generic filenames (Intro, Track 01, etc.)
**Pros:** Play track to verify before accepting, waveform visualization, file details
**Cons:** Requires functional audio preview (mock in prototype)

### Variant H: Pick Match
**Feel:** Simple, choice-focused
**Best for:** When you want to quickly pick from options without cognitive load
**Pros:** Radio buttons (just pick one), all alternatives visible, compact "Changes: Artist, Album" summary, inline edit search with tips
**Cons:** Less detailed comparison view

## Next Steps

1. **Play with the prototypes** - Use the test harness to feel each approach
2. **Note your reactions** - Which feels most natural for your workflow?
3. **Identify edge cases** - What scenarios feel awkward?
4. **Consider hybrid approaches** - Mix features from different variants?

Once you've picked a direction, we'll:
- Write the detailed implementation spec doc
- Plan Selene API changes (if needed)
- Design the "Learn from corrections" feature
- Explore cover art integration

## Notes

- These are prototypes - buttons don't actually do anything
- Mock data is static (changes won't persist)
- SwiftLint rules are disabled (these aren't production code)
- Feel free to tweak and experiment!
