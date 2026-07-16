# ListenBrainz Setup

For an overview of how scrobbling works in PodCenter, see the [Scrobbling guide](guide://scrobbling-setup).

---

## Setup

1. Create an account at [listenbrainz.org](https://listenbrainz.org) (or log in with your MusicBrainz account)
2. Go to your [ListenBrainz settings](https://listenbrainz.org/settings/) and copy your **User Token**
3. In PodCenter, go to **Settings > Services** and turn on **ListenBrainz**
4. Paste your token and click **Connect**

The green indicator means you're good to go. Your token is encrypted and stored in your Mac's Keychain.

---

## Troubleshooting

**"Invalid token"?**
- Head to your [ListenBrainz settings](https://listenbrainz.org/settings/) and make sure the token matches
- If you regenerated the token on the website, the old one won't work anymore. Paste the new one.

**Scrobbles not showing up?**
- ListenBrainz can take a minute or two to process new listens
- Log in to [listenbrainz.org](https://listenbrainz.org) and check your listening history
- In PodCenter, make sure the connection shows green and the scrobbling toggles are on
