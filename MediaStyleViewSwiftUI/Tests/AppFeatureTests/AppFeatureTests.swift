//
//  AppFeatureTests.swift
//  
//
//  Created by 酒井文也 on 2023/02/16.
//

@testable import MediaStyleViewSwiftUI

import XCTest

final class AppFeatureTests: XCTestCase {

    override func setUpWithError() throws {}

    override func tearDownWithError() throws {}

    // MEMO: 試しのUnitTestを追加してみる

    func testExample1() throws {
        let result = true
        XCTAssertTrue(result)
    }

    func testExample2() throws {
        let result = "今日はうどんです"
        XCTAssertNotEqual(result, "今日はラーメンです")
    }
}
