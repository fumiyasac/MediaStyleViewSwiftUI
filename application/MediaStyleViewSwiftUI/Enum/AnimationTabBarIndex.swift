//
//  AnimationTabBarIndex.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2020/09/12.
//

import Foundation

enum AnimationTabBarIndex: Int, CaseIterable {

    case gallery
    case article
    case book

    // MARK: - Function

    func getTitle() -> String {
        switch self {
        case .gallery:
            return "写真一覧"
        case .article:
            return "記事一覧"
        case .book:
            return "書籍一覧"
        }
    }
}
