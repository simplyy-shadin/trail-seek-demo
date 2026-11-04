# 23 · Thrissur pivot: Forest Department programmes

**Status:** in progress (data, screens and in-app booking done; cloud community and iOS pipeline in place, need the Supabase anon key in the builds and a Mac runner run)

## Decision (2026-10-27)
Collaboration with the government in Thrissur district. The app now shows **only Thrissur** eco-tourism:
the Forest Department's destinations and every programme they run, with the official rates, **booked inside
Trail Seek** (date, slot, party, dummy payment, QR ticket, stored in our database). The operator's own booking
channel is never mentioned in the app; bookings will be pushed to the operator's API once access is granted.

## Data pipeline
- `tools/thrissur/build_data.py` pulls every Thrissur slot from the Kerala Forest Department ecotourism
  booking API (the same API the public portal calls), merges curated text from `curated.py` and the photo
  lists from `images.json`, and writes `assets/data/thrissur.json`. Re-run it to refresh prices.
- `tools/thrissur/images.py` converts the chosen photos (KFD portal, Vazhachal division site, Wikimedia
  Commons) into `assets/images/thrissur/` with credits.
- 4 destinations: Athirappilly–Vazhachal, Peechi–Vazhani, Chimmony, Chulannur. 22 programmes
  (treks, coracle rides, cycling, falls entry, stays). Portal-sourced ones are `verified: true`;
  the Anaporu camp (older Kerala Tourism listing) is flagged "confirm by phone".

## Screens
- Home: search, destination strip with photos, programme-type bar, cards with price and status.
- Programme detail: photo gallery, price card (package / per person / entry / vehicle / camera), timings
  and group size, map, Overview / Getting there / Safety / Carry, **Book** button.
- Booking: date strip (30–60 days), slots from the programme timing, party steppers (adult / child / student /
  foreign), parking and camera add-ons, live quote; simulated payment (UPI / card / net banking); ticket with
  QR and 6-character code; My bookings (Profile) and a "Next trip" banner on Home; cancel with 48 h rule.
- Destination page. No credits page (photos are public / government material per the client).

## Open
- [ ] Supabase anon key into app and website builds (docs/backend-setup.md).
- [ ] Run the iOS workflow once; sideload on an iPhone (docs/ios-build.md).
- [ ] Operator API: push confirmed bookings and read live capacity once the department grants access (field `operatorSynced`).
- [ ] Payment gateway (Razorpay / Cashfree) replacing the simulated step; refunds for the 48 h rule.
- [ ] Nearby places (Thumboormuzhi, Charpa) as their own entries with DTPC/Irrigation fees once confirmed.
- [ ] Malayalam text for the programme pages.
