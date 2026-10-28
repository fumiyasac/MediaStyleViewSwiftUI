-- 掲載割当。publication_date は DATE(時刻なし)で、Swift の日付キー(yyyy-MM-dd)と一致させる。
-- 同じ recipe が複数日に、同じ日に複数 recipe が載ることを許可する（PK は割当 ID）。
CREATE TABLE daily_recipe_entries (
    id               VARCHAR(96) NOT NULL,
    publication_date DATE        NOT NULL,
    recipe_id        VARCHAR(64) NOT NULL,
    display_order    INT         NOT NULL DEFAULT 0,
    created_at       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    -- 掲載期間検索の効率化
    KEY idx_daily_entries_date (publication_date),
    KEY idx_daily_entries_recipe (recipe_id),
    CONSTRAINT fk_daily_entries_recipe
        FOREIGN KEY (recipe_id) REFERENCES recipes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
