//
//  RecipeInstructionSectionView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// レシピの調理手順セクション。手順文字列の配列を受け取り、番号付きで表示する。

import SwiftUI

struct RecipeInstructionSectionView: View {

    // MARK: - Property

    let steps: [String]

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("作り方")
                .font(.headline)

            if steps.isEmpty {
                Text("手順情報はありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(CalendarTheme.accent))
                        Text(step)
                            .font(.body)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}
