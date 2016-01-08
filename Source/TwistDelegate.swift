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
    func twistCurrentItemChanged(item: AVPlayerItem)
}

public extension TwistDelegate {
    func twistCurrentItemChanged(item: AVPlayerItem) {}
}