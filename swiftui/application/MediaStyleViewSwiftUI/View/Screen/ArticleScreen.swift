//
//  ArticleScreen.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2020/09/12.
//

import SwiftUI

struct ArticleScreen: View {
    var body: some View {
        ZStack {
            TabBarDesign.articleActiveBackgroundColor
                .edgesIgnoringSafeArea(.all)
            Text("Article Screen")
        }
    }
}

struct ArticleScreen_Previews: PreviewProvider {
    static var previews: some View {
        ArticleScreen()
    }
}
