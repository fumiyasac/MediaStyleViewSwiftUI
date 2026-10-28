-- 材料と手順。position で順序を保証し、(recipe_id, position) を一意にする。
-- content は Swift の [String]（「材料名 分量」/手順文）1 行に対応する自由文。
CREATE TABLE recipe_ingredients (
    id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    recipe_id VARCHAR(64)     NOT NULL,
    position  INT             NOT NULL,
    content   VARCHAR(500)    NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_recipe_ingredient_pos (recipe_id, position),
    KEY idx_recipe_ingredients_recipe (recipe_id),
    CONSTRAINT fk_recipe_ingredients_recipe
        FOREIGN KEY (recipe_id) REFERENCES recipes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE recipe_steps (
    id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    recipe_id VARCHAR(64)     NOT NULL,
    position  INT             NOT NULL,
    content   VARCHAR(1000)   NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_recipe_step_pos (recipe_id, position),
    KEY idx_recipe_steps_recipe (recipe_id),
    CONSTRAINT fk_recipe_steps_recipe
        FOREIGN KEY (recipe_id) REFERENCES recipes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
