# Summit

A Home Screen "stack" tweak in the spirit of Apex / Zenith / Pinnacle, for iOS 15–16 jailbroken
with **roothide** (written for an iPhone 14 Pro Max on iOS 16.5).

Each app icon can hold up to four child apps (above, below, left and right of it).

| Action | Result |
| --- | --- |
| Swipe up on an icon that has a stack | Children fan out around it; other icons fade |
| Tap a child / the parent | Launches that app |
| Tap anywhere else | Closes the stack |
| Long-press icon → **Create Stack** / **Edit Stack** | Opens the stack editor |
| Swipe up on an icon in jiggle mode | Opens the stack editor |
| In the editor: tap **+** | Pick an app (searchable list) |
| In the editor: tap an app | Removes it from the stack |

Settings → **Summit**: enable/disable, app names, haptics, fade amount, fade duration, icon move
duration, spring damping, spring initial velocity, reset all stacks, respring.

## Files

- `Tweak.x` – SpringBoard hooks on `SBIconView` (swipe gesture + long-press quick action)
- `SMTStackOverlay.m` – the fan-out overlay and editor
- `SMTAppPicker.m` – app chooser
- `SMTStore.m` – settings and stacks (`com.adarsh.summit` preferences domain)
- `summitprefs/` – Settings pane

## Building on Windows (via WSL)

roothide packages need the **roothide fork of Theos**, which runs on Linux/macOS. On Windows use WSL:

1. In PowerShell (admin): `wsl --install -d Ubuntu`, reboot, open Ubuntu.
2. Install roothide Theos:
   ```bash
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/roothide/theos/master/bin/install-theos)"
   ```
   This installs Theos to `~/theos`, the iOS toolchain and SDKs. Make sure `THEOS` is exported
   (`echo 'export THEOS=~/theos' >> ~/.bashrc`).
3. Copy this folder into WSL (e.g. `cp -r /mnt/c/path/to/Summit ~/Summit`) and build:
   ```bash
   cd ~/Summit && make clean package FINALPACKAGE=1
   ```
4. The `.deb` (architecture `iphoneos-arm64e`) lands in `packages/`.

## Installing

- Copy the `.deb` to the phone (AirDrop / Files) and open it with Sileo or Zebra from the
  roothide Bootstrap, **or**
- over SSH: `make do THEOS_DEVICE_IP=<phone-ip>` (needs OpenSSH installed from the Bootstrap).

SpringBoard tweak injection is on by default in roothide Bootstrap; respring after installing.

## Notes

- `TARGET` uses `latest` so it builds with whatever SDK Theos installed (16.x or newer is fine).
- Private APIs used: `SBIconView`, `SBSApplicationShortcutItem`, `LSApplicationWorkspace`,
  `+[UIImage _applicationIconImageForBundleIdentifier:format:scale:]`. If an icon looks blurry,
  try a different value for `kSMTHomeIconFormat` in `SMTStackOverlay.m`.
- Change `com.adarsh.summit` everywhere if you want a different package ID.
