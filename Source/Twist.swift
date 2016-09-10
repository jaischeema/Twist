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
func debug(_ message: Any) {
    if debugging {
        print("Twist: \(message)")
    }
}

public enum TwistRepeatMode: Int {
    case all = 0
    case single
    case none
    
    public var nextMode: TwistRepeatMode {
        switch self {
        case .all: return .single
        case .single: return .none
        case .none: return .all
        }
    }
}

public enum TwistState: Int {
    case waiting = 0
    case buffering
    case ready
    case playing
    case paused
    case failed
}

open class Twist: NSObject, AVAudioPlayerDelegate {
    open static let defaultPlayer = Twist()
    open var dataSource: TwistDataSource?
    open var delegate: TwistDelegate?
    
    fileprivate(set) open var currentState = TwistState.waiting

    open var repeatMode: TwistRepeatMode {
        get { return self.playerIndex.repeatMode }
        set { self.playerIndex.repeatMode = newValue }
    }
    
    open var shuffle: Bool {
        get { return self.playerIndex.shuffle }
        set { self.playerIndex.shuffle = newValue }
    }
    
    open var currentIndex: Int {
        get { return self.playerIndex.currentIndex }
        set {
            self.playerIndex.currentIndex = newValue
            fetchCurrentItemInfo()
        }
    }

    open var currentPlayerItem: AVPlayerItem? {
        return currentMediaItem?.avPlayerItem
    }
    
    open var isPlayable: Bool { return self.playerIndex.totalItems > 0 }
    open var hasNextItem: Bool { return self.nextIndex != nil }
    open var hasPreviousItem: Bool { return self.previousIndex != nil }
    
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
            MPMediaItemPropertyAlbumTitle:  mediaInfo.album as AnyObject,
            MPMediaItemPropertyArtist:      mediaInfo.artist as AnyObject,
            MPMediaItemPropertyTitle:       mediaInfo.title as AnyObject,
        ]
        if let albumArt = mediaInfo.albumArt {
            self.currentItemInfo![MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: albumArt)
        }
    }
    
    // MARK: Public API
    open func removedItem(_ index: Int) {
        self.playerIndex.removedItem(index)
    }

    open func addedItem(_ index: Int) {
        self.playerIndex.addedItem(index)
    }
    
    open func movedItem(_ previousIndex: Int, to newIndex: Int) {
        self.playerIndex.movedItem(previousIndex, to: newIndex)
    }
    
    open func play(_ itemIndex: Int? = nil) {
        let index = itemIndex ?? self.currentIndex
        if !isPlayable {
            debug("Player called but player not in playable state, doing nothing.")
            return
        }

        if !preConfigured { self.configurePlayer() }
        
        if currentIndex != index {
            self.cleanupCurrentItem()
        }
        
        if self.currentMediaItem == nil {
            debug("Creating new AVPlayerItem")
            self.currentIndex = index
            
            self.dataSource?.twist(self, urlForItemAtIndex: index) { (currentItemURL, error) in
                guard error == nil else {
                    self.next()
                    return
                }
                self.currentMediaItem = MediaItem(player: self, itemURL: currentItemURL!, itemIndex: index)
                self.player = AVPlayer(playerItem: self.currentPlayerItem!)
                self.periodicObserver = self.player?.addPeriodicTimeObserver(forInterval: CMTimeMake(1, 10),
                                                                                        queue: DispatchQueue.main,
                                                                                        using: { (_) in
                    self.updatedPlayerTiming()
                }) as AnyObject?
                self.delegate?.twist(self, startedPlayingItemAtIndex: self.currentIndex)
                self.changeState(.buffering)
            }
        } else {
            debug("Playing current Item")
            self.player!.play()
            self.changeState(.playing)
        }
    }
    
    open func pause() {
        if !isPlayable { return }
        
        if self.currentState == .playing {
            debug("Pausing current item")
            self.player?.pause()
            self.changeState(.paused)
        }
    }

    open func togglePlayPause() {
        if self.currentState == .playing {
            self.pause()
        } else {
            self.play()
        }
    }

    open func stop() {
        if (self.player != nil) {
            debug("Stopping current item")
            self.cleanupCurrentItem()
            self.changeState(.waiting)
        }
    }

    open func next(_ ignoreRepeat: Bool = true) {
        guard isPlayable else { return }
        guard let nextIndex = self.playerIndex.nextIndex(ignoreRepeat) else { return }
        
        self.cleanupCurrentItem()
        self.play(nextIndex)
    }

    open func previous(_ ignoreRepeat: Bool = true) {
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

    open func seekCurrentItemTo(_ position: Double) {
        let time = CMTimeMakeWithSeconds(position, Int32(NSEC_PER_SEC))
        self.player?.seek(to: time, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
    }
    
    // MARK: Listeners and events setup
    func configurePlayer() {
        self.preConfigured = true
        self.player = AVPlayer()
        self.registerAudioSession()
        self.registerListeners()
        self.setupRemoteCommandTargets()
    }
    
    func registerListener(_ selector: Selector, notification: String) {
        NotificationCenter.default.addObserver(
            self, selector: selector, name: NSNotification.Name(rawValue: notification), object: nil
        )
    }
    
    func registerListeners() {
        registerListener(#selector(Twist.playerItemDidReachEnd(_:)), notification: NSNotification.Name.AVPlayerItemDidPlayToEndTime.rawValue)
        registerListener(#selector(Twist.playerItemFailedToPlayEndTime(_:)), notification: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime.rawValue)
        registerListener(#selector(Twist.playerItemPlaybackStall(_:)), notification: NSNotification.Name.AVPlayerItemPlaybackStalled.rawValue)
        registerListener(#selector(Twist.interruption(_:)), notification: NSNotification.Name.AVAudioSessionInterruption.rawValue)
        registerListener(#selector(Twist.routeChange(_:)), notification: NSNotification.Name.AVAudioSessionRouteChange.rawValue)
    }

    func playCurrentSong() {
        self.play(self.currentIndex)
    }
    
    func setupRemoteCommandTargets() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.nextTrackCommand.addTarget(self, action: #selector(Twist.next))
        commandCenter.previousTrackCommand.addTarget(self, action: #selector(Twist.previous))
        commandCenter.playCommand.addTarget(self, action: #selector(Twist.playCurrentSong))
        commandCenter.pauseCommand.addTarget(self, action: #selector(Twist.pause))
        commandCenter.togglePlayPauseCommand.addTarget(self, action: #selector(Twist.togglePlayPause))
    }

    func playerItemDidReachEnd(_ notification: Notification) {
        self.next(false)
    }
    
    func playerItemFailedToPlayEndTime(_ notification: Notification) {
        self.next()
    }
    
    func playerItemPlaybackStall(_ notification: Notification) {
        self.changeState(.buffering)
    }
    
    func interruption(_ notification: Notification) {
        if  let notificationType = (notification as NSNotification).userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let interruptionType = AVAudioSessionInterruptionType(rawValue: notificationType) {
            switch interruptionType {
            case .began:
                self.interruptedWhilePlaying = (self.currentState == .playing)
                self.pause()
            case .ended:
                if self.interruptedWhilePlaying {
                    self.interruptedWhilePlaying = false
                    self.play()
                }
            }
        }
    }
    
    func routeChange(_ notification: Notification) {
        if  let notificationType = (notification as NSNotification).userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSessionRouteChangeReason(rawValue: notificationType) {
            switch reason {
            case .oldDeviceUnavailable:
                self.pause()
                debug("Route changed and paused")
            default:
                debug("Route changed but no need to pause: \(notificationType.description)")
            }
        }
    }
    
    func registerAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        if audioSession.category != AVAudioSessionCategoryPlayback {
            let device = UIDevice.current
            if device.isMultitaskingSupported {
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
    
    func updateNowPlayingInfo(_ currentTime: Double, totalDuration: Double) {
        if var currentItemInfo = self.currentItemInfo {
            let defaultCenter = MPNowPlayingInfoCenter.default()
            currentItemInfo[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: totalDuration as Double)
            currentItemInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: currentTime as Double)
            defaultCenter.nowPlayingInfo = currentItemInfo
        }
    }
    
    func updatedPlayerTiming() {
        let totalDuration = CMTimeGetSeconds(self.currentPlayerItem!.duration)
        let currentTime   = CMTimeGetSeconds(self.player!.currentTime())
        self.updateNowPlayingInfo(currentTime, totalDuration: totalDuration)
        self.delegate?.twist(self, playedTo: currentTime, outOf: totalDuration)
    }

    func changeState(_ newState: TwistState) {
        self.delegate?.twist(self, willChangeStateFrom: currentState, to: newState)
        debug("Changing from \(currentState) => \(newState)")
        self.currentState = newState
        self.delegate?.twist(self, didChangeStateFrom: currentState, to: newState)
    }
}
