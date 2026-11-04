# Getting Trail Seek onto iPhones

## What xtool can and cannot do

[xtool](https://xtool.sh) is a Linux/Windows replacement for Xcode, but it builds **Swift Package
Manager** apps only. Flutter's iOS build (`flutter build ios`) drives Xcode's `xcodebuild` against
`ios/Runner.xcworkspace`, links the Flutter engine, and runs CocoaPods for the plugins (Bluetooth,
maps, ML Kit, camera). None of that goes through xtool, so xtool cannot produce this app. Flutter
itself refuses to build iOS on Linux ("Building for iOS is only supported on macOS").

## What works instead: GitHub's macOS runners

`.github/workflows/ios.yml` builds the app on a hosted Mac with Xcode installed. Run it from the
repo's **Actions** tab (*iOS build → Run workflow*), or push a `v*` tag.

Two modes:

| Mode | Needs | Output | Install on iPhone |
|---|---|---|---|
| Unsigned (default) | nothing | `trailseek-unsigned.ipa` artifact | **Sideloadly** (Windows/Mac) or **AltStore** with a free Apple ID; the app expires after 7 days, re-sideload to renew. Up to 3 apps per free ID. |
| Signed | Apple Developer Program (₹8,000/year) + 4 repository secrets | App Store Connect-ready `.ipa` | **TestFlight** (up to 10,000 testers, 90-day builds), then the App Store |

Secrets for signed mode (Settings → Secrets and variables → Actions):
`IOS_P12_BASE64`, `IOS_P12_PASSWORD`, `IOS_PROFILE_BASE64`, `IOS_TEAM_ID`.
Create the certificate and an App Store provisioning profile for `com.trailseek.trailseek` at
developer.apple.com, export the certificate as `.p12`, and `base64 -w0 file` each one.

Minutes: the repo is private, so macOS runner minutes count 10× against the free 2,000/month,
roughly 8 builds a month. Making the repo public makes the runs free.

## iOS-specific checks still owed

- `ios/Runner/Info.plist` already declares Bluetooth, location and background modes for the
  Digital Rope; camera and photo-library strings are needed for the avatar and post photos.
- Digital Rope on iOS: iOS strips the advertisement name in the background, so a locked iPhone is
  invisible on the heartbeat path and relies on the GATT roster sync (see PLAN.md §3.4). The first
  iPhone test should be the screen-locked scenario.
- Sign in with Apple is mandatory on the App Store once Google sign-in is offered; the cloud auth
  repository already implements it, but it needs the capability on the App ID.
