//
//  TwistTests.swift
//  TwistTests
//
//  Created by Jais Cheema on 8/01/2016.
//  Copyright © 2016 Needle Apps. All rights reserved.
//

import XCTest
@testable import Twist

class TwistTests: XCTestCase {
    var player: Twist?
    var provider: TestMusicProvider? {
        didSet {
            self.player?.delegate   = self.provider
            self.player?.dataSource = self.provider
        }
    }
    
    override func setUp() {
        super.setUp()
        self.player   = Twist()
        self.provider = TestMusicProvider()
    }
    
    override func tearDown() {
        self.player   = nil
        self.provider = nil
    }
    
    func testPlayerStateWhenPlayerIsEmpty() {
        assert(self.player!.currentState == .Waiting)
        self.player?.play()
        assert(self.player!.currentState == .Waiting)
        self.player?.next()
        assert(self.player!.currentState == .Waiting)
        self.player?.previous()
        assert(self.player!.currentState == .Waiting)
    }
    
    func testPlayerStateWhenQueueIsNotEmpty() {
        self.provider = TestMusicProvider(itemCount: 1)
        assert(self.player!.currentState == .Waiting)
        self.player?.play()
    }
}
