-- ============================================
-- SAMPLE REVIEWS & COMMENTS
-- Run after review_comment_tables.sql
-- Every review here is for a product from one of the member's
-- COMPLETED orders, same rule the procedures will enforce.
-- johnsmith still has products 3, 11 and 17 left to review
-- so there's something to try on the create page.
-- ============================================

-- ============================================
-- SEED: review
-- ============================================
INSERT INTO public.review (id, member_id, product_id, sale_order_id, rating, review_text, created_at, updated_at) VALUES
(1,  2,  1,  1,  4, 'Simple bottle, does the job. Dropped it twice on the MRT floor and it only got a small dent. Lid doesn''t leak in my bag, which was my main worry.', '2025-01-14 21:10:00', NULL),
(2,  9,  1,  8,  3, 'its ok. water gets warm by lunch since it''s single wall, should have gotten the insulated one', '2025-02-16 13:45:00', NULL),
(3,  12, 1,  25, 5, 'Bought this for my son for school. Light enough for him to carry and easy to wash.', '2025-04-24 08:20:00', NULL),
(4,  3,  2,  2,  5, 'Ice was still there at the end of the day even though I left it in the car. Wide mouth makes it easy to clean. Update: liked it so much I bought a second one for my mum.', '2025-01-19 22:05:00', '2025-03-09 19:30:00'),
(5,  10, 2,  9,  4, 'Keeps drinks cold for really long but it''s quite heavy when full. Paint at the bottom chipped after a month.', '2025-02-20 18:00:00', NULL),
(6,  14, 2,  27, 2, 'Mine came with a dent near the base. Insulation works fine but for $34.90 I expected better QC.', '2025-04-28 11:15:00', NULL),
(7,  2,  5,  1,  5, 'Use this at the gym almost every day. The straw lid is the best part, no need to unscrew anything between sets.', '2025-01-18 07:40:00', NULL),
(8,  11, 5,  10, 4, 'Good grip and the flip top is easy to open with one hand. Straw is a bit hard to clean though, had to buy a small brush for it.', '2025-02-25 20:30:00', NULL),
(9,  4,  3,  3,  5, 'Took it up Bukit Timah and on a 3 day trip to Tioman. Water was still cold on day 2. The carabiner clip is solid.', '2025-01-24 16:50:00', NULL),
(10, 13, 19, 12, 4, 'Narrow mouth means ice cubes are a pain to get in, but drinking from it is nicer than the wide ones.', '2025-03-03 10:10:00', NULL),
(11, 8,  16, 20, 5, 'Expensive but really light. Feels premium.', '2025-03-30 15:25:00', NULL),
(12, 7,  13, 6,  2, 'Cool idea but it gets hard to fold flat after a few uses. Fine for travel I guess.', '2025-02-02 12:00:00', NULL),
(13, 6,  12, 5,  4, 'Got the mint one. Looks exactly like the photo and holds cold well.', '2025-01-31 09:35:00', NULL),
(14, 3,  8,  15, 4, 'Lemon and mint in the infuser works great. Just remember to take the fruit out or it smells the next day.', '2025-03-14 21:00:00', NULL);

SELECT setval('public.review_id_seq', 14, true);

-- ============================================
-- SEED: review_comment
-- parents are inserted before their replies
-- ============================================
INSERT INTO public.review_comment (id, review_id, member_id, parent_id, comment_text, is_removed, created_at) VALUES
-- review 4 (janetaylor, Insulated 750ml)
(1,  4,  6,  NULL, 'How cold are we talking? Does the ice actually last overnight?', FALSE, '2025-01-20 09:15:00'),
(2,  4,  3,  1,    'yes! filled it at 10pm and there was still ice in the morning', FALSE, '2025-01-20 12:40:00'),
(3,  4,  10, 2,    'Same for mine. Only issue is it''s heavy.', FALSE, '2025-02-21 08:05:00'),
(4,  4,  5,  NULL, 'Does it fit the side pocket of a normal backpack?', FALSE, '2025-01-23 17:30:00'),
(5,  4,  14, 4,    'Fits mine but it''s a tight squeeze.', FALSE, '2025-04-29 10:00:00'),

-- review 6 (bennylow, 2 stars)
(6,  6,  3,  NULL, 'Oh no, mine came perfectly fine. Did you try asking for an exchange?', FALSE, '2025-04-29 13:20:00'),
(7,  6,  14, 6,    'Emailed them, still waiting for a reply.', FALSE, '2025-04-30 09:45:00'),
(8,  6,  3,  7,    'Hope they sort it out for you', FALSE, '2025-05-01 19:10:00'),

-- review 7 (johnsmith, Sport 600ml)
(9,  7,  11, NULL, 'Agree about the straw lid. Has yours ever leaked?', FALSE, '2025-02-26 21:00:00'),
(10, 7,  2,  9,    'Nope, as long as the flip top is clicked shut.', FALSE, '2025-02-26 22:15:00'),

-- review 1 (johnsmith, Classic 500ml)
(11, 1,  9,  NULL, 'how does it do with hot drinks?', FALSE, '2025-02-16 14:00:00'),
(12, 1,  2,  11,   'Wouldn''t recommend, the outside gets too hot to hold since it''s single wall.', FALSE, '2025-02-16 18:30:00'),

-- review 9 (mikewong, Pro 1 Litre)
-- comment 13 was removed by its owner, the reply under it stays
(13, 9,  7,  NULL, NULL, TRUE, '2025-01-25 11:00:00'),
(14, 9,  13, 13,   'It comes with the clip already attached, mine did anyway.', FALSE, '2025-01-26 08:30:00'),
(15, 9,  2,  NULL, 'Tioman! How was the water there?', FALSE, '2025-01-27 20:45:00'),
(16, 9,  4,  15,   'Super clear. Go around March, the weather is better.', FALSE, '2025-01-28 07:55:00'),

-- review 12 (emilychua, Collapsible)
(17, 12, 8,  NULL, 'Thanks for the heads up, was about to buy this for my Japan trip.', FALSE, '2025-02-03 23:10:00');

SELECT setval('public.review_comment_id_seq', 17, true);
