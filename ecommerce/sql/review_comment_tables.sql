-- ============================================
-- REVIEW & COMMENT TABLES
-- Run this after CreateDbTable.sql and SeedData.sql
-- ============================================

-- comments depend on reviews, so drop them first
DROP TABLE IF EXISTS public.review_comment CASCADE;
DROP TABLE IF EXISTS public.review CASCADE;

-- ============================================
-- review
-- One review per member per product. If someone buys the same
-- product again they just edit their old review instead of
-- posting a second one.
-- ============================================
CREATE TABLE public.review (
    id SERIAL PRIMARY KEY,
    member_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    sale_order_id INTEGER NOT NULL,   -- the completed order that proves they bought it
    rating SMALLINT NOT NULL,
    review_text CHARACTER VARYING(1000) NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITHOUT TIME ZONE,   -- stays NULL until the review is edited
    CONSTRAINT fk_review_member FOREIGN KEY (member_id) REFERENCES public.member(id),
    CONSTRAINT fk_review_product FOREIGN KEY (product_id) REFERENCES public.product(id),
    CONSTRAINT fk_review_sale_order FOREIGN KEY (sale_order_id) REFERENCES public.sale_order(id),
    CONSTRAINT uq_review_member_product UNIQUE (member_id, product_id),
    CONSTRAINT chk_review_rating CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT chk_review_text CHECK (char_length(btrim(review_text)) > 0)
);

-- the product page looks up reviews by product a lot
CREATE INDEX idx_review_product ON public.review(product_id);

-- ============================================
-- review_comment
-- parent_id is NULL for a top level comment, otherwise it points
-- to the comment being replied to (same table).
-- ============================================
CREATE TABLE public.review_comment (
    id SERIAL PRIMARY KEY,
    review_id INTEGER NOT NULL,
    member_id INTEGER NOT NULL,
    parent_id INTEGER,
    comment_text CHARACTER VARYING(500),
    is_removed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),

    -- needed so the parent FK below can point at (id, review_id)
    CONSTRAINT uq_review_comment_id_review UNIQUE (id, review_id),

    -- deleting a review deletes every comment on it
    CONSTRAINT fk_review_comment_review FOREIGN KEY (review_id)
        REFERENCES public.review(id) ON DELETE CASCADE,
    CONSTRAINT fk_review_comment_member FOREIGN KEY (member_id)
        REFERENCES public.member(id),

    -- a reply has to be on the same review as the comment it replies to.
    -- matching on both columns means the database checks this for us
    CONSTRAINT fk_review_comment_parent FOREIGN KEY (parent_id, review_id)
        REFERENCES public.review_comment(id, review_id) ON DELETE CASCADE,

    CONSTRAINT chk_review_comment_not_self CHECK (parent_id <> id),

    -- a removed comment keeps its spot in the thread but loses its text.
    -- every other comment must have text
    CONSTRAINT chk_review_comment_text CHECK (
        is_removed = TRUE
        OR (comment_text IS NOT NULL AND char_length(btrim(comment_text)) > 0)
    )
);

CREATE INDEX idx_review_comment_review ON public.review_comment(review_id);
CREATE INDEX idx_review_comment_parent ON public.review_comment(parent_id);
