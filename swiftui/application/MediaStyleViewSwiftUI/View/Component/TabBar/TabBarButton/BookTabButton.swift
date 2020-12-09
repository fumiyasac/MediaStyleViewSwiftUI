//
//  BookTabButton.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2020/09/12.
//

import SwiftUI

struct BookTabButton: View {

    // MARK: - Property

    private let symbolName: String = TabBarDesign.bookSymbolName
    private let nameTextFont: Font = TabBarDesign.nameTextFont

    private let imageWidth: CGFloat = TabBarDesign.iconImageRect
    private let imageHeight: CGFloat = TabBarDesign.iconImageRect

    private let activeForegroundColor: Color = TabBarDesign.activeForegroundColor
    private let activeBackgroundColor: Color = TabBarDesign.bookActiveBackgroundColor
    private let activeTextColor: Color = TabBarDesign.bookActiveBackgroundColor

    private let deactiveForegroundColor: Color = TabBarDesign.deactiveForegroundColor
    private let deactiveBackgroundColor: Color = TabBarDesign.deactiveBackgroundColor
    private let deactiveTextColor: Color = TabBarDesign.deactiveBackgroundColor

    // MARK: - @Binding

    @Binding var selectedTabBarIndex: AnimationTabBarIndex

    var body: some View {
        Button(
            action: {
                selectedTabBarIndex = .book
            },
            label: {
                VStack {
                    let shouldActiveColor = (selectedTabBarIndex == .book)
                    Image(systemName: symbolName)
                        .frame(width: imageWidth, height: imageHeight)
                        .foregroundColor(shouldActiveColor ? activeForegroundColor : deactiveForegroundColor)
                        .padding()
                        .background(shouldActiveColor ? activeBackgroundColor : deactiveBackgroundColor)
                        .clipShape(Circle())
                    Text(AnimationTabBarIndex.book.getTitle())
                        .foregroundColor(shouldActiveColor ? activeTextColor : deactiveTextColor)
                        .font(nameTextFont)
                }
            }
        )
    }
}

struct BookTabButton_Previews: PreviewProvider {
    static var previews: some View {
        BookTabButton(selectedTabBarIndex: .constant(.book))
    }
}
