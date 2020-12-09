//
//  TabBarDesign.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2020/09/12.
//

import SwiftUI

struct TabBarDesign {

    // MEMO: TabBarの配色設定
    static let galleryActiveBackgroundColor = Color(hex: 0xff803a)
    static let articleActiveBackgroundColor = Color(hex: 0x52cb52)
    static let bookActiveBackgroundColor = Color(hex: 0xfeca2c)
    static let deactiveBackgroundColor = Color.black.opacity(0.25)

    static let activeForegroundColor = Color.white
    static let deactiveForegroundColor = Color.black.opacity(0.5)

    // MEMO: TabBarのサイズ・フォント・SFSymbol名
    static let iconImageRect: CGFloat = 6.0

    static let nameTextFont: Font = .system(size: 10.0, weight: .bold, design: .rounded)

    static let gallerySymbolName = "photo.fill"
    static let articleSymbolName = "doc.text.fill"
    static let bookSymbolName = "book"
}
