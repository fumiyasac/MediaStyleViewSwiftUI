//
//  AnimationTabBar.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2020/09/12.
//

import SwiftUI

struct AnimationTabBar: View {

    // MARK: - @Binding

    @Binding var selectedTabBarIndex: AnimationTabBarIndex

    // MARK: - body

    var body: some View {
        HStack {
            Spacer()
                .frame(width: 36.0)
            GalleryTabButton(selectedTabBarIndex: $selectedTabBarIndex)
            Spacer()
            ArticleTabButton(selectedTabBarIndex: $selectedTabBarIndex)
            Spacer()
            BookTabButton(selectedTabBarIndex: $selectedTabBarIndex)
            Spacer()
                .frame(width: 36.0)
        }
        .frame(width: UIScreen.main.bounds.width - 48.0, height: 72.0)
        .background(Color(hex: 0xf7f7f7))
        .cornerRadius(36.0)
        .overlay(
            RoundedRectangle(cornerRadius: 36.0)
                .stroke(Color(hex: 0xbbbbbb), lineWidth: 0.75)
        )
        .animation(.spring())
    }
}

struct AnimationTabBar_Previews: PreviewProvider {
    static var previews: some View {
        AnimationTabBar(selectedTabBarIndex: .constant(.gallery))
    }
}
