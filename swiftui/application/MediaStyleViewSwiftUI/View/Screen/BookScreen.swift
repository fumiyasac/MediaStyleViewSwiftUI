//
//  BookScreen.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2020/09/12.
//

import SwiftUI

struct BookScreen: View {
    var body: some View {
        ZStack {
            TabBarDesign.bookActiveBackgroundColor
                .edgesIgnoringSafeArea(.all)
            Text("Book Screen")
        }
    }
}

struct BookScreen_Previews: PreviewProvider {
    static var previews: some View {
        BookScreen()
    }
}
