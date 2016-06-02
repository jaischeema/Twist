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
    
    // MARK: Public Variables
    public var repeatMode: TwistRepeatMode = .None
    public var shuffle: Bool = false
    public var dataSource: TwistDataSource?
    public var delegate: TwistDelegate?
    
    // MARK: Public getters, Private setters
    private(set) public var currentState = TwistState.Waiting
    private(set) public var currentPlayerItem: AVPlayerItem?
    private(set) public var currentIndex: Int = 0 {
        didSet { fetchCurrentItemInfo() }
    }

    // MARK: Private variables
    var player: AVPlayer?
    var preConfigured: Bool = false
    var interruptedWhilePlaying: Bool = false
    var mediaItem: MediaItem?
    var periodicObserver: AnyObject?
    var currentItemInfo: [String: AnyObject]?
    
    func fetchCurrentItemInfo() {
        let mediaInfo = self.dataSource!.twist(self, mediaInfoForItemAtIndex: self.currentIndex)
        self.currentItemInfo = [
            MPMediaItemPropertyAlbumTitle:  mediaInfo.album,
            MPMediaItemPropertyArtist:      mediaInfo.artist,
            MPMediaItemPropertyTitle:       mediaInfo.title,
        ]
        if let albumArt = mediaInfo.albumArt {
            self.currentItemInfo![MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: albumArt)
        }
    }
    
    // MARK: Public API

    public var hasNextItem: Bool {
        return self.currentIndex < self.dataSource!.twistTotalItemsInQueue(self) - 1
    }

    public var hasPreviousItem: Bool {
        return self.currentIndex != 0
    }
    
    public var isPlayable: Bool {
        guard let dataSource = self.dataSource else { return false }
        return dataSource.twistTotalItemsInQueue(self) > 0
    }
    
    public func play() {
        self.play(self.currentIndex)
    }
    
    public func play(index: Int) {
        if !isPlayable {
            debug("Player called but player not in playable state, doing nothing.")
            return
        }
        
        if !preConfigured { self.configurePlayer() }
        
        if currentIndex != index {
            self.cleanupCurrentItem()
        }
        
        if self.currentPlayerItem == nil {
            debug("Creating new AVPlayerItem")
            
            self.dataSource?.twist(self, urlForItemAtIndex: index) { (currentItemURL, error) in
                if error != nil {
                    self.next()
                    return
                }

                self.mediaItem = MediaItem(
                    mediaURL:       currentItemURL!,
                    cachePath:      self.dataSource?.twist(self, cacheFilePathForItemAtIndex: index),
                    cachingEnabled: self.dataSource?.twist(self, shouldCacheItemAtIndex: index)
                )

                self.mediaItem?.successfulDownloadCallback = { mediaItemURL in
                    self.delegate?.twist(self, downloadedMedia: mediaItemURL, forItemAtIndex: index)
                }

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
                self.periodicObserver = self.player?.addPeriodicTimeObserverForInterval(CMTimeMake(1, 10), queue: dispatch_get_main_queue(), usingBlock: { (_) in
                    self.updatedPlayerTiming()
                })
                self.delegate?.twist(self, startedPlayingItemAtIndex: self.currentIndex)
            }
        } else {
            debug("Playing current Item")
            self.player!.play()
            self.currentState = .Playing
            self.triggerPlaybackStateChanged()
        }
    }
    
    public func pause() {
        if !isPlayable { return }
        
        if self.currentState == .Playing {
            debug("Pausing current item")
            self.player?.pause()
            self.currentState = .Paused
            self.triggerPlaybackStateChanged()
        }
    }
    
    public func next() {
        if !isPlayable { return }
        
        if hasNextItem {
            self.cleanupCurrentItem()
            self.play(self.currentIndex + 1)
        }
    }
    
    public func stop() {
        if (self.player != nil) {
            self.currentState = .Waiting
            self.cleanupCurrentItem()
            debug("Stopping current item")
            self.triggerPlaybackStateChanged()
        }
    }
    
    public func togglePlayPause() {
        if self.currentState == .Playing {
            self.pause()
        } else {
            self.play()
        }
    }

    func seekCurrentItemTo(position: Double) {
        let time = CMTimeMakeWithSeconds(position, Int32(NSEC_PER_SEC))
        self.player?.seekToTime(time, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
    }
    
    public func previous() {
        if !isPlayable { return }
        
        if self.player != nil && CMTimeGetSeconds(self.player!.currentTime()) > 4.0 {
            self.seekCurrentItemTo(0.0)
        } else if hasPreviousItem {
            self.cleanupCurrentItem()
            self.play(self.currentIndex - 1)
        } else {
            self.seekCurrentItemTo(0.0)
        }
    }
    
    // MARK: Listeners and events setup
    func configurePlayer() {
        self.preConfigured = true
        self.player = AVPlayer()
        self.registerAudioSession()
        self.registerListeners()
        self.setupRemoteCommandTargets()
    }
    
    func registerListener(selector: Selector, notification: String) {
        NSNotificationCenter.defaultCenter().addObserver(
            self, selector: selector, name: notification, object: nil
        )
    }
    
    func registerListeners() {
        registerListener(#selector(Twist.playerItemDidReachEnd(_:)), notification: AVPlayerItemDidPlayToEndTimeNotification)
        registerListener(#selector(Twist.playerItemFailedToPlayEndTime(_:)), notification: AVPlayerItemFailedToPlayToEndTimeNotification)
        registerListener(#selector(Twist.playerItemPlaybackStall(_:)), notification: AVPlayerItemPlaybackStalledNotification)
        registerListener(#selector(Twist.interruption(_:)), notification: AVAudioSessionInterruptionNotification)
        registerListener(#selector(Twist.routeChange(_:)), notification: AVAudioSessionRouteChangeNotification)
    }
    
    func setupRemoteCommandTargets() {
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
        if  let notificationType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let interruptionType = AVAudioSessionInterruptionType(rawValue: notificationType) {
            switch interruptionType {
            case .Began:
                self.interruptedWhilePlaying = (self.currentState == .Playing)
                self.pause()
            case .Ended:
                if self.interruptedWhilePlaying {
                    self.interruptedWhilePlaying = false
                    self.play()
                }
            }
        }
    }
    
    func routeChange(notification: NSNotification) {
        if  let notificationType = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSessionRouteChangeReason(rawValue: notificationType) {
            switch reason {
            case .OldDeviceUnavailable:
                self.pause()
                debug("Route changed and paused")
            default:
                debug("Route changed but no need to pause: \(notificationType.description)")
            }
        }
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

    // MARK: Helper methods
    func cleanupCurrentItem() {
        self.currentPlayerItem?.removeObserver(self, forKeyPath: kStatusKey)
        self.currentPlayerItem?.removeObserver(self, forKeyPath: kLoadedTimeRangesKey)
        self.currentPlayerItem = nil
        self.player?.removeTimeObserver(self.periodicObserver!)
        self.player = nil
        self.mediaItem?.session.invalidateAndCancel()
    }
    
    func updateNowPlayingInfo(currentTime: Double, totalDuration: Double) {
        if var currentItemInfo = self.currentItemInfo {
            let defaultCenter = MPNowPlayingInfoCenter.defaultCenter()
            currentItemInfo[MPMediaItemPropertyPlaybackDuration] = NSNumber(double: totalDuration)
            currentItemInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(double: currentTime)
            defaultCenter.nowPlayingInfo = currentItemInfo
        }
    }
    
    func updatedPlayerTiming() {
        let totalDuration = CMTimeGetSeconds(self.currentPlayerItem!.duration)
        let currentTime   = CMTimeGetSeconds(self.player!.currentTime())
        self.updateNowPlayingInfo(currentTime, totalDuration: totalDuration)
        self.delegate?.twist(self, playedTo: currentTime, outOf: totalDuration)
    }

    // MARK: Observer methods
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
        self.delegate?.twistStateChanged(self)
    }
}