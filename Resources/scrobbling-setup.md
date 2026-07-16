# Scrobbling

PodCenter can send your listening history to **Last.fm** and **ListenBrainz**, whether you're playing music directly or syncing from an iPod.

## How it works

There are three ways scrobbles get sent:

- **PodCenter playback**: when you listen to a track in PodCenter, it gets scrobbled once you've heard at least half of it (or 4 minutes, whichever comes first). Anything under 30 seconds is ignored.
- **iPod play history**: each time you connect your iPod, PodCenter checks which tracks have new plays since last time and scrobbles them.
- **Rockbox scrobble log**: if your iPod runs Rockbox with the Last.fm Scrobbler plugin, PodCenter can import the scrobble log directly (see below).

## Getting started

Pick one or both services and follow the setup guide:

- [Last.fm Setup Guide](guide://lastfm-setup)
- [ListenBrainz Setup Guide](guide://listenbrainz-setup)

Once connected, head to **Settings > Services** to choose what gets scrobbled: PodCenter playback, iPod play history, or both.

## How iPod scrobbling works

PodCenter keeps track of the play count for every song on each iPod. When you reconnect, it compares the current counts against what it saw last time and scrobbles the difference. Timestamps are estimated by spacing plays backwards from the "last played" date using the track's duration.

The first time you connect an iPod with scrobbling enabled, all existing plays get scrobbled. You can also manually trigger a scrobble sync from the iPod overview or the sidebar context menu.

## Last.fm timestamp limit

Last.fm silently rejects scrobbles with timestamps older than 2 weeks. This can be an issue when:

- You connect an iPod for the first time and it has months of play history
- You haven't connected your iPod in a while and plays have accumulated

By default, PodCenter has **"Adjust old timestamps for Last.fm"** enabled (in Settings, under the Last.fm connection). This shifts old timestamps forward so Last.fm accepts them. The plays will show up with approximate dates rather than the original ones.

If you'd rather keep the real timestamps (knowing Last.fm will drop the old ones), you can turn this off. ListenBrainz has no timestamp limit, so it always receives the real timestamps regardless of this setting.

## Rockbox scrobbling

If your iPod runs Rockbox and you have the **Last.fm Scrobbler** plugin enabled in Rockbox, PodCenter can import your scrobble log directly.

Rockbox writes a `.scrobbler.log` file to the root of your iPod whenever you listen to music. When you connect your iPod, PodCenter detects this file and shows how many scrobbles are ready to import in the Rockbox sidebar entry's overview.

To import:

1. Connect your iPod
2. Select the **[iPod Name] (Rockbox)** entry in the sidebar
3. Click **Import Scrobbles** in the Scrobble Log card
4. PodCenter reads the log, sends the scrobbles to your connected services, and archives the file

You can also right-click the Rockbox entry in the sidebar and choose **Import Scrobble Log**.

Unlike iPod scrobbling (which estimates timestamps from play counts), Rockbox scrobbles have real timestamps recorded at the moment of playback — so your Last.fm and ListenBrainz histories will be accurate.

> **Note:** Make sure the Last.fm Scrobbler plugin is running in Rockbox (Plugins > Apps > Last.fm Scrobbler). It runs in the background and writes to the log as you listen.

## Pending Scrobbles

If scrobbles fail to send (network issues, service downtime, etc.), they're saved to a queue and retried automatically. You can view and manage this queue in the **Pending Scrobbles** window.

To open it:

- **Window > Pending Scrobbles** (⌘2) in the menu bar
- Or click **Manage…** next to the pending scrobbles row in Settings > Services (the row only appears when scrobbles are queued)

The Pending Scrobbles window shows:

- All queued scrobbles with track info, timestamp, and target service
- Which services each entry is still pending for
- Error details for failed entries (select an entry to see the error)

From this window you can:

- **Retry** failed scrobbles
- **Delete** entries you don't want to send
- **Select and inspect** individual entries for error details

## Something not working?

- If scrobbles aren't showing up, check **Window > Pending Scrobbles** for a pending queue and errors.
- Make sure the service shows a green dot (connected) in Settings > Services and that the relevant toggle is on.
- Getting duplicates? Check whether you have another scrobbler running (browser extension, phone app, etc.)
- Old plays missing from Last.fm? Make sure "Adjust old timestamps for Last.fm" is enabled in Settings.
