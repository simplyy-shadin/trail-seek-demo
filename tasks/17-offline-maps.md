# 17 · Offline maps

**Status:** done in code (2026-10-18). Airplane-mode check and the ±20 % size-estimate check wait for the Pixel; auto-download of upcoming group treks on Wi-Fi not built; tile provider must change before beta (OSM policy). · **Size:** M · **Depends on:** 09

## Goal
Trailheads have no signal. Map tiles for a trek must be on the phone before the user leaves home.

## Scope
- Tile cache for flutter_map (`flutter_map_tile_caching` or a small custom `TileProvider` over `sqflite`), honouring OSM tile usage policy (bulk download limits, attribution, user-agent).
- "Download for offline" on the adventure detail: bounding box around the trail with 3 km padding, zoom 12–16, size estimate before download, progress, cancel.
- Settings → Offline Maps: list of downloaded areas, size, delete, "auto-download upcoming group treks on Wi-Fi".
- Pre-start checklist item "Offline maps" becomes real (currently a stub).
- Fallback: when tiles are missing offline, draw the route on a plain dark canvas so tracking still works.

## Acceptance
- Download Chembra Peak area on Wi-Fi, enable airplane mode, open live tracking: tiles render at zoom 14–16.
- Download size shown within ±20 % of actual.
- Total cache capped (default 1 GB) with least-recently-used eviction.

## Implementation notes
- Consider a self-hosted or paid tile source before public beta: OSM's public tile servers forbid heavy bulk downloads. Budget line "Maps / location API ₹0–5,000" covers a MapTiler/Stadia free tier.
