//
//  GalleryScreen.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2020/09/12.
//

import SwiftUI

struct GalleryScreen: View {
    var body: some View {
        ZStack {
            TabBarDesign.galleryActiveBackgroundColor
                .edgesIgnoringSafeArea(.all)
            Text("Gallery Screen")
        }
    }
}

struct GalleryScreen_Previews: PreviewProvider {
    static var previews: some View {
        GalleryScreen()
    }
}
