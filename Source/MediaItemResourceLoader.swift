//
//  AVPlayerCaching.swift
//  Twist
//
//  Created by Jais Cheema on 4/04/2016.
//  Copyright © 2016 Needle Apps. All rights reserved.
//

import Foundation
import AVFoundation
import MobileCoreServices

func replaceUrlScheme(url: NSURL, scheme: String) -> NSURL? {
    let urlComponents = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)
    urlComponents?.scheme = scheme
    return urlComponents?.URL
}

class MediaItemResourceLoader: NSObject, NSURLSessionDataDelegate, AVAssetResourceLoaderDelegate {
    var pendingRequests = [AVAssetResourceLoadingRequest]()
    var data: NSMutableData?
    var response: NSURLResponse?
    var session: NSURLSession!
    var connection: NSURLSessionDataTask?
    var successfulDownloadCallback: ((NSURL) -> Void)?
    
    let mediaURL:  NSURL
    let cachePath: String?
    let cachingEnabled: Bool
    var _asset: AVURLAsset?
    
    init(mediaURL: NSURL, cachePath: String?, cachingEnabled: Bool?) {
        self.mediaURL = mediaURL
        self.cachePath = cachePath
        self.cachingEnabled = cachingEnabled == nil ? false : cachingEnabled!
        super.init()

        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.allowsCellularAccess = true
        configuration.timeoutIntervalForRequest = 30
        self.session = NSURLSession(configuration: configuration, delegate: self, delegateQueue: NSOperationQueue.mainQueue())
    }
    
    var asset: AVURLAsset {
        if self._asset == nil {
            self.configureAsset()
        }
        return self._asset!
    }
    
    var isCachingEnabled: Bool {
        return self.cachingEnabled && self.cachePath != nil
    }
    
    var hasCachedFile: Bool {
        guard let cachePath = self.cachePath else { return false }
        let fileManager = NSFileManager.defaultManager()
        return fileManager.fileExistsAtPath(cachePath)
    }
    
    func configureAsset() {
        if isCachingEnabled {
            debug("Caching is enabled")
            if hasCachedFile {
                debug("Local cached file is available")
                self._asset = AVURLAsset(URL: NSURL(fileURLWithPath: self.cachePath!), options: [:])
            } else {
                debug("Local cache file is not available")
                let streamingURL = replaceUrlScheme(self.mediaURL, scheme: "streaming")!
                self._asset = AVURLAsset(URL: streamingURL, options: [:])
                self._asset!.resourceLoader.setDelegate(self, queue: dispatch_get_main_queue())
            }
        } else {
            debug("Caching is not enabled")
            self._asset = AVURLAsset(URL: self.mediaURL, options: [:])
        }
        assert(self._asset != nil, "Asset should not be nil")
    }

    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: (NSURLSessionResponseDisposition) -> Void) {
        debug("Received response")
        self.data = NSMutableData()
        self.response = response
        self.processPendingRequests()
        completionHandler(.Allow)
    }

    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
        print(".", terminator:"")
        self.data?.appendData(data)
        self.processPendingRequests()
    }

    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        if error != nil {
            debug(error)
        } else {
            self.processPendingRequests()
            debug("Writing data to local cached file: \(self.cachePath!)")
            do {
                try self.data?.writeToFile(self.cachePath!, options: NSDataWritingOptions.AtomicWrite)
                self.successfulDownloadCallback?(mediaURL)
            } catch {
                debug("Unable to write to original file")
            }
        }
    }

    func processPendingRequests() {
        self.pendingRequests = self.pendingRequests.filter { loadingRequest in
            self.fillInContentInformation(loadingRequest.contentInformationRequest)
            if self.respondWithDataForRequest(loadingRequest.dataRequest) {
                loadingRequest.finishLoading()
                return false
            }
            return true
        }
    }
    
    func fillInContentInformation(contentInformationRequest: AVAssetResourceLoadingContentInformationRequest?) {
        if(contentInformationRequest == nil || self.response == nil) {
            return
        }
        let mimeType = self.response!.MIMEType!
        guard let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType, nil)?.takeRetainedValue() else {
            return
        }
        contentInformationRequest?.byteRangeAccessSupported = true
        contentInformationRequest?.contentType   = contentType as String
        contentInformationRequest?.contentLength = self.response!.expectedContentLength
    }
    
    func respondWithDataForRequest(dataRequest: AVAssetResourceLoadingDataRequest?) -> Bool {
        guard let dataRequest = dataRequest else { return false }
        let startOffset = Int(dataRequest.currentOffset == 0 ? dataRequest.requestedOffset : dataRequest.currentOffset)

        if self.data!.length < startOffset {
            return false
        }
        
        let unreadBytes = self.data!.length - startOffset
        let numberOfBytesToRespondWith  = min(Int(dataRequest.requestedLength), unreadBytes)
        dataRequest.respondWithData(self.data!.subdataWithRange(NSMakeRange(startOffset, numberOfBytesToRespondWith)))
        
        return self.data!.length >= startOffset + dataRequest.requestedLength
    }
    
    func resourceLoader(resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        if self.connection == nil {
            debug("Starting request to get media URL: \(self.mediaURL)")
            let request = NSURLRequest(URL: replaceUrlScheme(loadingRequest.request.URL!, scheme: "http")!)
            self.connection = session.dataTaskWithRequest(request)
            self.connection?.resume()
        }
        
        self.pendingRequests.append(loadingRequest)
        
        return true
    }
    
    func resourceLoader(resourceLoader: AVAssetResourceLoader, didCancelLoadingRequest loadingRequest: AVAssetResourceLoadingRequest) {
        self.pendingRequests = self.pendingRequests.filter { $0 != loadingRequest }
    }
}