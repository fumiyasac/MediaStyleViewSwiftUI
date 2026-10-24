//
//  MealLogEditorSheet.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// 「作った記録を追加」のSheet。標準Formで調理日・評価・メモを入力する。
// 保存中はProgressViewと対話的dismiss抑止で二重操作・中断を防ぎ、保存成功時のみ閉じる。
// 保存成功のSummaryはonSavedで呼び出し側へ渡し、Calendar/Detailへ反映させる。

import SwiftUI

struct MealLogEditorSheet: View {

    // MARK: - Property

    @State private var viewModel: MealLogEditorViewModel
    @Environment(\.dismiss) private var dismiss

    private let recipeTitle: String
    private let onSaved: (MealLogSummary) -> Void

    // MARK: - Initializer

    init(
        recipeID: RecipeID,
        recipeTitle: String,
        defaultCookedAt: Date,
        repository: any MealLogRepository,
        onSaved: @escaping (MealLogSummary) -> Void
    ) {
        _viewModel = State(
            initialValue: MealLogEditorViewModel(
                repository: repository,
                initialState: .initial(recipeID: recipeID, cookedAt: defaultCookedAt)
            )
        )
        self.recipeTitle = recipeTitle
        self.onSaved = onSaved
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section("レシピ") {
                    Text(recipeTitle)
                        .font(.headline)
                }

                Section("調理の記録") {
                    DatePicker(
                        "調理日",
                        selection: bindingCookedAt,
                        displayedComponents: .date
                    )

                    Picker("評価", selection: bindingRating) {
                        ForEach(1...5, id: \.self) { value in
                            Text(String(repeating: "★", count: value)).tag(value)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("メモ")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("メモ（任意）", text: bindingMemo, axis: .vertical)
                            .lineLimit(2...5)
                    }
                }

                if let message = viewModel.state.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("作った記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .disabled(viewModel.state.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.state.isSaving {
                        ProgressView()
                    } else {
                        Button("保存") { viewModel.send(.save) }
                    }
                }
            }
            // 保存中は対話的dismissを抑止し、永続化を中断させない
            .interactiveDismissDisabled(viewModel.state.isSaving)
            // 保存成功時のみ、Summaryを通知してから閉じる
            .onChange(of: viewModel.state.savedSummary) { _, saved in
                if let saved {
                    onSaved(saved)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Private Binding

    private var bindingCookedAt: Binding<Date> {
        Binding(get: { viewModel.state.cookedAt }, set: { viewModel.send(.setCookedAt($0)) })
    }

    private var bindingRating: Binding<Int> {
        Binding(get: { viewModel.state.rating }, set: { viewModel.send(.setRating($0)) })
    }

    private var bindingMemo: Binding<String> {
        Binding(get: { viewModel.state.memo }, set: { viewModel.send(.setMemo($0)) })
    }
}
