# PhoneMic

Turn your iPhone into a wireless PC microphone over WiFi. No cable, no Bluetooth
limitations, and the mic never drops when other audio plays on your phone.

## What's in this project
- `Sources/PhoneMic/` — the iOS app (Swift/SwiftUI)
- `.github/workflows/build-ipa.yml` — builds the iPhone app into an .ipa automatically (no Mac needed)
- `.github/workflows/build-installer.yml` — builds the Windows **one-click installer** automatically
- `pc/` — the Windows receiver app + installer script

## Part 1: Build the Windows installer (do this first)

1. Create a free GitHub account if you don't have one, and create a new **private** repository.
2. Upload this entire `PhoneMic` folder to that repository (drag-and-drop on github.com works, or use GitHub Desktop — no terminal needed).
3. On your repo page, click the **Actions** tab.
4. Click **"Build PC Installer"** on the left, then click **"Run workflow"** → **Run workflow** (green button).
5. Wait ~3-5 minutes for it to finish (green checkmark).
6. Click into the finished run, scroll down to **Artifacts**, and download **PhoneMic-Setup**. Unzip it — you'll get `PhoneMic-Setup.exe`.
7. Double-click `PhoneMic-Setup.exe` on your PC. Click Next through the wizard (it will ask for admin permission — that's needed to install the virtual mic driver). It installs everything: the virtual microphone driver + the receiver app. No command line at any point.
8. After install, the **PhoneMic Receiver** window opens automatically and shows something like:
   `Listening on 192.168.1.23:50505 — enter this IP in the iPhone app`
   **Write down that IP address** — you'll need it in the iPhone app.

## Part 2: Build the iPhone app

1. In the same GitHub repo, go to **Actions** → **"Build PhoneMic IPA"** → **Run workflow**.
2. Wait ~3-5 minutes, then download the **PhoneMic-ipa** artifact and unzip it to get `PhoneMic.ipa`.
3. On your Windows PC, download and install **Sideloadly** (free): https://sideloadly.io
4. Connect your iPhone to the PC with a USB cable (only needed for this one-time install step).
5. Open Sideloadly, drag `PhoneMic.ipa` into it, enter your Apple ID when asked, and click Start. It installs the app on your phone.
6. On your iPhone: **Settings → General → VPN & Device Management** → trust your Apple ID's developer profile (one-time step iOS requires for sideloaded apps).
7. Note: free Apple ID sideloads expire after 7 days — you'll just re-run Sideloadly with the same IPA to refresh it. A paid $99/year Apple Developer account removes that limit.

## Part 3: Use it

1. Make sure your iPhone and PC are on the **same WiFi network**.
2. On your PC, run the **PhoneMic Receiver** (auto-starts if you kept that option; otherwise from the Start Menu).
3. On your iPhone, open **PhoneMic**, type in the PC's IP address it showed you, tap **Start Streaming**.
4. In whatever app you want to use the mic in on your PC (Discord, OBS, Zoom, etc.), pick **"CABLE Output (VB-Audio Virtual Cable)"** as the microphone input.
5. Talk — audio from your phone streams straight into that app. Playing music, getting notifications, or taking calls on your phone will duck other audio automatically instead of cutting the stream.

## Notes / limitations
- Both devices must stay on the same WiFi network (or a phone hotspot the PC joins).
- One phone connects at a time.
- If your PC's IP address changes (e.g. after a router restart), just re-check the receiver window for the new IP.
