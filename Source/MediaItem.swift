//
//  MediaItem.swift
//  Twist
//
//  Created by Jais Cheema on 3/06/2016.
//  Copyright © 2016 Needle Apps. All rights reserved.
//

import Foundation
import AVFoundation

var myContext = 0
let kPlaybackLikelyToKeepUp = "playbackLikelyToKeepUp"

class MediaItem: NSObject {
    let player: Twist
    let itemURL: URL
    let itemIndex: Int

    var avPlayerItem: AVPlayerItem?
    var mediaResourceLoader: MediaItemResourceLoader?

    init(player: Twist, itemURL: URL, itemIndex: Int) {
        self.player = player
        self.itemURL = itemURL
        self.itemIndex = itemIndex
        super.init()

        self.setupResourceLoader()
        self.setupObservers()
    }

    func cleanup() {
        self.avPlayerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        self.avPlayerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges))
        self.avPlayerItem?.removeObserver(self, forKeyPath: kPlaybackLikelyToKeepUp)
        self.avPlayerItem = nil
        self.mediaResourceLoader?.session.invalidateAndCancel()
    }

    func setupResourceLoader() {
        self.mediaResourceLoader
            = MediaItemResourceLoader(mediaURL: itemURL,
                                      cachePath: player.dataSource?.twist(player, cacheFilePathForItemAtIndex: itemIndex),
                                      cachingEnabled: player.dataSource?.twist(player, shouldCacheItemAtIndex: itemIndex))

        self.mediaResourceLoader?.successfulDownloadCallback = { mediaItemURL in
            self.player.delegate?.twist(self.player,
                                        downloadedMedia: self.itemURL,
                                        forItemAtIndex: self.itemIndex)
        }

        self.avPlayerItem = AVPlayerItem(asset: self.mediaResourceLoader!.asset)
    }

    func setupObservers() {
        self.avPlayerItem!.addObserver(self,
                                       forKeyPath: #keyPath(AVPlayerItem.status),
                                       options: [.new, .initial],
                                       context: &myContext)
        self.avPlayerItem!.addObserver(self,
                                       forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges),
                                       options: [.new, .initial],
                                       context: &myContext)
        self.avPlayerItem!.addObserver(self,
                                       forKeyPath: kPlaybackLikelyToKeepUp,
                                       options: [.new],
                                       context: &myContext)
    }

    // MARK: Observer methods
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        guard context == &myContext else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }

        guard let playerItem = object as? AVPlayerItem,
              let keyPath = keyPath else { return }

        switch keyPath {
        case #keyPath(AVPlayerItem.status):
            switch playerItem.status {
            case .readyToPlay:
                Twist.log.twistInfo("Item is ready to play")
            case .failed:
                Twist.log.twistError("Failed to play current media item")
                self.player.changeState(TwistState.failed)
                self.player.cleanupCurrentItem()
                self.player.delegate?.twist(self.player,
                                            failedToPlayURL: self.itemURL,
                                            forItemAtIndex: self.itemIndex)
            case .unknown:
                Twist.log.twistDebug("Status updated but not ready to play")
            }
        case #keyPath(AVPlayerItem.loadedTimeRanges):
            if let availableDuration = self.availableDurationForCurrentItem() {
                let duration = playerItem.duration
                let totalDuration = CMTimeGetSeconds(duration)
                self.player.delegate?.twist(self.player,
                                            loaded: availableDuration,
                                            outOf: totalDuration)
            }
        case kPlaybackLikelyToKeepUp:
            if playerItem.isPlaybackLikelyToKeepUp {
                self.player.playRespectingForcePause()
            }
        default:
            Twist.log.twistDebug("Unhandled key :\(keyPath)")
        }
    }

    func availableDurationForCurrentItem() -> TimeInterval? {
        guard let avPlayerItem = self.avPlayerItem else { return nil }
        let loadedTimeRanges = avPlayerItem.loadedTimeRanges
        if let timeRange = loadedTimeRanges.first?.timeRangeValue {
            let startSeconds = CMTimeGetSeconds(timeRange.start)
            let durationSeconds = CMTimeGetSeconds(timeRange.duration)
            return startSeconds + durationSeconds
        }
        return nil
    }
}
