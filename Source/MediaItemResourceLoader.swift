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

func replaceUrlScheme(_ url: URL, scheme: String) -> URL? {
    var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
    urlComponents?.scheme = scheme
    return urlComponents?.url
}

class MediaItemResourceLoader: NSObject, URLSessionDataDelegate, AVAssetResourceLoaderDelegate {
    var pendingRequests = [AVAssetResourceLoadingRequest]()
    var data: NSMutableData?
    var response: URLResponse?
    var session: URLSession!
    var connection: URLSessionDataTask?
    var successfulDownloadCallback: ((URL) -> Void)?
    
    let mediaURL:  URL
    let cachePath: String?
    let cachingEnabled: Bool
    var _asset: AVURLAsset?
    
    init(mediaURL: URL, cachePath: String?, cachingEnabled: Bool?) {
        self.mediaURL = mediaURL
        self.cachePath = cachePath
        self.cachingEnabled = cachingEnabled == nil ? false : cachingEnabled!
        super.init()

        let configuration = URLSessionConfiguration.default
        configuration.allowsCellularAccess = true
        configuration.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
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
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: cachePath)
    }
    
    func configureAsset() {
        if isCachingEnabled {
            debug("Caching is enabled")
            if hasCachedFile {
                debug("Local cached file is available")
                self._asset = AVURLAsset(url: URL(fileURLWithPath: self.cachePath!), options: [:])
            } else {
                debug("Local cache file is not available")
                let streamingURL = replaceUrlScheme(self.mediaURL, scheme: "streaming")!
                self._asset = AVURLAsset(url: streamingURL, options: [:])
                self._asset!.resourceLoader.setDelegate(self, queue: DispatchQueue.main)
            }
        } else {
            debug("Caching is not enabled")
            self._asset = AVURLAsset(url: self.mediaURL, options: [:])
        }
        assert(self._asset != nil, "Asset should not be nil")
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        debug("Received response")
        self.data = NSMutableData()
        self.response = response
        self.processPendingRequests()
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print(".", terminator:"")
        self.data?.append(data)
        self.processPendingRequests()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            debug(error)
        } else {
            self.processPendingRequests()
            debug("Writing data to local cached file: \(self.cachePath!)")
            do {
                try self.data?.write(toFile: self.cachePath!, options: NSData.WritingOptions.atomicWrite)
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
    
    func fillInContentInformation(_ contentInformationRequest: AVAssetResourceLoadingContentInformationRequest?) {
        if(contentInformationRequest == nil || self.response == nil) {
            return
        }
        let mimeType = self.response!.mimeType!
        guard let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)?.takeRetainedValue() else {
            return
        }
        contentInformationRequest?.isByteRangeAccessSupported = true
        contentInformationRequest?.contentType   = contentType as String
        contentInformationRequest?.contentLength = self.response!.expectedContentLength
    }
    
    func respondWithDataForRequest(_ dataRequest: AVAssetResourceLoadingDataRequest?) -> Bool {
        guard let dataRequest = dataRequest else { return false }
        let startOffset = Int(dataRequest.currentOffset == 0 ? dataRequest.requestedOffset : dataRequest.currentOffset)

        if self.data!.length < startOffset {
            return false
        }
        
        let unreadBytes = self.data!.length - startOffset
        let numberOfBytesToRespondWith  = min(Int(dataRequest.requestedLength), unreadBytes)
        dataRequest.respond(with: self.data!.subdata(with: NSMakeRange(startOffset, numberOfBytesToRespondWith)))
        
        return self.data!.length >= startOffset + dataRequest.requestedLength
    }


    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        if self.connection == nil {
            debug("Starting request to get media URL: \(self.mediaURL)")
            let request = URLRequest(url: replaceUrlScheme(loadingRequest.request.url!, scheme: "http")!)
            self.connection = session.dataTask(with: request)
            self.connection?.resume()
        }
        
        self.pendingRequests.append(loadingRequest)
        
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        self.pendingRequests = self.pendingRequests.filter { $0 != loadingRequest }
    }
}
