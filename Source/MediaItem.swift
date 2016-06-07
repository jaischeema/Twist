//
//  MediaItem.swift
//  Twist
//
//  Created by Jais Cheema on 3/06/2016.
//  Copyright © 2016 Needle Apps. All rights reserved.
//

import Foundation
import AVFoundation

var myContext  = 0
let kStatusKey              = "status"
let kLoadedTimeRangesKey    = "loadedTimeRanges"
let KPlaybackBufferEmptyKey = "playbackBufferEmpty"
let kPlaybackLikelyToKeepUp = "playbackLikelyToKeepUp"

class MediaItem: NSObject {
    let player: Twist
    let itemURL: NSURL
    let itemIndex: Int

    var avPlayerItem: AVPlayerItem?
    var mediaResourceLoader: MediaItemResourceLoader?

    init(player: Twist, itemURL: NSURL, itemIndex: Int) {
        self.player = player
        self.itemURL = itemURL
        self.itemIndex = itemIndex
        super.init()

        self.setupResourceLoader()
        self.setupObservers()
    }

    func cleanup() {
        self.avPlayerItem?.removeObserver(self, forKeyPath: kStatusKey)
        self.avPlayerItem?.removeObserver(self, forKeyPath: kLoadedTimeRangesKey)
        self.avPlayerItem?.removeObserver(self, forKeyPath: kPlaybackLikelyToKeepUp)
        self.avPlayerItem?.removeObserver(self, forKeyPath: KPlaybackBufferEmptyKey)
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
        self.avPlayerItem!.addObserver(
            self,
            forKeyPath: kStatusKey,
            options: NSKeyValueObservingOptions.New.union(NSKeyValueObservingOptions.Initial),
            context: &myContext
        )
        self.avPlayerItem!.addObserver(
            self,
            forKeyPath: kLoadedTimeRangesKey,
            options: NSKeyValueObservingOptions.New.union(NSKeyValueObservingOptions.Initial),
            context: &myContext
        )
        self.avPlayerItem!.addObserver(self,
                                       forKeyPath: KPlaybackBufferEmptyKey,
                                       options: NSKeyValueObservingOptions.New,
                                       context: &myContext)
        self.avPlayerItem!.addObserver(self,
                                       forKeyPath: kPlaybackLikelyToKeepUp,
                                       options: NSKeyValueObservingOptions.New,
                                       context: &myContext)
    }

    // MARK: Observer methods
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if context == &myContext {
            if let playerItem = object as? AVPlayerItem {
                guard let keyPath = keyPath else { return }
                switch keyPath {
                case kStatusKey:
                    switch playerItem.status {
                    case .ReadyToPlay:
                        self.player.play()
                    case .Failed:
                        debug("Failed to play current media item")
                        self.player.changeState(TwistState.Failed)
                        self.player.cleanupCurrentItem()
                        self.player.delegate?.twist(self.player,
                                                    failedToPlayURL: self.itemURL,
                                                    forItemAtIndex: self.itemIndex)
                    case .Unknown:
                        debug("Status updated but not ready to play")
                    }
                case kLoadedTimeRangesKey:
                    if let availableDuration = self.availableDurationForCurrentItem() {
                        let duration = playerItem.duration
                        let totalDuration = CMTimeGetSeconds(duration)
                        self.player.delegate?.twist(self.player,
                                                    loaded: availableDuration,
                                                    outOf: totalDuration)
                    }
                case KPlaybackBufferEmptyKey:
                    if playerItem.playbackBufferEmpty {
                        self.player.changeState(.Buffering)
                    }
                case kPlaybackLikelyToKeepUp:
                    if playerItem.playbackLikelyToKeepUp {
                        self.player.play()
                    }
                default:
                    print("Unhandled key :\(keyPath)")
                }
            }
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }

    func availableDurationForCurrentItem() -> NSTimeInterval? {
        guard let avPlayerItem = self.avPlayerItem else { return nil }
        let loadedTimeRanges = avPlayerItem.loadedTimeRanges
        if let timeRange = loadedTimeRanges.first?.CMTimeRangeValue {
            let startSeconds = CMTimeGetSeconds(timeRange.start)
            let durationSeconds = CMTimeGetSeconds(timeRange.duration)
            return startSeconds + durationSeconds
        }
        return nil
    }
}
