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
func debug(message: Any) {
    if debugging {
        print("Twist: \(message)")
    }
}

public enum TwistRepeatMode: Int {
    case All = 0
    case Single
    case None
    
    public var nextMode: TwistRepeatMode {
        switch self {
        case .All: return .Single
        case .Single: return .None
        case .None: return .All
        }
    }
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
    public var dataSource: TwistDataSource?
    public var delegate: TwistDelegate?
    
    private(set) public var currentState = TwistState.Waiting

    public var repeatMode: TwistRepeatMode {
        get { return self.playerIndex.repeatMode }
        set { self.playerIndex.repeatMode = newValue }
    }
    
    public var shuffle: Bool {
        get { return self.playerIndex.shuffle }
        set { self.playerIndex.shuffle = newValue }
    }
    
    public var currentIndex: Int {
        get { return self.playerIndex.currentIndex }
        set {
            self.playerIndex.currentIndex = newValue
            fetchCurrentItemInfo()
        }
    }

    public var currentPlayerItem: AVPlayerItem? {
        return currentMediaItem?.avPlayerItem
    }
    
    public var isPlayable: Bool { return self.playerIndex.totalItems > 0 }
    public var hasNextItem: Bool { return self.nextIndex != nil }
    public var hasPreviousItem: Bool { return self.previousIndex != nil }
    
    // MARK: Private variables
    
    var playerIndex: PlayerIndex!
    var player: AVPlayer?
    var preConfigured: Bool = false
    var interruptedWhilePlaying: Bool = false
    var periodicObserver: AnyObject?
    var currentItemInfo: [String: AnyObject]?
    var currentMediaItem: MediaItem?

    var nextIndex: Int?     { return self.playerIndex.nextIndex() }
    var previousIndex: Int? { return self.playerIndex.previousIndex() }

    override init() {
        super.init()
        self.playerIndex = PlayerIndex(player: self)
    }

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
    
    public func play(itemIndex: Int? = nil) {
        let index = itemIndex ?? self.currentIndex
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
            self.currentIndex = index
            
            self.dataSource?.twist(self, urlForItemAtIndex: index) { (currentItemURL, error) in
                guard error == nil else {
                    self.next()
                    return
                }
                self.currentMediaItem = MediaItem(player: self, itemURL: currentItemURL!, itemIndex: index)
                self.player = AVPlayer(playerItem: self.currentPlayerItem!)
                self.periodicObserver = self.player?.addPeriodicTimeObserverForInterval(CMTimeMake(1, 10),
                                                                                        queue: dispatch_get_main_queue(),
                                                                                        usingBlock: { (_) in
                    self.updatedPlayerTiming()
                })

                self.delegate?.twist(self, startedPlayingItemAtIndex: self.currentIndex)
            }
        } else {
            debug("Playing current Item")
            self.player!.play()
            self.changeState(.Playing)
        }
    }
    
    public func pause() {
        if !isPlayable { return }
        
        if self.currentState == .Playing {
            debug("Pausing current item")
            self.player?.pause()
            self.changeState(.Paused)
        }
    }

    public func togglePlayPause() {
        if self.currentState == .Playing {
            self.pause()
        } else {
            self.play()
        }
    }

    public func stop() {
        if (self.player != nil) {
            debug("Stopping current item")
            self.cleanupCurrentItem()
            self.changeState(.Waiting)
        }
    }

    public func next(ignoreRepeat: Bool = true) {
        guard isPlayable else { return }
        guard let nextIndex = self.playerIndex.nextIndex(ignoreRepeat) else { return }
        
        self.cleanupCurrentItem()
        self.play(nextIndex)
    }

    public func previous(ignoreRepeat: Bool = true) {
        guard isPlayable else { return }
        
        if self.player != nil && CMTimeGetSeconds(self.player!.currentTime()) > 4.0 {
            self.seekCurrentItemTo(0.0)
        } else if let previousIndex = self.playerIndex.previousIndex(ignoreRepeat) {
            self.cleanupCurrentItem()
            self.play(previousIndex)
        } else {
            self.seekCurrentItemTo(0.0)
        }
    }

    public func seekCurrentItemTo(position: Double) {
        let time = CMTimeMakeWithSeconds(position, Int32(NSEC_PER_SEC))
        self.player?.seekToTime(time, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
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

    func playCurrentSong() {
        self.play(self.currentIndex)
    }
    
    func setupRemoteCommandTargets() {
        let commandCenter = MPRemoteCommandCenter.sharedCommandCenter()
        commandCenter.nextTrackCommand.addTarget(self, action: #selector(Twist.next))
        commandCenter.previousTrackCommand.addTarget(self, action: #selector(Twist.previous))
        commandCenter.playCommand.addTarget(self, action: #selector(Twist.playCurrentSong))
        commandCenter.pauseCommand.addTarget(self, action: #selector(Twist.pause))
        commandCenter.togglePlayPauseCommand.addTarget(self, action: #selector(Twist.togglePlayPause))
    }
    
    func playerItemDidReachEnd(notification: NSNotification) {
        self.next(false)
    }
    
    func playerItemFailedToPlayEndTime(notification: NSNotification) {
        self.next()
    }
    
    func playerItemPlaybackStall(notification: NSNotification) {
        debug("playback stalled")
        play()
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
        self.currentMediaItem?.cleanup()
        self.currentMediaItem = nil
        if self.player != nil && self.periodicObserver != nil {
            self.player!.removeTimeObserver(self.periodicObserver!)
        }
        self.player = nil
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

    func changeState(newState: TwistState) {
        self.delegate?.twist(self, willChangeStateFrom: currentState, to: newState)
        self.currentState = newState
        self.delegate?.twist(self, didChangeStateFrom: currentState, to: newState)
    }
}