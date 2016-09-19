# Twist Player

Twist provides a full fledged music player functionality. **This is still in alpha stage and is being actively developed.**

## Requirements

- iOS 9.0+
- Xcode 8.0+
- Swift 3.0+

## Features

- Play local and remote media
- Update media information on lockscreen using MPNowPlayingInfoCenter
- Handle the remote events
- 3 Repeat modes: RepeatAll, RepeatOne, RepeatOff
- Shuffling
- Cache remote files to local filesystem
- Configurable logging

## Installation

There will be support for Carthage and Cocoapods but this has not been done right now.

## Usage

The music player is controlled via `TwistDelegate` and `TwistDataSource` protocol implementations

### TwistDelegate

```swift
public protocol TwistDelegate {
    func twist(_ twist: Twist, loaded: TimeInterval, outOf totalDuration: TimeInterval)
    func twist(_ twist: Twist, playedTo currentTime: Double, outOf totalDuration: Double)
    func twist(_ twist: Twist, startedPlayingItemAtIndex itemIndex: Int)
    func twist(_ twist: Twist, failedToPlayURL itemURL: URL, forItemAtIndex itemIndex: Int)
    func twist(_ twist: Twist, downloadedMedia fileItemURL: URL, forItemAtIndex itemIndex: Int)
    func twist(_ twist: Twist, willChangeStateFrom fromState: TwistState, to newState: TwistState)
    func twist(_ twist: Twist, didChangeStateFrom fromState: TwistState, to newState: TwistState)
}
```

All methods are optional and have been provided with default implementation.

### TwistDataSource

```swift
public protocol TwistDataSource {
    func twistTotalItemsInQueue(_ twist: Twist) -> Int
    func twist(_ twist: Twist, urlForItemAtIndex itemIndex: Int, completionHandler completion: @escaping (URL?, NSError?) -> Void)

    // Optional
    func twist(_ twist: Twist, shouldCacheItemAtIndex itemIndex: Int) -> Bool
    func twist(_ twist: Twist, cacheFilePathForItemAtIndex itemIndex: Int) -> String
    func twist(_ twist: Twist, mediaInfoForItemAtIndex itemIndex: Int) -> TwistMediaInfo
    func twistPreferredNextItemIndex(_ twist: Twist) -> Int?
}
```

Data source only has two required methods and everything else is optional

### TwistMediaInfo

This struct is used to provide the media information to be displayed on the lockscreen

```swift
public struct TwistMediaInfo {
    let title: String
    let artist: String
    let album: String
    var albumArt: UIImage?

    public init(title: String, artist: String, album: String, albumArt: UIImage? = nil) {
        ...
    }
}
```

## TODO

- Add tests
- Add installation instructions for Carthage and Cocoapods

## Author

Created by Jais Cheema

* [GitHub](https://github.com/jaischeema/)
* [Twitter](https://twitter.com/jaischeema)

## Contributions

Fork the repository and make a pull request and I will review and merge it. Try to

- Pick a thing out of the TODO list (or something that is an obvious improvement)
- Keep the changes simple
- Add comments for the hairy bits
- Add tests

## License

Twist is released under the MIT license. See LICENSE for details.

