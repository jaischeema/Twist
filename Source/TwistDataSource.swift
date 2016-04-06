//
//  TwistDataSource.swift
//  Twist
//
//  Created by Jais Cheema on 8/01/2016.
//  Copyright © 2016 Needle Apps. All rights reserved.
//

import Foundation

public struct TwistMediaInfo {
    let title: String
    let artist: String
    let album: String
    var albumArt: UIImage?
    
    public init(title: String, artist: String, album: String, albumArt: UIImage? = nil) {
        self.title    = title
        self.artist   = artist
        self.album    = album
        self.albumArt = albumArt
    }
}

public protocol TwistDataSource {
    func twistURLForItemAtIndex(index: Int, completion: (NSURL) -> Void)
    func twistShouldCacheItemAtIndex(index: Int) -> Bool
    func twistCacheFilePathURLForItemAtIndex(index: Int) -> NSURL
    func twistNumberOfItems() -> Int
    func twistMediaInfoForItemAtIndex(index: Int) -> TwistMediaInfo
}

public extension TwistDataSource {
    func twistMediaInfoForItemAtIndex(index: Int) -> TwistMediaInfo {
        return TwistMediaInfo(title: "", artist: "", album: "")
    }
    
    func twistCacheFilePathURLForItemAtIndex(index: Int) -> NSURL {
        return NSURL()
    }
    
    func twistShouldCacheItemAtIndex(index: Int) -> Bool {
        return false
    }
}
