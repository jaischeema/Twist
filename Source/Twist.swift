//
//  Twist.swift
//  Twist
//
//  Created by Jais Cheema on 8/01/2016.
//  Copyright © 2016 Needle Apps. All rights reserved.
//

import Foundation
import AVFoundation
import MediaPlayer

let debugging  = true
var myContext  = 0
let kStatusKey = "status"
let kLoadedTimeRangesKey = "loadedTimeRanges"

func debug(message: Any) {
    if debugging {
        print("Twist: \(message)")
    }
}

public enum TwistRepeatMode: Int {
    case None = 0
    case Single
    case All
}

public enum TwistState: Int {
    case Waiting = 0
    case Buffering
    case Ready
    case Playing
    case Paused
}

public class Twist: NSObject, AVAudioPlayerDelegate {
    public static let defaultPlayer = Twist()
    
    // Public Variables
    public var repeatMode: TwistRepeatMode = .None
    public var shuffle: Bool = false
    public var dataSource: TwistDataSource?
    public var delegate: TwistDelegate?
    
    // Public getters, private setters
    private(set) public var currentState = TwistState.Waiting
    private(set) public var currentIndex: Int = 0
    private(set) public var currentPlayerItem: AVPlayerItem?

    // Private variables
    var player: AVPlayer?
    var preConfigured: Bool = false
    var mediaItem: MediaItem?
    var periodicObserver: AnyObject?
    
    func preAction() {
        self.preConfigured = true
        self.player = AVPlayer()
        self.registerAudioSession()
        self.registerListeners()
    }
    
    // This could potentially be for UI
    public func refresh() {
        self.updateMPRemoteCommandButtons()
    }
    
    func registerListener(selector: Selector, notification: String) {
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: selector,
            name: notification,
            object: nil
        )
    }
    
    func registerListeners() {
        registerListener(#selector(Twist.playerItemDidReachEnd(_:)), notification: AVPlayerItemDidPlayToEndTimeNotification)
        registerListener(#selector(Twist.playerItemFailedToPlayEndTime(_:)), notification: AVPlayerItemFailedToPlayToEndTimeNotification)
        registerListener(#selector(Twist.playerItemPlaybackStall(_:)), notification: AVPlayerItemPlaybackStalledNotification)
        registerListener(#selector(Twist.interruption(_:)), notification: AVAudioSessionInterruptionNotification)
        registerListener(#selector(Twist.routeChange(_:)), notification: AVAudioSessionRouteChangeNotification)
        
        let commandCenter = MPRemoteCommandCenter.sharedCommandCenter()
        commandCenter.nextTrackCommand.addTarget(self, action: #selector(Twist.next))
        commandCenter.previousTrackCommand.addTarget(self, action: #selector(Twist.previous))
        commandCenter.playCommand.addTarget(self, action: #selector(Twist.play(_:)))
        commandCenter.pauseCommand.addTarget(self, action: #selector(Twist.pause))
        commandCenter.togglePlayPauseCommand.addTarget(self, action: #selector(Twist.togglePlayPause))
    }
    
    func playerItemDidReachEnd(notification: NSNotification) {
        self.next()
    }
    
    func playerItemFailedToPlayEndTime(notification: NSNotification) {
        self.next()
    }
    
    func playerItemPlaybackStall(notification: NSNotification) {
        debug("playback stalled")
    }
    
    func interruption(notification: NSNotification) {
        debug("interuppted")
    }
    
    func routeChange(notification: NSNotification) {
        debug("route")
    }
    
    func registerAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        
        if audioSession.category != AVAudioSessionCategoryPlayback {
            let device = UIDevice.currentDevice()
            if device.multitaskingSupported {
                do {
                    try audioSession.setCategory(AVAudioSessionCategoryPlayback)
                } catch let error as NSError {
                    debug("Set Category error: \(error.localizedDescription)")
                }
                do {
                    try audioSession.setActive(true)
                } catch let error as NSError {
                    debug("Set active error: \(error.localizedDescription)")
                }
            }
        } else {
            debug("Unable to register background playback")
        }
    }

    public func togglePlayPause() {
        if self.currentState == .Playing {
            self.pause()
        } else {
            self.play()
        }
    }

    public func play(index: Int = 0) {
        if !isPlayable() {
            debug("Player called but player not in playable state, doing nothing.")
            return
        }
        
        if !preConfigured { self.preAction() }
        
        if self.currentPlayerItem == nil {
            debug("Creating new AVPlayerItem")
            
            self.dataSource?.twistURLForItemAtIndex(index) { currentItemURL in
                self.mediaItem = MediaItem(
                    mediaURL:       currentItemURL,
                    cachePath:      self.dataSource?.twistCacheFilePathURLForItemAtIndex(index).path!,
                    cachingEnabled: self.dataSource?.twistShouldCacheItemAtIndex(index)
                )
                
                self.currentIndex = index
                self.currentPlayerItem = AVPlayerItem(asset: self.mediaItem!.asset)
                self.currentPlayerItem!.addObserver(
                    self,
                    forKeyPath: kStatusKey,
                    options: NSKeyValueObservingOptions.New.union(NSKeyValueObservingOptions.Initial),
                    context: &myContext
                )
                self.currentPlayerItem!.addObserver(
                    self,
                    forKeyPath: kLoadedTimeRangesKey,
                    options: NSKeyValueObservingOptions.New.union(NSKeyValueObservingOptions.Initial),
                    context: &myContext
                )
                self.player = AVPlayer(playerItem: self.currentPlayerItem!)
                self.periodicObserver = self.player?.addPeriodicTimeObserverForInterval(CMTimeMake(1, 1), queue: dispatch_get_main_queue(), usingBlock: { (_) in
                    self.updatedPlayerTiming()
                })
            }
        } else {
            debug("Playing current Item")
            self.player!.play()
            self.currentState = .Playing
            self.triggerPlaybackStateChanged()
        }
    }

    public func pause() {
        if !isPlayable() {
            return
        }

        if self.currentState == .Playing {
            debug("Pausing current item")
            self.player?.pause()
            self.currentState = .Paused
            self.triggerPlaybackStateChanged()
        }
    }

    public func stop() {
        if (self.player != nil) {
            self.cleanupCurrentItem()
            debug("Stopping current item")
            self.triggerPlaybackStateChanged()
        }
    }
    
    func cleanupCurrentItem() {
        self.currentState = .Waiting
        self.currentPlayerItem?.removeObserver(self, forKeyPath: kStatusKey)
        self.currentPlayerItem?.removeObserver(self, forKeyPath: kLoadedTimeRangesKey)
        self.currentPlayerItem = nil
        self.player?.removeTimeObserver(self.periodicObserver!)
        self.player = nil
    }
    
    func updateMediaInfo() {
        let defaultCenter = MPNowPlayingInfoCenter.defaultCenter()

        let totalDuration = NSNumber(double: CMTimeGetSeconds(self.currentPlayerItem!.duration))
        let currentTime   = NSNumber(double: CMTimeGetSeconds(self.player!.currentTime()))
        defaultCenter.nowPlayingInfo = [
            MPMediaItemPropertyAlbumTitle:               "Something",
            MPMediaItemPropertyArtist:                   "Jais Cheema",
            MPMediaItemPropertyTitle:                    "Some Title",
            MPMediaItemPropertyPlaybackDuration:         totalDuration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime
        ]
    }
    
    func updatedPlayerTiming() {
        self.updateMediaInfo()
    }

    public func next() {
        if !isPlayable() {
            return
        }
    
        if hasNextItem {
            self.cleanupCurrentItem()
            self.play(self.currentIndex + 1)
        }
    }
    
    // TODO:
    // Check the repeat
    // Check the shuffle settings
    var hasNextItem: Bool {
        return self.currentIndex < self.dataSource!.twistNumberOfItems() - 1
    }
    
    // Check the repeat
    // Check the shuffle settings
    var hasPreviousItem: Bool {
        return self.currentIndex != 0
    }

    public func previous() {
        if !isPlayable() {
            return
        }

        // TODO:
        // Seek to 0 if time is more than 5 seconds, else go to previous
        if hasPreviousItem {
            self.cleanupCurrentItem()
            self.play(self.currentIndex - 1)
        }
    }

    func isPlayable() -> Bool {
        guard let dataSource = self.dataSource else { return false }
        return dataSource.twistNumberOfItems() > 0
    }

    override public func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if context == &myContext {
            if let player = self.player where object is AVPlayer {
                debug("Received a message for player: \(player)")
            }
            
            if self.currentPlayerItem != nil && object is AVPlayerItem {
                guard let keyPath = keyPath else { return }
                switch keyPath {
                case kStatusKey:
                    if self.currentPlayerItem!.status == .ReadyToPlay {
                        self.player!.play()
                        self.currentState = .Playing
                        self.triggerPlaybackStateChanged()
                    } else {
                        debug("Status updated but not ready to play")
                    }
                case kLoadedTimeRangesKey:
                    if let availableDuration = self.availableDurationForCurrentItem() {
                        let duration = self.currentPlayerItem!.duration
                        let totalDuration = CMTimeGetSeconds(duration)
                        self.delegate?.twist(self, loaded: availableDuration, outOf: totalDuration)
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
        guard let currentItem = self.currentPlayerItem else { return nil }
        let loadedTimeRanges = currentItem.loadedTimeRanges
        if let timeRange = loadedTimeRanges.first?.CMTimeRangeValue {
            let startSeconds = CMTimeGetSeconds(timeRange.start)
            let durationSeconds = CMTimeGetSeconds(timeRange.duration)
            return startSeconds + durationSeconds
        }
        return nil
    }
    
    func triggerPlaybackStateChanged() {
        self.delegate?.twistStatusChanged()
        self.updateMPRemoteCommandButtons()
    }
    
    func updateMPRemoteCommandButtons() {
        let commandCenter = MPRemoteCommandCenter.sharedCommandCenter()
        commandCenter.nextTrackCommand.enabled = self.hasNextItem
        commandCenter.previousTrackCommand.enabled = self.hasPreviousItem
        commandCenter.playCommand.enabled = self.currentState == .Paused
        commandCenter.pauseCommand.enabled = self.currentState == .Playing
        commandCenter.togglePlayPauseCommand.enabled = self.isPlayable()
    }
}