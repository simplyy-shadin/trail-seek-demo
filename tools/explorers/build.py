#!/usr/bin/env python3
"""Demo explorers for the beta: realistic faces (AI-generated, people who do not
exist), bios and multi-month trekking histories. Writes
  assets/data/explorers.json        (read by the app in local mode)
  supabase/seed_explorers.sql       (same data for the cloud database)
  web/public/images/people/*.jpg    (faces for the website)
XP / level / badges are NOT stored here: the app derives them from the history
with the same engine it uses for real users. The SQL carries an XP figure
computed with the same rules so the cloud leaderboard sorts identically.
Usage: FACES=/dir/with/f*.jpg,g*.jpg python3 tools/explorers/build.py
"""
import json, os, random, datetime
from PIL import Image, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FACES = os.environ.get('FACES', '/tmp/claude-1000/-home-robert-Projects-trailseek/71b6d62d-00b9-408a-a039-faf5736cd0d4/scratchpad')

# username: (name, town, bio, face file, persona weights, activity count, cloud uuid suffix)
PEOPLE = {
    'arjun':   ('Arjun Nair', 'Chalakudy', 'Grew up next to Athirappilly. Hornbill count: 212. Leads weekend treks for first-timers.', 'faces2/f15.jpg', {'athi': 5, 'peechi': 1, 'chim': 2, 'peaks': 3}, 46, '02'),
    'deepa':   ('Deepa Krishnan', 'Irinjalakuda', 'Butterfly photographer. Chimmony after the rains is home. Climate Walk x6.', 'faces3/g12.jpg', {'chim': 6, 'peechi': 2, 'chul': 2, 'peaks': 2}, 41, '06'),
    'meera':   ('Meera Pillai', 'Thrissur', 'Forest guide trainee at Peechi. Ask me about leeches, dholes and the Moodal climb.', 'faces3/g8.jpg', {'peechi': 7, 'chim': 2, 'athi': 1}, 38, '10'),
    'sneha':   ('Sneha Thomas', 'Kochi', 'Organiser of Kochi Trekkers. 30+ group treks on the Digital Rope, nobody left behind.', 'faces3/g19.jpg', {'peechi': 3, 'chim': 3, 'athi': 2, 'peaks': 2}, 34, '03', ),
    'rahul':   ('Rahul Varma', 'Palakkad', 'Peacocks, granite and sunrise at Chulannur. Early starts only.', 'faces2/f13.jpg', {'chul': 7, 'peechi': 1, 'peaks': 2}, 29, '09'),
    'riya':    ('Riya Sharma', 'Thrissur', 'Weekend trekker. Peechi regular. Birds over summits.', 'faces3/g11.jpg', {'peechi': 5, 'chim': 2, 'athi': 1}, 24, '01'),
    'vishnu':  ('Vishnu Prasad', 'Wadakkanchery', 'Marathon runner gone trail. Falls behind on purpose (photos).', 'faces2/f23.jpg', {'peechi': 3, 'peaks': 3, 'chul': 1}, 21, '07'),
    'nikhil':  ('Nikhil Menon', 'Thrissur', 'Forest walks, coracles, chai at the dam.', 'faces3/g25.jpg', {'peechi': 3, 'athi': 3, 'water': 3}, 18, '05'),
    'joel':    ('Joel Mathew', 'Angamaly', 'Cycling the sanctuary roads one weekend at a time.', 'faces2/f2.jpg', {'cycle': 6, 'chim': 2, 'athi': 1}, 16, '11'),
    'lakshmi': ('Lakshmi Suresh', 'Chalakudy', 'Coracle convert. 40 minutes is never enough.', 'faces3/g27.jpg', {'water': 6, 'peechi': 2, 'athi': 1}, 13, '12'),
    'fathima': ('Fathima K', 'Kodungallur', 'Family treks with two kids and a very slow uncle.', 'faces3/g50.jpg', {'water': 3, 'chul': 3, 'athi': 2}, 10, '04'),
    'anu':     ('Anu Jose', 'Guruvayur', 'Student. First trek this year, hooked.', 'faces3/g43.jpg', {'chul': 3, 'peechi': 2}, 6, '08'),
}

# (title, type, trailId, district, km, gain m, max altitude m, hours)
POOL = {
    'athi': [('Athirappilly Forest Trek', 'trekking', 'athirappilly-trekking', 'Thrissur', 9.2, 260, 420, 5.0),
             ('Athirappilly & Vazhachal Falls', 'waterfallTrail', 'athirappilly-vazhachal-falls', 'Thrissur', 2.4, 70, 310, 2.5),
             ('Vazhachal Riverbank Walk', 'forestWalk', 'vazhachal-trekking', 'Thrissur', 6.5, 160, 380, 4.0)],
    'peechi': [('Nasika Trek', 'trekking', 'peechi-nasika', 'Thrissur', 3.1, 140, 260, 2.5),
               ('Elephant Saga Trek', 'forestWalk', 'peechi-elephant-saga', 'Thrissur', 2.2, 60, 180, 1.6),
               ('Dam Valley Trek', 'trekking', 'peechi-dam-valley', 'Thrissur', 10.4, 380, 420, 6.0),
               ('Moodal Hill Hike', 'hiking', 'peechi-moodal-hill', 'Thrissur', 12.2, 640, 742, 7.5)],
    'chim': [('Choorathala Waterfall Trek', 'waterfallTrail', 'chimmony-choorathala', 'Thrissur', 5.2, 190, 340, 3.5),
             ('Amphi-Trekking, Chimmony', 'trekking', 'chimmony-amphi-trekking', 'Thrissur', 8.1, 230, 410, 5.0),
             ('Climate Walk, Chimmony', 'hiking', 'chimmony-climate-walk', 'Thrissur', 12.3, 520, 730, 7.0)],
    'chul': [('Chilambathodi Stream Trek', 'forestWalk', 'chulannur-chilambathodi', 'Palakkad', 3.0, 60, 150, 2.0),
             ('Anadiyanpara Rock Trek', 'trekking', 'chulannur-anadiyanpara', 'Palakkad', 5.1, 160, 260, 3.0),
             ('Watch Tower Trek', 'trekking', 'chulannur-watch-tower', 'Palakkad', 6.2, 190, 290, 3.5),
             ('Ayakurisi Circuit', 'hiking', 'chulannur-ayakurisi', 'Palakkad', 8.0, 310, 340, 6.0)],
    'water': [('Coracle Ride, Peechi (40 min)', 'kayaking', 'peechi-coracle-40', 'Thrissur', 2.0, 0, 90, 0.7),
              ('Coracle Ride, Chimmony', 'kayaking', 'chimmony-coracle-20', 'Thrissur', 1.0, 0, 80, 0.4),
              ('Coracle + Nasika Trek', 'trekking', 'peechi-coracle-nasika', 'Thrissur', 3.2, 140, 260, 3.0)],
    'cycle': [('Panther Ride, Chimmony', 'cycling', 'chimmony-panther-ride', 'Thrissur', 14.0, 220, 260, 2.0),
              ('Thrissur to Peechi Ride', 'cycling', None, 'Thrissur', 42.0, 310, 220, 3.5)],
    'peaks': [('Meesapulimala', 'trekking', None, 'Idukki', 16.0, 1050, 2640, 8.5),
              ('Chembra Peak', 'trekking', None, 'Wayanad', 7.4, 900, 2100, 4.5),
              ('Agasthyakoodam', 'mountaineering', None, 'Thiruvananthapuram', 28.0, 1650, 1868, 22.0),
              ('Kolukkumalai Sunrise', 'hiking', None, 'Idukki', 9.0, 640, 2160, 5.0),
              ('Banasura Hill', 'trekking', None, 'Wayanad', 10.5, 800, 1650, 5.5)],
}

# XP rules mirrored from lib/features/progress/xp_rules.dart (for the SQL leaderboard figure only).
def xp_for(r, first):
    xp = 100 + int(r['distanceM'] / 1000 * 10) + (r['elevationGainM'] // 100) * 5
    if r['memberCount'] > 1: xp += 50
    if first and r['trailId']: xp += 25
    if not r["verified"]: xp = int(xp * 0.25 + 0.5)  # Dart .round(): half away from zero
    return max(0, min(1500, xp))


def history(user, weights, n, rnd):
    now = datetime.datetime(2026, 10, 27, 18, 0)
    keys = [k for k, w in weights.items() for _ in range(w)]
    out = []
    for i in range(n):
        k = rnd.choice(keys)
        t = rnd.choice(POOL[k])
        days_ago = int((i / max(1, n - 1)) ** 1.3 * 420) + rnd.randint(0, 6)
        start_h = rnd.choice([5, 5, 6, 6, 6, 7, 7, 8, 9, 15]) if t[1] != 'kayaking' else rnd.choice([9, 10, 16])
        start = (now - datetime.timedelta(days=days_ago)).replace(hour=start_h, minute=rnd.choice([0, 15, 30, 45]))
        hours = t[7] * rnd.uniform(0.9, 1.2)
        end = start + datetime.timedelta(hours=hours)
        km = round(t[4] * rnd.uniform(0.95, 1.08), 2)
        group = rnd.random() < (0.85 if user == 'sneha' else 0.4)
        rec = {
            'id': f'demo-{user}-{i:03d}', 'type': t[1], 'title': t[0], 'startedAt': start.isoformat(), 'endedAt': end.isoformat(),
            'distanceM': round(km * 1000), 'elevationGainM': int(t[5] * rnd.uniform(0.95, 1.1)), 'maxAltitudeM': t[6],
            'verified': rnd.random() > 0.06, 'trailId': t[2], 'district': t[3], 'groupSessionId': (f'g-{user}-{i}' if group else None),
            'memberCount': rnd.randint(3, 9) if group else 1, 'separations': (1 if group and rnd.random() < 0.2 else 0), 'simulated': False,
        }
        out.append(rec)
    out.sort(key=lambda r: r['endedAt'])
    return out


def main():
    rnd = random.Random(42)
    people, acts = [], {}
    os.makedirs(os.path.join(ROOT, 'assets', 'images', 'people'), exist_ok=True)
    web = os.path.join(ROOT, 'web', 'public', 'images', 'people')
    os.makedirs(web, exist_ok=True)
    sql = ['-- Generated by tools/explorers/build.py. Run after supabase/seed.sql.', 'begin;', 'delete from public.activities where user_id::text like \'11111111-%\';']
    for uname, (name, town, bio, face, weights, n, suffix) in PEOPLE.items():
        im = ImageOps.exif_transpose(Image.open(os.path.join(FACES, face))).convert('RGB')
        w, h = im.size
        s = min(w, h)
        im = im.crop(((w - s) // 2, int((h - s) * 0.3), (w - s) // 2 + s, int((h - s) * 0.3) + s)).resize((400, 400), Image.LANCZOS)
        im.save(os.path.join(ROOT, 'assets', 'images', 'people', f'{uname}.jpg'), 'JPEG', quality=82, optimize=True)
        im.save(os.path.join(web, f'{uname}.jpg'), 'JPEG', quality=82, optimize=True)
        hist = history(uname, weights, n, rnd)
        seen, total = set(), 0
        for r in hist:
            first = r['trailId'] is not None and r['trailId'] not in seen
            if r['trailId']: seen.add(r['trailId'])
            total += xp_for(r, first)
        cloud_id = f'11111111-0000-4000-8000-0000000000{suffix}'
        people.append({'id': f'demo-{uname}', 'cloudId': cloud_id, 'name': name, 'username': uname, 'town': town, 'bio': bio, 'avatar': f'asset:assets/images/people/{uname}.jpg', 'xp': total})
        acts[f'demo-{uname}'] = hist
        sql.append(f"update public.profiles set avatar_id = 'asset:assets/images/people/{uname}.jpg', bio = $${bio}$$, home_town = '{town}', xp = {total}, activity_count = {len(hist)} where id = '{cloud_id}';")
        for r in hist:
            sql.append("insert into public.activities (id, user_id, data, ended_at) values ('{}', '{}', $${}$$::jsonb, '{}');".format(r['id'], cloud_id, json.dumps(r), r['endedAt']))
    sql.append('commit;')
    json.dump({'explorers': people, 'activities': acts}, open(os.path.join(ROOT, 'assets', 'data', 'explorers.json'), 'w'), indent=0)
    open(os.path.join(ROOT, 'supabase', 'seed_explorers.sql'), 'w').write('\n'.join(sql) + '\n')
    for p in sorted(people, key=lambda p: -p['xp']):
        print(f"{p['username']:8} xp={p['xp']:6}  acts={len(acts[p['id']])}")


if __name__ == '__main__':
    main()
