# Device Permissions

PodCenter needs your permission to access devices like iPods and portable music players. This is a macOS security requirement.

## Why Permission is Required

macOS requires apps to get your explicit permission before accessing external devices. When you connect a device, PodCenter can see it but can't read or write files until you grant access.

## Granting Access

When you see "Permission required" for a device:

1. Click **Grant Access**
2. A file picker opens showing your device's volume
3. Select the appropriate folder and click **Grant Access** in the picker

That's it! PodCenter remembers your permission, so you won't need to do this again for the same device.

### iPods

For iPods, select the **root of the iPod volume** (the folder that opens by default in the picker). PodCenter needs access to the entire iPod to read and write to its music database.

### External Devices (DAPs, USB Drives)

For portable music players and USB drives, you can select either:

- **The root volume** — gives PodCenter access to the entire device
- **A specific music folder** — PodCenter will sync music here and scan this folder for existing tracks

Choose a music folder if you want to keep your synced music organized in a specific location.

## After Granting Access

Once you grant access, PodCenter can:

- **Read** your device's music library
- **Sync** new tracks to the device
- **Edit** metadata on existing tracks
- **Delete** tracks from the device

## If Permission Stops Working

Occasionally macOS may revoke access (after system updates, for example). If your device shows "Permission required" again, just repeat the grant process.
