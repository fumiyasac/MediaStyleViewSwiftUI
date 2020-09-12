//
//  ContentView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2020/09/12.
//

import SwiftUI

struct ContentView: View {

    // MARK: - @State

    @State private var selectedTabBarIndex: AnimationTabBarIndex = .gallery

    // MARK: - body

    var body: some View {
        ZStack {
            switch self.selectedTabBarIndex {
            case .gallery:
                GalleryScreen()
            case .article:
                ArticleScreen()
            case .book:
                BookScreen()
            }
            VStack {
                Spacer()
                AnimationTabBar(selectedTabBarIndex: $selectedTabBarIndex)
            }
        }
        .animation(.spring())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
