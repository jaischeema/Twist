//
//  TestMusicProvider.swift
//  Twist
//
//  Created by Jais Cheema on 8/04/2016.
//  Copyright © 2016 Needle Apps. All rights reserved.
//

import UIKit
import Twist

let sampleFiles = [
    "http://www.example.com/test.mp3"
]

class TestMusicProvider: NSObject, TwistDelegate, TwistDataSource {
    let itemCount: Int
    
    init(itemCount: Int = 0) {
        self.itemCount = itemCount
    }
    
    func twist(twist: Twist, urlForItemAtIndex itemIndex: Int, completionHandler completion: (NSURL) -> Void) {
        completion(NSURL(string: sampleFiles[itemIndex])!)
    }
    
    func twistTotalItemsInQueue(twist: Twist) -> Int {
        return itemCount
    }
}
