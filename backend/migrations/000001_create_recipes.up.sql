-- レシピ Master。id は Swift の RecipeID(recipe-01 等)と一致させる。
CREATE TABLE recipes (
    id              VARCHAR(64)  NOT NULL,
    title           VARCHAR(255) NOT NULL,
    summary         VARCHAR(500) NOT NULL,
    category        VARCHAR(32)  NOT NULL,
    cooking_minutes INT          NOT NULL,
    calories        INT          NOT NULL,
    servings        INT          NOT NULL,
    image_reference VARCHAR(255) NULL,
    created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    -- カテゴリ絞り込みの検索効率のため索引を張る
    KEY idx_recipes_category (category)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
