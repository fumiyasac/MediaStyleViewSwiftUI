//
//  MediaStyleViewSwiftUIApp.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2020/09/12.
//

import SwiftUI
import UIKit

@main
struct MediaStyleViewSwiftUIApp: App {

    // MARK: - Initializer

    init() {
        // MEMO: NavigationBarの色を白色に合わせる対応
        let newNavAppearance = UINavigationBarAppearance()
        newNavAppearance.configureWithTransparentBackground()
        newNavAppearance.backgroundColor = UIColor.white
        UINavigationBar.appearance().standardAppearance = newNavAppearance
    }

    // MARK: - body

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
