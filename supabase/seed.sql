-- Demo explorers for the Thrissur beta. Password for every demo account: trailseek
-- Re-runnable: deletes and recreates the demo users and their content.
begin;
delete from auth.users where email like '%@demo.trailseek.in';

create temp table demo (id uuid, name text, uname text, email text, avatar text, town text, bio text) on commit drop;
insert into demo values
 ('11111111-0000-4000-8000-000000000001','Riya Sharma','riya','riya@demo.trailseek.in','v1:1.0.1.2.1','Thrissur','Weekend trekker. Peechi regular. Birds over summits.'),
 ('11111111-0000-4000-8000-000000000002','Arjun Nair','arjun','arjun@demo.trailseek.in','v1:4.1.3.0.0','Chalakudy','Grew up next to Athirappilly. Hornbill count: 212.'),
 ('11111111-0000-4000-8000-000000000003','Sneha Thomas','sneha','sneha@demo.trailseek.in','v1:2.2.0.4.3','Kochi','Organiser of the Kochi Trekkers group. Safety first.'),
 ('11111111-0000-4000-8000-000000000004','Fathima K','fathima','fathima@demo.trailseek.in','v1:6.3.2.3.0','Kodungallur','Family treks with two kids and a very slow uncle.'),
 ('11111111-0000-4000-8000-000000000005','Nikhil Menon','nikhil','nikhil@demo.trailseek.in','v1:3.0.0.1.1','Thrissur','Forest walks, coracles, chai at the dam.'),
 ('11111111-0000-4000-8000-000000000006','Deepa Krishnan','deepa','deepa@demo.trailseek.in','v1:0.3.1.1.2','Irinjalakuda','Butterfly photographer. Chimmony after the rains is home.'),
 ('11111111-0000-4000-8000-000000000007','Vishnu Prasad','vishnu','vishnu@demo.trailseek.in','v1:5.2.2.0.1','Wadakkanchery','Marathon runner trying trails. Falls behind on purpose.'),
 ('11111111-0000-4000-8000-000000000008','Anu Jose','anu','anu@demo.trailseek.in','v1:2.1.3.2.0','Guruvayur','Student. First trek this year, hooked.'),
 ('11111111-0000-4000-8000-000000000009','Rahul Varma','rahul','rahul@demo.trailseek.in','v1:1.3.0.0.3','Palakkad','Peacocks, rocks and sunrise at Chulannur.'),
 ('11111111-0000-4000-8000-000000000010','Meera Pillai','meera','meera@demo.trailseek.in','v1:3.2.1.3.1','Thrissur','Forest guide trainee. Ask me about leeches.'),
 ('11111111-0000-4000-8000-000000000011','Joel Mathew','joel','joel@demo.trailseek.in','v1:4.0.2.1.2','Angamaly','Cycling the sanctuary roads one weekend at a time.'),
 ('11111111-0000-4000-8000-000000000012','Lakshmi Suresh','lakshmi','lakshmi@demo.trailseek.in','v1:0.1.3.0.0','Chalakudy','Coracle convert. 40 minutes is never enough.');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change)
select id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', email, extensions.crypt('trailseek', extensions.gen_salt('bf')), now() - interval '60 days',
       '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('display_name', name, 'username', uname), now() - interval '60 days', now(), '', '', '', ''
from demo;

insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), id, id::text, 'email', jsonb_build_object('sub', id::text, 'email', email, 'email_verified', true), now(), now(), now() from demo;

update public.profiles p set username = d.uname, avatar_id = d.avatar, home_town = d.town, bio = d.bio, is_demo = true
from demo d where p.id = d.id;

insert into public.follows (follower_id, followee_id) values
 ('11111111-0000-4000-8000-000000000001','11111111-0000-4000-8000-000000000002'),('11111111-0000-4000-8000-000000000001','11111111-0000-4000-8000-000000000003'),('11111111-0000-4000-8000-000000000001','11111111-0000-4000-8000-000000000010'),
 ('11111111-0000-4000-8000-000000000002','11111111-0000-4000-8000-000000000001'),('11111111-0000-4000-8000-000000000002','11111111-0000-4000-8000-000000000006'),
 ('11111111-0000-4000-8000-000000000003','11111111-0000-4000-8000-000000000001'),('11111111-0000-4000-8000-000000000003','11111111-0000-4000-8000-000000000007'),('11111111-0000-4000-8000-000000000003','11111111-0000-4000-8000-000000000004'),
 ('11111111-0000-4000-8000-000000000004','11111111-0000-4000-8000-000000000003'),('11111111-0000-4000-8000-000000000005','11111111-0000-4000-8000-000000000001'),('11111111-0000-4000-8000-000000000005','11111111-0000-4000-8000-000000000012'),
 ('11111111-0000-4000-8000-000000000006','11111111-0000-4000-8000-000000000002'),('11111111-0000-4000-8000-000000000006','11111111-0000-4000-8000-000000000010'),('11111111-0000-4000-8000-000000000007','11111111-0000-4000-8000-000000000003'),
 ('11111111-0000-4000-8000-000000000008','11111111-0000-4000-8000-000000000001'),('11111111-0000-4000-8000-000000000008','11111111-0000-4000-8000-000000000010'),('11111111-0000-4000-8000-000000000008','11111111-0000-4000-8000-000000000003'),
 ('11111111-0000-4000-8000-000000000009','11111111-0000-4000-8000-000000000006'),('11111111-0000-4000-8000-000000000010','11111111-0000-4000-8000-000000000001'),('11111111-0000-4000-8000-000000000010','11111111-0000-4000-8000-000000000002'),
 ('11111111-0000-4000-8000-000000000011','11111111-0000-4000-8000-000000000005'),('11111111-0000-4000-8000-000000000012','11111111-0000-4000-8000-000000000005'),('11111111-0000-4000-8000-000000000012','11111111-0000-4000-8000-000000000001');

create temp table seedposts (id uuid, author uuid, ago interval, text text, place text, lat float, lng float) on commit drop;
insert into seedposts values
 ('22222222-0000-4000-8000-000000000001','11111111-0000-4000-8000-000000000002','2 hours','Top of Athirappilly at 7:40 this morning before the day crowd. Guide Suresh spotted two great hornbills in the first kilometre. #Athirappilly #Hornbill #ForestTrek','Athirappilly',10.2851,76.5699),
 ('22222222-0000-4000-8000-000000000002','11111111-0000-4000-8000-000000000001','6 hours','Nasika trail then straight into the coracle. 3 km up, 20 minutes floating back past the dam. Best ₹1,500 I have spent this year. #Peechi #Coracle','Peechi dam',10.5309,76.3736),
 ('22222222-0000-4000-8000-000000000003','11111111-0000-4000-8000-000000000006','11 hours','Choorathala after last week''s rain is thundering. Leeches were out in force; salt in the socks, no problem. Tamil yeoman butterflies everywhere on the way back. #Chimmony #Choorathala #Butterflies','Chimmony Wildlife Sanctuary',10.4414,76.4487),
 ('22222222-0000-4000-8000-000000000004','11111111-0000-4000-8000-000000000009','1 day 1 hour','Chulannur at sunrise. Counted 14 peacocks displaying on the laterite before 7. The watch tower trek is short but the light up there is unreal. #Chulannur #Peafowl','Chulannur',10.7179,76.4622),
 ('22222222-0000-4000-8000-000000000005','11111111-0000-4000-8000-000000000003','1 day 5 hours','Digital Rope saved us a scare on the Dam Valley trek: Vishnu stopped for photos, the app flagged him falling behind in 20 seconds, guide waited. Everyone home by 2. #Peechi #GoTogether','Peechi dam',10.5309,76.3736),
 ('22222222-0000-4000-8000-000000000006','11111111-0000-4000-8000-000000000004','2 days 3 hours','Took the kids on the 20-minute coracle at Peechi. Life jackets on, boatman let the 8-year-old hold the paddle. Zero stress, big smiles. #Peechi #FamilyTrek','Peechi dam',10.5309,76.3736),
 ('22222222-0000-4000-8000-000000000007','11111111-0000-4000-8000-000000000011','2 days 9 hours','Panther Ride: cycled the Chimmony sanctuary road from the dam. Gaur on the verge at the 3 km mark, we just stopped and waited. ₹300 well spent. #Chimmony #Cycling','Chimmony dam',10.4414,76.4487),
 ('22222222-0000-4000-8000-000000000008','11111111-0000-4000-8000-000000000010','3 days','Trainee guide diary, day 12: Elephant Saga loop with a group of six from Kochi. Fresh dung at the stream crossing, so we took the upper line. #Peechi #GuideLife','Peechi',10.5309,76.3736),
 ('22222222-0000-4000-8000-000000000009','11111111-0000-4000-8000-000000000005','3 days 7 hours','Vazhachal rapids at full flow and the bamboo arch on the way down. The division trek is paused for the season but the riverbank walk is open. #Vazhachal #Athirappilly','Vazhachal',10.3016,76.6034),
 ('22222222-0000-4000-8000-000000000010','11111111-0000-4000-8000-000000000008','4 days','First real trek: Chilambathodi stream walk at Chulannur. Easy, 2 hours, peacock calls the whole way. Booked the Anadiyanpara rock trek for next month already. #Chulannur #FirstTrek','Chulannur',10.7179,76.4622),
 ('22222222-0000-4000-8000-000000000011','11111111-0000-4000-8000-000000000007','5 days','Moodal Hill. 8 AM start, back at 3. Legs gone, views worth it. Carry 2 litres minimum, there is nothing up there. #Peechi #MoodalHill','Peechi',10.5309,76.3736),
 ('22222222-0000-4000-8000-000000000012','11111111-0000-4000-8000-000000000012','6 days','The 40-minute coracle reaches the far shore where the elephants come down in the evening. Boatman Manikandan has been on this water 30 years. #Peechi #Coracle','Peechi dam',10.5309,76.3736),
 ('22222222-0000-4000-8000-000000000013','11111111-0000-4000-8000-000000000002','7 days','Charpa Falls is roaring beside the road this week. Free to see, five minutes from Athirappilly, nobody stops. #Charpa #Athirappilly','Charpa Falls',10.2967,76.5894),
 ('22222222-0000-4000-8000-000000000014','11111111-0000-4000-8000-000000000003','9 days','Amphi-Trekking at Chimmony: 8 km through the forest and a coracle back across the reservoir. 7 AM sharp start, done by 1. Six of us on one ticket. #Chimmony #AmphiTrekking','Chimmony Wildlife Sanctuary',10.4414,76.4487),
 ('22222222-0000-4000-8000-000000000015','11111111-0000-4000-8000-000000000006','12 days','Climate Walk, 12 km, seven hours, three forest types. The evergreen patch near the top had lion-tailed macaques. Hardest and best day of the year. #Chimmony #ClimateWalk','Chimmony Wildlife Sanctuary',10.4414,76.4487),
 ('22222222-0000-4000-8000-000000000016','11111111-0000-4000-8000-000000000009','15 days','Ayakurisi full circuit: 8 km, six hours, out by 8 AM. Peafowl, junglefowl, a monitor lizard sunning on the rock. Carry water, there is none. #Chulannur #Ayakurisi','Chulannur',10.7179,76.4622),
 ('22222222-0000-4000-8000-000000000017','11111111-0000-4000-8000-000000000010','18 days','Guide tip: for any Peechi trek, start by 9 and you are back before the afternoon heat on the open rock. #Peechi #GuideLife','Peechi',10.5309,76.3736),
 ('22222222-0000-4000-8000-000000000018','11111111-0000-4000-8000-000000000005','21 days','Thumboormuzhi hanging bridge and the butterfly garden on the way back from Athirappilly. Good stop with kids, ₹40 a head. #Thumboormuzhi #Athirappilly','Thumboormuzhi',10.2985,76.4532);

insert into public.posts (id, author_id, text, place_name, lat, lng, created_at)
select id, author, text, place, lat, lng, now() - ago from seedposts;

-- Likes: every demo user likes a pseudo-random third of the posts they did not write.
insert into public.likes (user_id, post_id, created_at)
select d.id, p.id, now() - (random() * interval '2 days')
from demo d cross join seedposts p
where p.author <> d.id and (abs(hashtext(d.id::text || p.id::text)) % 3) = 0;

insert into public.comments (post_id, author_id, text, created_at) values
 ('22222222-0000-4000-8000-000000000001','11111111-0000-4000-8000-000000000001','Which guide? We had Suresh too, he knows every nest on that stretch.', now() - interval '90 minutes'),
 ('22222222-0000-4000-8000-000000000001','11111111-0000-4000-8000-000000000010','Hornbills before 8 is the rule. Great shot.', now() - interval '70 minutes'),
 ('22222222-0000-4000-8000-000000000002','11111111-0000-4000-8000-000000000012','Try the 40-minute coracle next time, totally different water.', now() - interval '5 hours'),
 ('22222222-0000-4000-8000-000000000003','11111111-0000-4000-8000-000000000009','Those yeomans! Chimmony in November is the place.', now() - interval '9 hours'),
 ('22222222-0000-4000-8000-000000000004','11111111-0000-4000-8000-000000000008','Doing the stream walk there this weekend, thanks for the sunrise tip.', now() - interval '20 hours'),
 ('22222222-0000-4000-8000-000000000005','11111111-0000-4000-8000-000000000007','In my defence the dholes were right there.', now() - interval '1 day'),
 ('22222222-0000-4000-8000-000000000005','11111111-0000-4000-8000-000000000004','This is exactly why I book with the app for the kids.', now() - interval '22 hours'),
 ('22222222-0000-4000-8000-000000000007','11111111-0000-4000-8000-000000000005','Gaur on the road is the Chimmony welcome committee.', now() - interval '2 days'),
 ('22222222-0000-4000-8000-000000000010','11111111-0000-4000-8000-000000000003','Welcome to the club. Anadiyanpara rock at dusk is special.', now() - interval '3 days'),
 ('22222222-0000-4000-8000-000000000011','11111111-0000-4000-8000-000000000010','2 litres is the minimum, 3 in March.', now() - interval '4 days'),
 ('22222222-0000-4000-8000-000000000014','11111111-0000-4000-8000-000000000011','Six on one ticket is the way. Booking this for December.', now() - interval '8 days'),
 ('22222222-0000-4000-8000-000000000015','11111111-0000-4000-8000-000000000002','Macaques at Chimmony? That is a first for me, brilliant.', now() - interval '11 days');
commit;
