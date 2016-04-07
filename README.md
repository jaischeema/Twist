# Twist Player

Twist provides a full fledged music player functionality. **This is still in alpha stage and is being actively developed.**

## Features

- Play local and remote media
- Update media information on lockscreen using MPNowPlayingInfoCenter
- Handle the remote events
- 3 Repeat modes: RepeatAll, RepeatOne, RepeatOff
- Shuffling
- Cache remote files to local filesystem

## Installation

There will be support for Carthage and Cocoapods but this has not been done right now.

## Usage

The music player is controlled via `TwistDelegate` and `TwistDataSource` protocol implementations

### TwistDelegate

```swift
public protocol TwistDelegate {
    func twist(twist: Twist, loaded: NSTimeInterval, outOf totalDuration: NSTimeInterval)
    func twist(twist: Twist, progressed: NSTimeInterval)
    func twistCurrentItemChanged(item: AVPlayerItem)
    func twistStatusChanged()
}
```

All methods are optional and have been provided with default implementation.

### TwistDataSource

```swift
public protocol TwistDataSource {
    func twistURLForItemAtIndex(index: Int, completion: (NSURL) -> Void)
    func twistNumberOfItems() -> Int
    // optional
    func twistShouldCacheItemAtIndex(index: Int) -> Bool
    func twistCacheFilePathURLForItemAtIndex(index: Int) -> NSURL
    func twistMediaInfoForItemAtIndex(index: Int) -> TwistMediaInfo
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
       ....
    }
}
```

## TODO

- Implement Repeat modes
- Implement Shuffling
- Implment seeking
- Add tests
- Add installation instructions for Carthage and Cocoapods

## Author

Created by Jais Cheema

* [GitHub](https://github.com/jaischeema/)
* [Twitter](https://twitter.com/jaischeema)

## Contributions

Fork the repository and make a pull request and I will review and merge it. Try to

- Pick a thing out of the TODO list
- Keep the changes simple
- Add comments for the hairy bits
- Add tests

## License

Twist is released under the MIT license. See LICENSE for details.

