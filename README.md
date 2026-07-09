# HomeDashboard

A **local-only** smart home dashboard for an old **iPad mini 2** (iOS 12). Controls Philips Hue lights and Sonos speakers over your home Wi-Fi — no cloud, no App Store, no backend server.

Built with **UIKit** (not SwiftUI) so it runs on iOS 12.5.x.

## Requirements

| Item | Details |
|------|---------|
| Device | iPad mini 2 (or any iPad on iOS 12) |
| Mac | Xcode 13.2.1+ on the build Mac (this project targets Xcode 13 format); newer Xcode on your dev Mac is fine for editing |
| Apple ID | Free Personal Team for 7-day sideloading |
| Network | iPad and devices on the same LAN |

> **Note:** Modern Xcode can still *build* for iOS 12 if you set the deployment target manually, but on-device debugging for iOS 12 may be limited. The app will install and run; use `print()` or alerts if you need to debug on the iPad itself.

## Quick Start

1. **Open the project**
   ```
   open /Users/robertgrimes/WebDev/HomeDashboard/HomeDashboard.xcodeproj
   ```

2. **Signing**
   - Select the **HomeDashboard** target → **Signing & Capabilities**
   - Check **Automatically manage signing**
   - Choose your **Personal Team** (free Apple ID)

3. **Connect your iPad mini 2** via USB and select it as the run destination.

4. **Build & Run** (⌘R). Trust the developer profile on the iPad:
   *Settings → General → Device Management → Trust*

5. **Configure devices** in the app’s **Settings** tab (or edit `HomeDashboard/Resources/Config.json` before building).

## Project Structure

```
HomeDashboard/
├── App/                    AppDelegate (iOS 12 window setup)
├── ViewControllers/        Tab bar: Home, Lights, Sonos, Settings
├── Views/                  Reusable cells and tiles
├── Models/                 SmartDevice, DashboardSnapshot
├── Services/
│   ├── LocalHTTPClient     URLSession wrapper for LAN HTTP
│   ├── LightsService       Philips Hue REST API
│   ├── SonosService        Sonos local HTTP / UPnP
│   └── DashboardService    Aggregates devices + auto-refresh
├── Config/                 AppConfig load/save
└── Resources/              Info.plist, Config.json, assets
```

## Device Setup

### Philips Hue

1. Find your bridge IP (router admin or Hue app → Settings → My Bridge).
2. Create an API username (one-time, press bridge button when asked):

   ```bash
   curl -X POST http://<BRIDGE_IP>/api \
     -d '{"devicetype":"HomeDashboard#iPadMini2"}'
   ```

3. Copy the generated `username` into Settings or `Config.json`.

### Sonos

1. Find each speaker’s IP in your router (Sonos app → Settings → About My System also helps on newer setups).
2. Enter comma-separated IPs in Settings, e.g. `192.168.1.101, 192.168.1.102`.

Sonos volume uses the local UPnP API on port **1400**. If volume control fails for your model, check the speaker’s control URL in the Sonos UPnP docs and adjust `SonosService.swift`.

## Free Developer Account (7-Day Cycle)

Apps signed with a free Apple ID expire after **7 days**. When the app stops opening:

1. Connect the iPad to your Mac.
2. Open Xcode → **Product → Run** (⌘R) to re-sign and reinstall.
3. No data is lost — settings live in the app’s Documents folder.

Tip: Keep the iPad plugged in and leave the project ready in Xcode for a quick weekly refresh.

## Security & Privacy

- All requests go to **local IP addresses** only.
- `NSAppTransportSecurity` allows HTTP on your LAN (Hue and Sonos use HTTP).
- No analytics, accounts, or external servers.
- Config is stored on-device only.

## Extending

Add more device types by:

1. Creating a new service in `Services/` (e.g. `TuyaService`, `HomeAssistantService`).
2. Registering it in `DashboardService`.
3. Adding a tab or section in `MainTabBarController`.

[Home Assistant REST API](https://www.home-assistant.io/developers/rest_api/) on your LAN is a good single endpoint if you want one hub for many brands later.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| “Untrusted Developer” | Settings → General → Device Management → Trust |
| App expired | Re-run from Xcode (free account) |
| No lights found | Check bridge IP, username, same Wi-Fi |
| Sonos unreachable | Verify IP, ping from Mac, same subnet |
| Build fails on deployment target | Set **iOS 12.0** manually in target → General |

## License

Personal use — yours to modify.
