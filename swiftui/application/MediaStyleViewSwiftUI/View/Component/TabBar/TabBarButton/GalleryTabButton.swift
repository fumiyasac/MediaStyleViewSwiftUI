//
//  GalleryTabButton.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2020/09/12.
//

import SwiftUI

struct GalleryTabButton: View {

    // MARK: - Property

    private let symbolName: String = TabBarDesign.gallerySymbolName
    private let nameTextFont: Font = TabBarDesign.nameTextFont

    private let imageWidth: CGFloat = TabBarDesign.iconImageRect
    private let imageHeight: CGFloat = TabBarDesign.iconImageRect

    private let activeForegroundColor: Color = TabBarDesign.activeForegroundColor
    private let activeBackgroundColor: Color = TabBarDesign.galleryActiveBackgroundColor
    private let activeTextColor: Color = TabBarDesign.galleryActiveBackgroundColor

    private let deactiveForegroundColor: Color = TabBarDesign.deactiveForegroundColor
    private let deactiveBackgroundColor: Color = TabBarDesign.deactiveBackgroundColor
    private let deactiveTextColor: Color = TabBarDesign.deactiveBackgroundColor

    // MARK: - @Binding

    @Binding var selectedTabBarIndex: AnimationTabBarIndex

    // MARK: - body

    var body: some View {
        Button(
            action: {
                selectedTabBarIndex = .gallery
            },
            label: {
                VStack {
                    let shouldActiveColor = (selectedTabBarIndex == .gallery)
                    Image(systemName: symbolName)
                        .frame(width: imageWidth, height: imageHeight)
                        .foregroundColor(shouldActiveColor ? activeForegroundColor : deactiveForegroundColor)
                        .padding()
                        .background(shouldActiveColor ? activeBackgroundColor : deactiveBackgroundColor)
                        .clipShape(Circle())
                    Text(AnimationTabBarIndex.gallery.getTitle())
                        .foregroundColor(shouldActiveColor ? activeTextColor : deactiveTextColor)
                        .font(nameTextFont)
                }
            }
        )
    }
}

struct GalleryTabButton_Previews: PreviewProvider {
    static var previews: some View {
        GalleryTabButton(selectedTabBarIndex: .constant(.gallery))
    }
}
