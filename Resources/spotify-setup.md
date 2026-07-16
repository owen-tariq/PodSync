# Spotify Setup Guide

PodCenter uses the **Bring Your Own Key (BYOK)** pattern for Spotify integration. This means you create your own Spotify Developer app and provide its credentials to PodCenter. This takes about 5 minutes and gives you full control over your data.

## Requirements

- **Spotify Premium** — The Spotify account you use to create the Developer app must have an active Premium subscription (Family or Duo plans count). The app will stop working if your Premium lapses.

## Why BYOK?

Spotify limits Development Mode apps to 5 authorized users. By using your own developer app, you're the only user—no limits apply.

## Step-by-Step Setup

### 1. Open Spotify Developer Dashboard

Go to [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard) and sign in with your Spotify account.

### 2. Create a New App

1. Click **"Create App"**
2. Fill in the form:
   - **App name:** Anything you like (e.g., "PodCenter")
   - **App description:** Anything (e.g., "Personal use")
   - **Redirect URI:** Copy this exactly:
     ```
     podcenter://spotify-callback
     ```
3. Check the **"Web API"** checkbox
4. Accept the Developer Terms of Service
5. Click **"Save"**

### 3. Copy Your Client ID

1. On your new app's page, find the **Client ID** (a 32-character code)
2. Click the copy button or select and copy it
3. Keep this page open—you'll paste it into PodCenter next

### 4. Configure and Connect

1. Open **PodCenter Settings** (⌘,)
2. Go to the **Services** tab
3. Enable **Spotify**
4. Paste your **Client ID** into the field
5. Click **"Connect"** — this saves your credentials and opens Spotify's authorization page
6. Review the permissions and click **"Agree"**
7. You'll be redirected back to PodCenter
8. You should see **Connected as [your name]**

## Troubleshooting

### "Redirect URI not registered"

The redirect URI in your Spotify app doesn't match. Make sure it's exactly:
```
podcenter://spotify-callback
```
No trailing slash, all lowercase.

### "Invalid Client ID"

- Client IDs are 32 hexadecimal characters (letters a-f and numbers 0-9)
- Make sure you copied the **Client ID**, not the Client Secret
- Check for extra spaces when pasting

### Connection Fails Silently

- Make sure you checked **"Web API"** when creating the app
- New Spotify developer accounts may take 5-10 minutes to activate
- Try disconnecting and reconnecting

### "INVALID_CLIENT: Invalid redirect URI"

Your Spotify app's redirect URI doesn't match. In the Spotify Dashboard:
1. Click **"Edit Settings"**
2. Under **Redirect URIs**, make sure you have exactly:
   ```
   podcenter://spotify-callback
   ```
3. Click **"Save"**

## What Permissions Does PodCenter Request?

| Permission | Purpose |
|------------|---------|
| View your Spotify account data | Display your username |
| Access your private playlists | Read your playlists for comparison |
| Access your collaborative playlists | Include shared playlists |
| Access your saved content | Read your liked songs and albums |

PodCenter only **reads** your data—it cannot modify your playlists or account.

## Security Notes

- Your Client ID is stored securely in macOS Keychain
- PodCenter uses the PKCE OAuth flow (no client secret stored)
- You can revoke access anytime at [spotify.com/account/apps](https://www.spotify.com/account/apps/)
- Deleting your Spotify Developer app immediately revokes PodCenter's access

## Disconnecting

To disconnect Spotify from PodCenter, open **Settings** → **Services**. When connected, two buttons are available:

- **Disconnect** — ends the current session but keeps your saved Client ID, so you can reconnect without re-entering it.
- **Clear Credentials** — removes the stored Client ID entirely. You'll need to paste it again to reconnect.

To fully revoke access, also visit [spotify.com/account/apps](https://www.spotify.com/account/apps/) and remove the app.

## March 2026 API Changes

Spotify enforced new Development Mode restrictions on March 9, 2026. If you set up PodCenter before this date:

- **Premium is now required** for the developer account that owns the app
- **Search results** are now limited to 10 per request (reduced from 50)
- **ISRC codes** are no longer returned, so track matching uses metadata comparison instead
- **Permissions reduced** — PodCenter no longer requests email or recently-played access

No action is needed on your part — PodCenter handles these changes automatically. If you experience issues, try disconnecting and reconnecting Spotify in Settings.
