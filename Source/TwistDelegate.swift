//
//  TwistDelegate.swift
//  Twist
//
//  Created by Jais Cheema on 8/01/2016.
//  Copyright © 2016 Needle Apps. All rights reserved.
//

import Foundation
import AVFoundation

public protocol TwistDelegate {
    func twist(_ twist: Twist, loaded: TimeInterval, outOf totalDuration: TimeInterval)
    func twist(_ twist: Twist, playedTo currentTime: Double, outOf totalDuration: Double)
    func twist(_ twist: Twist, startedPlayingItemAtIndex itemIndex: Int)
    func twist(_ twist: Twist, failedToPlayURL itemURL: URL, forItemAtIndex itemIndex: Int)
    func twist(_ twist: Twist, downloadedMedia fileItemURL: URL, forItemAtIndex itemIndex: Int)
    func twist(_ twist: Twist, willChangeStateFrom fromState: TwistState, to newState: TwistState)
    func twist(_ twist: Twist, didChangeStateFrom fromState: TwistState, to newState: TwistState)
}

public extension TwistDelegate {
    func twist(_ twist: Twist, loaded: TimeInterval, outOf totalDuration: TimeInterval) {}
    func twist(_ twist: Twist, playedTo currentTime: Double, outOf totalDuration: Double) {}
    func twist(_ twist: Twist, startedPlayingItemAtIndex itemIndex: Int) {}
    func twist(_ twist: Twist, downloadedMedia fileItemURL: URL, forItemAtIndex itemIndex: Int) {}
    func twist(_ twist: Twist, willChangeStateFrom fromState: TwistState, to newState: TwistState) {}
    func twist(_ twist: Twist, didChangeStateFrom fromState: TwistState, to newState: TwistState) {}

    func twist(_ twist: Twist, failedToPlayURL itemURL: URL, forItemAtIndex itemIndex: Int) {
        twist.next()
    }
}
