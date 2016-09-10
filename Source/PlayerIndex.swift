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
    
    var repeatMode: TwistRepeatMode = .all
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
    
    func removedItem(_ index: Int) {
        if currentIndex > index {
            currentIndex -= 1
        }
        self.maybeUpdateQueue()
    }

    func addedItem(_ index: Int) {
        if index <= currentIndex {
            currentIndex += 1
        }
        self.maybeUpdateQueue()
    }
    
    func movedItem(_ previousIndex: Int, to newIndex: Int) {
        if currentIndex == previousIndex {
            currentIndex = newIndex
        } else if currentIndex == newIndex {
            currentIndex = previousIndex
        }
    }

    func nextIndex(_ ignoreRepeat: Bool = false) -> Int? {
        if !ignoreRepeat && repeatMode == .single {
            return currentIndex
        }

        if let preferredNextIndex = self.player.dataSource?.twistPreferredNextItemIndex(self.player) {
            return preferredNextIndex
        }

        self.maybeUpdateQueue()

        let currentQueuePosition = self.indexQueue.index(of: self.currentIndex)!
        if currentQueuePosition >= self.cachedTotalItems - 1 {
            return repeatMode == .none ? nil : self.indexQueue.first
        } else {
            return self.indexQueue[currentQueuePosition + 1]
        }
    }

    func previousIndex(_ ignoreRepeat: Bool = false) -> Int? {
        if !ignoreRepeat && repeatMode == .single {
            return currentIndex
        }

        self.maybeUpdateQueue()
        
        let currentQueuePosition = self.indexQueue.index(of: self.currentIndex)!
        if currentQueuePosition <= 0 {
            return repeatMode == .none ? nil : self.indexQueue.last
        } else {
            return self.indexQueue[currentQueuePosition - 1]
        }
    }

    func maybeUpdateQueue(_ forced: Bool = false) {
        if self.cachedTotalItems != totalItems || forced {
            self.cachedTotalItems = totalItems
            self.shuffle ? self.shuffleIndexes() : self.resetIndexes()
        }
    }
    
    func resetIndexes() {
        self.indexQueue = Array(0..<cachedTotalItems)
    }

    func shuffleIndexes() {
        self.indexQueue = Array(0..<cachedTotalItems).sorted() {_, _ in arc4random() % 2 == 0 }
    }
}
