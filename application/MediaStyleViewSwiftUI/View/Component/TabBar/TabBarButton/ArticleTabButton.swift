//
//  ArticleTabButton.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2020/09/12.
//

import SwiftUI

struct ArticleTabButton: View {

    // MARK: - Property

    private let symbolName: String = TabBarDesign.articleSymbolName
    private let nameTextFont: Font = TabBarDesign.nameTextFont

    private let imageWidth: CGFloat = TabBarDesign.iconImageRect
    private let imageHeight: CGFloat = TabBarDesign.iconImageRect

    private let activeForegroundColor: Color = TabBarDesign.activeForegroundColor
    private let activeBackgroundColor: Color = TabBarDesign.articleActiveBackgroundColor
    private let activeTextColor: Color = TabBarDesign.articleActiveBackgroundColor

    private let deactiveForegroundColor: Color = TabBarDesign.deactiveForegroundColor
    private let deactiveBackgroundColor: Color = TabBarDesign.deactiveBackgroundColor
    private let deactiveTextColor: Color = TabBarDesign.deactiveBackgroundColor

    // MARK: - @Binding

    @Binding var selectedTabBarIndex: AnimationTabBarIndex

    // MARK: - body

    var body: some View {
        Button(
            action: {
                selectedTabBarIndex = .article
            },
            label: {
                VStack {
                    let shouldActiveColor = (selectedTabBarIndex == .article)
                    Image(systemName: symbolName)
                        .frame(width: imageWidth, height: imageHeight)
                        .foregroundColor(shouldActiveColor ? activeForegroundColor : deactiveForegroundColor)
                        .padding()
                        .background(shouldActiveColor ? activeBackgroundColor : deactiveBackgroundColor)
                        .clipShape(Circle())
                    Text(AnimationTabBarIndex.article.getTitle())
                        .foregroundColor(shouldActiveColor ? activeTextColor : deactiveTextColor)
                        .font(nameTextFont)
                }
            }
        )
    }
}

struct ArticleTabButton_Previews: PreviewProvider {
    static var previews: some View {
        ArticleTabButton(selectedTabBarIndex: .constant(.article))
    }
}
