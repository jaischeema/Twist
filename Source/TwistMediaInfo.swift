//
//  UtilClasses.swift
//  Twist
//
//  Created by Jais Cheema on 3/06/2016.
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
