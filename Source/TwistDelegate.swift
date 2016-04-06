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
    func twist(twist: Twist, progressed: NSTimeInterval)
    func twistCurrentItemChanged(item: AVPlayerItem)
    func twistStatusChanged()
}

public extension TwistDelegate {
    func twist(twist: Twist, loaded: NSTimeInterval, outOf totalDuration: NSTimeInterval) {}
    func twist(twist: Twist, progressed: NSTimeInterval) {}
    func twistCurrentItemChanged(item: AVPlayerItem) {}
    func twistStatusChanged() {}
}