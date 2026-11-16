-- ============================================
-- TEST CALLS
-- Run these one at a time in pgAdmin (highlight the lines, F5).
--
-- The good calls that change data sit inside BEGIN ... ROLLBACK
-- so the sample data stays the same after testing.
-- The "should fail" calls are left on their own, each one should
-- stop with the message written next to it.
--
-- Members used below (all from SeedData.sql):
--   2 johnsmith   completed orders with products 1, 3, 5, 11, 17
--   3 janetaylor
--   4 mikewong    product 4 is in an order that's still PACKING
--   6 davidtan    product 9 is in a CANCELLED order
-- ============================================


-- ============================================
-- REVIEWS: create_review
-- ============================================

-- works: johnsmith reviews product 3 from his completed order 21
BEGIN;
CALL public.create_review(2, 3, 5, 'Big enough for a full day out. Handle is comfy too.');
SELECT * FROM public.review WHERE member_id = 2 AND product_id = 3;
ROLLBACK;

-- should fail: "You can only review products from your completed orders."
CALL public.create_review(2, 4, 4, 'Never bought this one');     -- never ordered
CALL public.create_review(4, 4, 4, 'Still waiting for it');      -- order is PACKING
CALL public.create_review(6, 9, 4, 'Cancelled this order');      -- order is CANCELLED

-- should fail: "You've already reviewed this product. You can edit your old review instead."
CALL public.create_review(2, 1, 4, 'Second review of the same bottle');

-- should fail: "Please pick a rating from 1 to 5."
CALL public.create_review(2, 3, 0, 'Rating too low');
CALL public.create_review(2, 3, 6, 'Rating too high');
CALL public.create_review(2, 3, NULL, 'No rating');

-- should fail: "Your review can't be empty."
CALL public.create_review(2, 3, 4, '   ');

-- should fail: "Your review is too long. Please keep it to 1000 characters or less."
CALL public.create_review(2, 3, 4, repeat('a', 1001));

-- should fail: "That product doesn't exist."
CALL public.create_review(2, 999, 4, 'Ghost product');


-- ============================================
-- REVIEWS: update_review
-- ============================================

-- works: johnsmith edits his own review 1, updated_at gets filled in
BEGIN;
CALL public.update_review(2, 1, 3, 'Dropped it again and the lid cracked this time. Still works though.');
SELECT id, rating, review_text, updated_at FROM public.review WHERE id = 1;
ROLLBACK;

-- should fail: "You can only edit your own reviews."  (review 2 belongs to lisamei)
CALL public.update_review(2, 2, 1, 'Trying to edit someone else''s review');

-- should fail: "That review doesn't exist."
CALL public.update_review(2, 999, 3, 'No such review');

-- should fail: "Please pick a rating from 1 to 5."
CALL public.update_review(2, 1, 9, 'Bad rating');

-- should fail: "Your review can't be empty."
CALL public.update_review(2, 1, 3, '');


-- ============================================
-- REVIEWS: delete_review
-- ============================================

-- works: johnsmith deletes review 1, comments 11 and 12 on it go too
BEGIN;
CALL public.delete_review(2, 1);
SELECT COUNT(*) AS review_left FROM public.review WHERE id = 1;                   -- 0
SELECT COUNT(*) AS comments_left FROM public.review_comment WHERE review_id = 1;  -- 0
ROLLBACK;

-- should fail: "You can only delete your own reviews."
CALL public.delete_review(3, 1);

-- should fail: "That review doesn't exist."
CALL public.delete_review(2, 999);


-- ============================================
-- REVIEWS: get_reviews, get_product_reviews, get_reviewable_products
-- ============================================

-- johnsmith's reviews: 7 and 1, both with 2 comments
SELECT * FROM public.get_reviews(2);

-- member with no reviews gives an empty table, not an error
SELECT * FROM public.get_reviews(5);

-- should fail: "That member doesn't exist."
SELECT * FROM public.get_reviews(999);

-- product 1 has 3 reviews, average 4.0
SELECT * FROM public.get_product_reviews(1);

-- product 4 has no reviews yet, empty table
SELECT * FROM public.get_product_reviews(4);

-- should fail: "That product doesn't exist."
SELECT * FROM public.get_product_reviews(999);

-- johnsmith can still review products 3, 11 and 17
SELECT * FROM public.get_reviewable_products(2);


-- ============================================
-- TIDY UP
-- A rolled back INSERT still uses up a review id, so put the
-- counter back to where the sample data left it.
-- ============================================
SELECT setval('public.review_id_seq', (SELECT MAX(id) FROM public.review));
