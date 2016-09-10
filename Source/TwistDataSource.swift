//
//  TwistDataSource.swift
//  Twist
//
//  Created by Jais Cheema on 8/01/2016.
//  Copyright © 2016 Needle Apps. All rights reserved.
//

import Foundation

public protocol TwistDataSource {
    func twistTotalItemsInQueue(_ twist: Twist) -> Int
    func twist(_ twist: Twist, urlForItemAtIndex itemIndex: Int, completionHandler completion: @escaping (URL?, NSError?) -> Void)
    
    // Optional
    func twist(_ twist: Twist, shouldCacheItemAtIndex itemIndex: Int) -> Bool
    func twist(_ twist: Twist, cacheFilePathForItemAtIndex itemIndex: Int) -> String
    func twist(_ twist: Twist, mediaInfoForItemAtIndex itemIndex: Int) -> TwistMediaInfo
    func twistPreferredNextItemIndex(_ twist: Twist) -> Int?
}

public extension TwistDataSource {
    func twist(_ twist: Twist, shouldCacheItemAtIndex itemIndex: Int) -> Bool {
        return false
    }
    
    func twist(_ twist: Twist, cacheFilePathForItemAtIndex itemIndex: Int) -> String {
        return ""
    }
    
    func twist(_ twist: Twist, mediaInfoForItemAtIndex itemIndex: Int) -> TwistMediaInfo {
        return TwistMediaInfo(title: "", artist: "", album: "")
    }

    func twistPreferredNextItemIndex(_ twist: Twist) -> Int? {
        return nil
    }
}
