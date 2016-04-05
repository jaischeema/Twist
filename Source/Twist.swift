//
//  Twist.swift
//  Twist
//
//  Created by Jais Cheema on 8/01/2016.
//  Copyright © 2016 Needle Apps. All rights reserved.
//

import Foundation
import AVFoundation

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
    
    func preAction() {
        self.preConfigured = true
        self.player = AVPlayer()
        self.registerAudioSession()
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
                    forKeyPath: "status",
                    options: NSKeyValueObservingOptions.New,
                    context: &myContext
                )
                self.player = AVPlayer(playerItem: self.currentPlayerItem!)
            }
        } else {
            debug("Playing current Item")
            self.player!.play()
            self.currentState = .Playing
            self.delegate?.twistStatusChanged()
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
            self.delegate?.twistStatusChanged()
        }
    }

    public func stop() {
        if (self.player != nil) {
            self.currentState = .Waiting
            self.currentPlayerItem?.removeObserver(self, forKeyPath: "status")
            self.currentPlayerItem = nil
            self.player = nil
            debug("Stopping current item")
            self.delegate?.twistStatusChanged()
        }
    }

    public func next() {
        if !isPlayable() {
            return
        }
        
        // TODO:
        // Check the repeat
        // Check the shuffle settings
        if self.currentIndex < self.dataSource!.twistNumberOfItems() {
            self.stop()
            self.play(self.currentIndex + 1)
        }
    }

    public func previous() {
        if !isPlayable() {
            return
        }

        // TODO:
        // Seek to 0 if time is more than 5 seconds, else go to previous
        // Check the repeat
        // Check the shuffle settings
        if self.currentIndex != 0 {
            self.stop()
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
            
            if keyPath == kStatusKey && self.currentPlayerItem != nil && object is AVPlayerItem {
                if self.currentPlayerItem!.status == .ReadyToPlay {
                    self.player!.play()
                    self.currentState = .Playing
                    self.delegate?.twistStatusChanged()
                } else {
                    debug(self.currentPlayerItem?.error)
                    debug("Status updated but not ready to play")
                }
            }
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
}