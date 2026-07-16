# Last.fm Setup

For an overview of how scrobbling works in PodCenter, see the [Scrobbling guide](guide://scrobbling-setup).

---

## Setup

1. If you don't have a Last.fm account, create one at [last.fm/join](https://www.last.fm/join)
2. In PodCenter, go to **Settings > Services** and turn on **Last.fm**
3. Enter your Last.fm username and password, then click **Connect**

You should see the green indicator once you're connected.

Your password isn't stored anywhere: it gets sent once to Last.fm to get a session key. The session key is what PodCenter actually uses (encrypted in your Keychain). If you disconnect and reconnect later, you'll need to enter your password again.

---

## Troubleshooting

**Authentication failed?**
- Double-check your username and password
- Try your **username** rather than your email. Last.fm's API can be finicky with email login.
- If you recently changed your password on last.fm, make sure you're using the new one

**Session stopped working?**
Last.fm sessions rarely expire, but if yours does, just disconnect and reconnect from Settings > Services.
