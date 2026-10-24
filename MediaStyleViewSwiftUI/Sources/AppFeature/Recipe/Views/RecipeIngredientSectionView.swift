//
//  RecipeIngredientSectionView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// レシピの材料セクション。Domain Modelの構造を知りすぎないよう、文字列配列と人数だけ受け取る。

import SwiftUI

struct RecipeIngredientSectionView: View {

    // MARK: - Property

    let ingredients: [String]
    let servings: Int

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("材料")
                    .font(.headline)
                Spacer()
                Text("\(servings)人分")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if ingredients.isEmpty {
                Text("材料情報はありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(ingredients.enumerated()), id: \.offset) { _, ingredient in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle()
                            .fill(CalendarTheme.accent)
                            .frame(width: 5, height: 5)
                        Text(ingredient)
                            .font(.body)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}
