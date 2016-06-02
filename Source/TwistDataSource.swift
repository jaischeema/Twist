//
//  TwistDataSource.swift
//  Twist
//
//  Created by Jais Cheema on 8/01/2016.
//  Copyright © 2016 Needle Apps. All rights reserved.
//

import Foundation

public protocol TwistDataSource {
    func twistTotalItemsInQueue(twist: Twist) -> Int
    func twist(twist: Twist, urlForItemAtIndex itemIndex: Int, completionHandler completion: (NSURL?, NSError?) -> Void)
    
    // Optional
    func twist(twist: Twist, shouldCacheItemAtIndex itemIndex: Int) -> Bool
    func twist(twist: Twist, cacheFilePathForItemAtIndex itemIndex: Int) -> String
    func twist(twist: Twist, mediaInfoForItemAtIndex itemIndex: Int) -> TwistMediaInfo
}

public extension TwistDataSource {
    func twist(twist: Twist, shouldCacheItemAtIndex itemIndex: Int) -> Bool {
        return false
    }
    
    func twist(twist: Twist, cacheFilePathForItemAtIndex itemIndex: Int) -> String {
        return ""
    }
    
    func twist(twist: Twist, mediaInfoForItemAtIndex itemIndex: Int) -> TwistMediaInfo {
        return TwistMediaInfo(title: "", artist: "", album: "")
    }
}
