# 19 · iOS build + TestFlight

**Status:** todo · **Size:** M · **Depends on:** 01 · **Needs:** a Mac with Xcode and an Apple Developer account

## Goal
The same app running on an iPhone, shipped to internal testers via TestFlight.

## Scope
- `flutter build ios` on a Mac; fix any plugin pod/SPM issues (bluetooth_low_energy, mobile_scanner, geolocator, share_plus).
- Signing: bundle id `com.trailseek.trailseek`, team, capabilities: Background Modes (bluetooth-central, bluetooth-peripheral, location), Push (16), Sign in with Apple (03).
- Info.plist strings reviewed for App Review (already present; make them specific).
- App icon set already generated; add launch screen matching the splash.
- Run on a physical iPhone: smoke the full flow, record one GPS activity, one demo Digital Rope session.
- TestFlight internal group with the team; crash-free session check.

## Acceptance
- Build archives without warnings about missing usage descriptions or background modes.
- Digital Rope demo mode runs on the iPhone; BLE mode starts advertising (verified from an Android scanner app).
- TestFlight build installed on at least two iPhones.
