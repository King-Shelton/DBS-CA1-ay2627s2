-- ============================================
-- REVIEW PROCEDURES & FUNCTIONS
-- Run after review_comment_tables.sql
--
-- All the checking happens in the database. Every RAISE EXCEPTION
-- message is written so the page can show it to the member as is.
--
-- Writes (create, update, delete) are PROCEDUREs, called with CALL.
-- Reads are FUNCTIONs that return a table, used with SELECT * FROM.
-- ============================================

-- drop the old versions first so this file can be run again
-- after a change to the parameters or the returned columns
DROP PROCEDURE IF EXISTS public.create_review;
DROP PROCEDURE IF EXISTS public.update_review;
DROP PROCEDURE IF EXISTS public.delete_review;
DROP FUNCTION IF EXISTS public.get_reviews;
DROP FUNCTION IF EXISTS public.get_product_reviews;
DROP FUNCTION IF EXISTS public.get_reviewable_products;


-- ============================================
-- create_review
-- A member can only review a product from one of their COMPLETED
-- orders, and only once per product.
-- ============================================
CREATE OR REPLACE PROCEDURE public.create_review(
    p_member_id INTEGER,
    p_product_id INTEGER,
    p_rating INTEGER,
    p_review_text VARCHAR
)
AS $$
DECLARE
    v_review_text VARCHAR := TRIM(p_review_text);
    v_product_id INTEGER;
    v_sale_order_id INTEGER;
    v_review_id INTEGER;
BEGIN
    -- ---- Check the input first ----
    IF p_rating IS NULL OR p_rating NOT BETWEEN 1 AND 5 THEN
        RAISE EXCEPTION 'Please pick a rating from 1 to 5.';
    END IF;

    IF v_review_text IS NULL OR v_review_text = '' THEN
        RAISE EXCEPTION 'Your review can''t be empty.';
    END IF;

    IF LENGTH(v_review_text) > 1000 THEN
        RAISE EXCEPTION 'Your review is too long. Please keep it to 1000 characters or less.';
    END IF;

    -- ---- Check the product ----
    SELECT id INTO v_product_id
    FROM public.product
    WHERE id = p_product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'That product doesn''t exist.';
    END IF;

    -- ---- Check they actually bought it ----
    -- SELECT INTO only keeps the first row, and ORDER BY puts their
    -- latest completed order first. That's the order the
    -- "verified purchase" tag points to
    SELECT so.id INTO v_sale_order_id
    FROM public.sale_order so
    JOIN public.sale_order_item soi ON soi.sale_order_id = so.id
    WHERE so.member_id = p_member_id
      AND soi.product_id = p_product_id
      AND so.status = 'COMPLETED'
    ORDER BY so.order_datetime DESC;

    -- PACKING and CANCELLED orders don't count
    IF NOT FOUND THEN
        RAISE EXCEPTION 'You can only review products from your completed orders.';
    END IF;

    -- ---- One review per product ----
    SELECT id INTO v_review_id
    FROM public.review
    WHERE member_id = p_member_id AND product_id = p_product_id;

    IF FOUND THEN
        RAISE EXCEPTION 'You''ve already reviewed this product. You can edit your old review instead.';
    END IF;

    INSERT INTO public.review (member_id, product_id, sale_order_id, rating, review_text)
    VALUES (p_member_id, p_product_id, v_sale_order_id, p_rating, v_review_text);
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- update_review
-- Only the member who wrote the review can change it.
-- ============================================
CREATE OR REPLACE PROCEDURE public.update_review(
    p_member_id INTEGER,
    p_review_id INTEGER,
    p_rating INTEGER,
    p_review_text VARCHAR
)
AS $$
DECLARE
    v_owner_id INTEGER;
    v_review_text VARCHAR := TRIM(p_review_text);
BEGIN
    -- ---- Check the review and who owns it ----
    SELECT member_id INTO v_owner_id
    FROM public.review
    WHERE id = p_review_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'That review doesn''t exist.';
    END IF;

    -- a NULL member id is blocked too, since comparing with NULL
    -- is never true
    IF p_member_id IS NULL OR v_owner_id <> p_member_id THEN
        RAISE EXCEPTION 'You can only edit your own reviews.';
    END IF;

    -- ---- Check the input ----
    IF p_rating IS NULL OR p_rating NOT BETWEEN 1 AND 5 THEN
        RAISE EXCEPTION 'Please pick a rating from 1 to 5.';
    END IF;

    IF v_review_text IS NULL OR v_review_text = '' THEN
        RAISE EXCEPTION 'Your review can''t be empty.';
    END IF;

    IF LENGTH(v_review_text) > 1000 THEN
        RAISE EXCEPTION 'Your review is too long. Please keep it to 1000 characters or less.';
    END IF;

    -- setting updated_at is what makes the page show "edited"
    UPDATE public.review
    SET rating = p_rating,
        review_text = v_review_text,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_review_id;
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- delete_review
-- Only the owner can delete. The comments on the review go with it
-- because of ON DELETE CASCADE on review_comment.review_id.
-- ============================================
CREATE OR REPLACE PROCEDURE public.delete_review(
    p_member_id INTEGER,
    p_review_id INTEGER
)
AS $$
DECLARE
    v_owner_id INTEGER;
BEGIN
    SELECT member_id INTO v_owner_id
    FROM public.review
    WHERE id = p_review_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'That review doesn''t exist.';
    END IF;

    IF p_member_id IS NULL OR v_owner_id <> p_member_id THEN
        RAISE EXCEPTION 'You can only delete your own reviews.';
    END IF;

    DELETE FROM public.review WHERE id = p_review_id;
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- get_reviews
-- Every review written by one member, newest first, for the
-- /review/retrieve/all page.
-- ============================================
CREATE OR REPLACE FUNCTION public.get_reviews(p_member_id INTEGER)
RETURNS TABLE (
    review_id INTEGER,
    product_id INTEGER,
    product_name CHARACTER VARYING,
    image_url CHARACTER VARYING,
    rating INTEGER,
    review_text CHARACTER VARYING,
    created_at TIMESTAMP WITHOUT TIME ZONE,
    updated_at TIMESTAMP WITHOUT TIME ZONE,
    comment_count BIGINT   -- COUNT gives back a BIGINT
)
AS $$
DECLARE
    v_member_id INTEGER;
BEGIN
    SELECT id INTO v_member_id
    FROM public.member
    WHERE id = p_member_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'That member doesn''t exist.';
    END IF;

    -- columns are written as r.something because the output column
    -- names above clash with the table column names otherwise
    RETURN QUERY
    SELECT r.id,
           r.product_id,
           p.name,
           p.image_url,
           r.rating,
           r.review_text,
           r.created_at,
           r.updated_at,
           -- count this review's comments, removed ones don't count
           (SELECT COUNT(*)
            FROM public.review_comment c
            WHERE c.review_id = r.id AND c.is_removed = FALSE)
    FROM public.review r
    JOIN public.product p ON p.id = r.product_id
    WHERE r.member_id = p_member_id
    ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- get_product_reviews
-- Every review on one product for /product/retrieve.
-- average_rating and review_count are the same on every row,
-- so the page just reads them off the first row.
-- ============================================
CREATE OR REPLACE FUNCTION public.get_product_reviews(p_product_id INTEGER)
RETURNS TABLE (
    review_id INTEGER,
    member_id INTEGER,
    username CHARACTER VARYING,
    rating INTEGER,
    review_text CHARACTER VARYING,
    created_at TIMESTAMP WITHOUT TIME ZONE,
    updated_at TIMESTAMP WITHOUT TIME ZONE,
    comment_count BIGINT,
    average_rating NUMERIC,
    review_count BIGINT
)
AS $$
DECLARE
    v_product_id INTEGER;
    v_average_rating NUMERIC;
    v_review_count BIGINT;
BEGIN
    SELECT id INTO v_product_id
    FROM public.product
    WHERE id = p_product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'That product doesn''t exist.';
    END IF;

    -- work out the product's totals once, then put them on every row
    SELECT ROUND(AVG(r.rating), 1), COUNT(*)
    INTO v_average_rating, v_review_count
    FROM public.review r
    WHERE r.product_id = p_product_id;

    -- member_id is returned so the page knows who wrote each review
    -- (the author can't start a top level comment on their own review)
    RETURN QUERY
    SELECT r.id,
           r.member_id,
           m.username,
           r.rating,
           r.review_text,
           r.created_at,
           r.updated_at,
           (SELECT COUNT(*)
            FROM public.review_comment c
            WHERE c.review_id = r.id AND c.is_removed = FALSE),
           v_average_rating,
           v_review_count
    FROM public.review r
    JOIN public.member m ON m.id = r.member_id
    WHERE r.product_id = p_product_id
    ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- get_reviewable_products
-- Products the member can still review: in one of their COMPLETED
-- orders and not reviewed yet. Fills the dropdown on the create page
-- so nobody can pick something create_review would reject anyway.
-- ============================================
CREATE OR REPLACE FUNCTION public.get_reviewable_products(p_member_id INTEGER)
RETURNS TABLE (
    product_id INTEGER,
    product_name CHARACTER VARYING,
    last_ordered TIMESTAMP WITHOUT TIME ZONE
)
AS $$
BEGIN
    RETURN QUERY
    SELECT p.id,
           p.name,
           MAX(so.order_datetime)   -- same product can be in more than one order
    FROM public.sale_order so
    JOIN public.sale_order_item soi ON soi.sale_order_id = so.id
    JOIN public.product p ON p.id = soi.product_id
    WHERE so.member_id = p_member_id
      AND so.status = 'COMPLETED'
      -- leave out the products they've already reviewed
      AND p.id NOT IN (
          SELECT r.product_id FROM public.review r
          WHERE r.member_id = p_member_id
      )
    GROUP BY p.id, p.name
    ORDER BY p.name;
END;
$$ LANGUAGE plpgsql;
