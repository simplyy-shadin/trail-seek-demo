#!/usr/bin/env python3
"""Builds assets/data/thrissur.json from the Kerala Forest Department ecotourism
booking API plus curated text in curated.py.

Run from the repo root:  python3 tools/thrissur/build_data.py [--offline]

The API is the same one the public booking portal (ecotourism.forest.kerala.gov.in)
calls from the browser; prices, timings, group sizes, contacts and booking status
come from there verbatim. Everything else (safety, gear, how to reach, nearby
places) is curated in curated.py and marked as such in the output.
"""
import json, os, re, sys, html, urllib.request, urllib.parse, urllib.error, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import curated  # noqa: E402

IMAGES_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'images.json')
IMAGES = json.load(open(IMAGES_FILE)) if os.path.exists(IMAGES_FILE) else {'destinations': {}, 'programs': {}, 'credits': []}

API = 'https://api-ecotourism.forest.kerala.gov.in/api/'
CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'cache')
PACKAGE_IDS = [1, 3, 4, 5, 7, 9, 11, 12, 14, 57, 58, 66, 67, 74, 75, 76, 77, 78, 82, 84, 85, 86, 87, 89, 91]
DISTRICT = 'Thrissur'
OFFLINE = '--offline' in sys.argv


def api(path):
    os.makedirs(CACHE, exist_ok=True)
    f = os.path.join(CACHE, path.replace('/', '_') + '.json')
    if OFFLINE:
        return json.load(open(f)) if os.path.exists(f) else {}
    try:
        req = urllib.request.Request(API + path, headers={'User-Agent': 'TrailSeek data builder'})
        data = json.load(urllib.request.urlopen(req, timeout=60))
        json.dump(data, open(f, 'w'), ensure_ascii=False)
        return data
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return {}
        if os.path.exists(f):
            print('  (cache)', path, e)
            return json.load(open(f))
        raise
    except Exception as e:  # fall back to cache
        if os.path.exists(f):
            print('  (cache)', path, e)
            return json.load(open(f))
        raise


def strip_html(s):
    return re.sub(r'\s+', ' ', re.sub('<[^>]+>', ' ', html.unescape(s or ''))).strip()


def parse_fees(conditions):
    pricing = {'entryFees': {}, 'vehicleFees': {}, 'cameraFees': {}}
    for h in conditions or []:
        if not isinstance(h, dict):
            continue
        head = (h.get('head_name') or '').strip()
        for sh in h.get('subheads') or []:
            if not isinstance(sh, dict):
                continue
            sub = (sh.get('subhead_name') or '').strip()
            for c in sh.get('conditions') or []:
                if not isinstance(c, dict):
                    continue
                name = (c.get('condition_name') or '').strip()
                amt = c.get('condition_amount')
                if amt is None:
                    continue
                amt = int(amt)
                key = re.sub(r'\s+', ' ', sub)
                if head == 'Entry Fee':
                    if 'Package' in sub or 'Package' in name or sub == 'entry fee' and 'Package' in name:
                        pricing['packageAmount'] = amt
                    elif sub == 'entry fee' and 'per person' in name.lower():
                        pricing['perPerson'] = amt
                    elif 'Indian Adult' in sub and 'Trekking' in name:
                        pricing['perPersonIndian'] = amt
                    elif 'Foreign Adult' in sub and 'Trekking' in name:
                        pricing['perPersonForeign'] = amt
                    else:
                        pricing['entryFees'][key] = amt
                elif head.startswith('Additional'):
                    pricing['additionalPerPerson'] = amt
                elif head == 'Common Entry Fee':
                    pricing['entryFees'][key] = amt
                elif head.startswith('Vehicle'):
                    pricing['vehicleFees'][key] = amt
                elif 'Camera' in head:
                    pricing['cameraFees'][key.replace('  ', ' ')] = amt
    return pricing


def latlng_from_embed(link):
    if not link:
        return None
    m2 = re.search(r'!2d([\d.]+)', link)
    m3 = re.search(r'!3d([\d.]+)', link)
    if m2 and m3:
        return (float(m3.group(1)), float(m2.group(1)))
    return None


def main():
    print('Fetching Thrissur slots from the KFD ecotourism API…')
    slots = {}
    for p in PACKAGE_IDS:
        d = api(f'getDetailsByPackage/{p}')
        data = d.get('data') or {}
        for ec in data.get('eco_centers', []):
            if (ec.get('districtname') or '') == DISTRICT:
                slots[ec['slot_id']] = {'package': data.get('package_name'), 'ecocenter_id': ec.get('ecocenter_id'), 'ecocenter_name': ec.get('ecocenter_name'), 'division': ec.get('division_name')}
    details = {}
    for sid in sorted(slots):
        details[sid] = api(f'slotmasterdetailsbyid/{sid}')['data']
    centres = {c['id']: c for c in api(f'ecocenteresbydistrict/28')['data']}
    today = datetime.date.today().isoformat()

    programs = []
    for sid, d in details.items():
        cur = curated.PROGRAMS.get(sid)
        if cur is None:
            print('  no curated entry for slot', sid, d.get('name'), d.get('package_name'), '- skipped')
            continue
        dest = curated.DESTINATIONS[cur['destinationId']]
        pricing = parse_fees(d.get('conditions'))
        pricing['packageCovers'] = d.get('maxperson')
        pricing.update(cur.get('pricingExtra', {}))
        ll = latlng_from_embed(d.get('location_link')) or ((cur['lat'], cur['lng']) if cur.get('lat') else (dest['lat'], dest['lng']))
        reason = (d.get('reason') or '').lower()
        availability = 'closed' if 'closed' in reason else 'soon' if 'not started' in reason else cur.get('availability', 'open')
        booking = {
            'availability': availability,
            'bookingWindowDays': max(int(d.get('advance_date') or 0), 30),
            'capacityPerDay': d.get('noof_tickets_to_be_issued'),
        }
        prog = {
            # --- Adventure shape (kept so group / rope / tracking flows work unchanged)
            'id': cur['id'],
            'name': cur.get('name') or d.get('package_name'),
            'regionId': 'thrissur',
            'district': 'Thrissur',
            'nearestTown': dest['nearestTown'],
            'categories': cur['categories'],
            'difficulty': cur.get('difficulty', 'moderate'),
            'distanceKm': cur.get('distanceKm', 0),
            'durationHours': cur.get('durationHours', [1, 2]),
            'elevationM': dest['elevationM'],
            'elevationGainM': cur.get('elevationGainM', 0),
            'terrain': cur.get('terrain', dest['terrain']),
            'bestSeason': cur.get('bestSeason', dest['bestSeason']),
            'entryFee': cur.get('entryFeeLabel') or curated.fee_label(pricing),
            'permit': cur.get('permit', 'Trail Seek ticket, shown at the gate; carry a government photo ID'),
            'guideRequired': cur.get('guideRequired', True),
            'howToReach': dest['howToReach'],
            'parking': dest['parking'],
            'network': dest['network'],
            'facilities': cur.get('facilities', dest['facilities']),
            'waterAvailability': cur.get('water', dest['water']),
            'emergencyContacts': dest['emergencyContacts'],
            'risks': cur.get('risks', dest['risks']),
            'dangerousSections': cur.get('dangerousSections', []),
            'wildlife': cur.get('wildlife', dest['wildlife']),
            'gear': cur.get('gear', curated.GEAR[cur['gearKind']]),
            'suitability': cur.get('suitability', {'beginner': cur.get('difficulty', 'moderate') == 'easy', 'family': cur['gearKind'] != 'trek', 'group': True}),
            'checklist': cur.get('checklist', curated.CHECKLIST[cur['gearKind']]),
            'precautions': cur.get('precautions', dest['precautions']),
            'highlights': cur['highlights'],
            'lat': ll[0], 'lng': ll[1],
            'coverHue': dest['coverHue'],
            'verified': True,
            # --- Programme extras
            'destinationId': cur['destinationId'],
            'destinationName': dest['name'],
            'programType': cur['programType'],
            'summary': cur['summary'],
            'description': cur.get('description') or strip_html(d.get('detailed_description')) or d.get('description') or '',
            'officialDescription': '',
            'images': IMAGES['programs'].get(cur['id'], []),
            'pricing': pricing,
            'timing': {'open': d.get('opening_time'), 'close': d.get('closing_time'), 'startTime': cur.get('startTime'), 'note': cur.get('timingNote')},
            'minPersons': d.get('minperson'),
            'maxPersons': d.get('maxperson'),
            'maxAdditional': d.get('max_additional'),
            'inclusions': cur.get('inclusions', []),
            'booking': booking,
        }
        programs.append(prog)

    # Curated-only programmes (not on the online portal today).
    for extra in curated.EXTRA_PROGRAMS:
        dest = curated.DESTINATIONS[extra['destinationId']]
        base = {
            'regionId': 'thrissur', 'district': 'Thrissur', 'nearestTown': dest['nearestTown'], 'elevationM': dest['elevationM'],
            'terrain': dest['terrain'], 'bestSeason': dest['bestSeason'], 'howToReach': dest['howToReach'], 'parking': dest['parking'],
            'network': dest['network'], 'facilities': dest['facilities'], 'waterAvailability': dest['water'], 'emergencyContacts': dest['emergencyContacts'],
            'risks': dest['risks'], 'dangerousSections': [], 'wildlife': dest['wildlife'], 'precautions': dest['precautions'], 'coverHue': dest['coverHue'],
            'destinationName': dest['name'],
        }
        base.update(extra)
        base.setdefault('gear', curated.GEAR[extra['gearKind']])
        base.setdefault('checklist', curated.CHECKLIST[extra['gearKind']])
        base.setdefault('suitability', {'beginner': False, 'family': False, 'group': True})
        base.setdefault('images', IMAGES['programs'].get(extra['id'], []))
        base.setdefault('inclusions', [])
        base.setdefault('maxAdditional', None)
        base.setdefault('officialDescription', '')
        base.setdefault('verified', True)
        base.pop('gearKind', None)
        programs.append(base)

    destinations = []
    for did, dest in curated.DESTINATIONS.items():
        c = centres.get(dest.get('ecocenterId')) or {}
        destinations.append({
            'id': did, 'name': dest['name'], 'tagline': dest['tagline'], 'district': 'Thrissur', 'state': 'Kerala',
            'division': dest['division'], 'nearestTown': dest['nearestTown'], 'description': dest['description'],
            'officialDescription': '',
            'images': IMAGES['destinations'].get(did, []), 'lat': dest['lat'], 'lng': dest['lng'], 'elevationM': dest['elevationM'],
            'phones': [], 'email': None, 'address': dest['address'],
            'howToReach': dest['howToReach'], 'timings': dest['timings'], 'entryFees': dest.get('entryFees', {}),
            'highlights': dest['highlights'], 'nearby': dest.get('nearby', []), 'bestSeason': dest['bestSeason'],
            'sourceUrls': [], 'programCount': sum(1 for p in programs if p['destinationId'] == did),
        })

    order = {d['id']: i for i, d in enumerate(destinations)}
    programs.sort(key=lambda p: (order[p['destinationId']], curated.TYPE_ORDER.index(p['programType']), p['name']))
    out = {
        '_note': 'Generated by tools/thrissur/build_data.py. Re-run the script to refresh rates.',
        'generatedAt': today,
        'destinations': destinations,
        'programs': programs,
    }
    path = os.path.join(ROOT, 'assets', 'data', 'thrissur.json')
    json.dump(out, open(path, 'w'), indent=1, ensure_ascii=False)
    print(f'wrote {path}: {len(destinations)} destinations, {len(programs)} programmes')


if __name__ == '__main__':
    main()
