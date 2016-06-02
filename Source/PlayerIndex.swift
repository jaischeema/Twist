//
//  PlayerIndex.swift
//  Twist
//
//  Created by Jais Cheema on 2/06/2016.
//  Copyright © 2016 Needle Apps. All rights reserved.
//

import Foundation

class PlayerIndex: NSObject {
    let player: Twist
    
    var currentIndex = 0
    var cachedTotalItems : Int = 0
    var indexQueue = [Int]()
    
    var repeatMode: TwistRepeatMode = .All
    var shuffle: Bool = false {
        didSet {
            if oldValue != shuffle {
                self.maybeUpdateQueue(true)
            }
        }
    }
    
    init(player: Twist) {
        self.player = player
    }
    
    var totalItems: Int {
        guard let dataSource = player.dataSource else { return 0 }
        return dataSource.twistTotalItemsInQueue(player)
    }
    
    func itemRemovedAtIndex(index: Int) {
        if currentIndex < index {
            currentIndex -= 1
            self.maybeUpdateQueue(true)
        }
    }
    
    func movedItem(previousIndex: Int, toIndex newIndex: Int) {
        if currentIndex == previousIndex {
            currentIndex = newIndex
        } else if currentIndex == newIndex {
            currentIndex = previousIndex
        }
    }
    
    var nextIndex: Int? {
        guard repeatMode != .None else { return nil }
        guard repeatMode != .Single else { return currentIndex }
        
        self.maybeUpdateQueue()

        let currentQueuePosition = self.indexQueue.indexOf(self.currentIndex)!
        if currentQueuePosition >= self.cachedTotalItems - 1 {
            return self.indexQueue.first
        } else {
            return self.indexQueue[currentQueuePosition + 1]
        }
    }

    var previousIndex: Int? {
        guard repeatMode != .None else { return nil }
        guard repeatMode != .Single else { return currentIndex }

        self.maybeUpdateQueue()
        
        let currentQueuePosition = self.indexQueue.indexOf(self.currentIndex)!
        if currentQueuePosition <= 0 {
            return self.indexQueue.last
        } else {
            return self.indexQueue[currentQueuePosition - 1]
        }
    }

    func maybeUpdateQueue(forced: Bool = false) {
        if self.cachedTotalItems != totalItems || forced {
            self.cachedTotalItems = totalItems
            self.shuffle ? self.shuffleIndexes() : self.resetIndexes()
        }
    }
    
    func resetIndexes() {
        self.indexQueue = Array(0..<cachedTotalItems)
    }

    func shuffleIndexes() {
        self.indexQueue = Array(0..<cachedTotalItems).sort() {_, _ in arc4random() % 2 == 0 }
    }
}