# 15 · Settings

**Status:** done (2026-10-18; policy/terms URLs are placeholders until the domain exists; blocked users and push toggles become live with tasks 13 and 16) · **Size:** S · **Depends on:** 01, 02

## Goal
Frame 14: Account & Profile, Notifications, Privacy & Security, Offline Maps, Units, Help & Support, About.

## Scope
- Account & Profile: username, email, change password (16), edit avatar (04), delete account (16; local wipe now).
- Notifications: group alerts, community activity, weekly summary (local toggles; push arrives with 16).
- Privacy & Security: location sharing in groups (on/off, default on during a session only), community visibility (public/followers), blocked users, data export (11), community guidelines, privacy policy + terms (web links).
- Offline Maps: entry to 17; shows downloaded regions and storage used.
- Units: Metric / Imperial, applied via a `UnitsFormatter` used by every distance/elevation label.
- Help & Support: FAQ, contact email, "Experimental companion tool" safety notice (moved from Profile).
- About: version, licences (`showLicensePage`), credits for map data (OpenStreetMap attribution is mandatory).

## Acceptance
- Switching to Imperial updates Home, Explore, Summary and History labels immediately.
- OSM attribution is visible on every map screen (flutter_map `RichAttributionWidget`).
