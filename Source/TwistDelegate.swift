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
    func twist(twist: Twist, loaded: NSTimeInterval, outOf totalDuration: NSTimeInterval)
    func twist(twist: Twist, playedTo currentTime: Double, outOf totalDuration: Double)
    func twist(twist: Twist, startedPlayingItemAtIndex itemIndex: Int)
    func twist(twist: Twist, failedToPlayURL itemURL: NSURL, forItemAtIndex itemIndex: Int)
    func twist(twist: Twist, downloadedMedia fileItemURL: NSURL, forItemAtIndex itemIndex: Int)
    func twistStateChanged(twist: Twist)
}

public extension TwistDelegate {
    func twist(twist: Twist, loaded: NSTimeInterval, outOf totalDuration: NSTimeInterval) {}
    func twist(twist: Twist, playedTo currentTime: Double, outOf totalDuration: Double) {}
    func twist(twist: Twist, startedPlayingItemAtIndex itemIndex: Int) {}
    func twistStateChanged(twist: Twist) {}
    func twist(twist: Twist, downloadedMedia fileItemURL: NSURL, forItemAtIndex itemIndex: Int) {}

    func twist(twist: Twist, failedToPlayURL itemURL: NSURL, forItemAtIndex itemIndex: Int) {
        twist.next()
    }
}