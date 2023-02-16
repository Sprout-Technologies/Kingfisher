//
//  MSStickerViewView+Kingfisher.swift
//  Kingfisher
//
//  Created by adad184 on 23/2/16.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#if canImport(UIKit)

import Messages
import UIKit

/// Represents the result of a Kingfisher retrieving image task.
public struct RetrieveStickerResult {
    public var diskCacheUrl: URL?

    public let source: Source
}

let stickerCache = ImageCache(name: "sticker")

public extension KingfisherWrapper where Base: MSStickerView {
    @discardableResult
    func setSticker(
        url: URL,
        options: KingfisherOptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<RetrieveStickerResult, KingfisherError>) -> Void)? = nil) -> DownloadTask?
    {
        return setSticker(
            with: url.convertToSource(),
            options: options,
            progressBlock: progressBlock,
            completionHandler: completionHandler)
    }

    @discardableResult
    func setSticker(
        with source: Source?,
        options: KingfisherOptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<RetrieveStickerResult, KingfisherError>) -> Void)? = nil) -> DownloadTask?
    {
        let options = KingfisherParsedOptionsInfo(KingfisherManager.shared.defaultOptions + (options ?? .empty))
        return setSticker(
            with: source,
            parsedOptions: options,
            progressBlock: progressBlock,
            completionHandler: completionHandler)
    }

    internal func setSticker(
        with source: Source?,
        parsedOptions: KingfisherParsedOptionsInfo,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<RetrieveStickerResult, KingfisherError>) -> Void)? = nil) -> DownloadTask?
    {
        var mutatingSelf = self
        guard let source = source else {
            mutatingSelf.taskIdentifier = nil
            completionHandler?(.failure(KingfisherError.imageSettingError(reason: .emptySource)))
            return nil
        }

        var options = parsedOptions

        let issuedIdentifier = Source.Identifier.next()
        mutatingSelf.taskIdentifier = issuedIdentifier

        if base.shouldPreloadAllAnimation() {
            options.preloadAllAnimationData = true
        }

        if let block = progressBlock {
            options.onDataReceived = (options.onDataReceived ?? []) + [ImageLoadingProgressSideEffect(block)]
        }

        let task = KingfisherManager.shared.retrieveSticker(
            with: source,
            options: options,
            downloadTaskUpdated: { mutatingSelf.imageTask = $0 },
            completionHandler: { result in
                CallbackQueue.mainCurrentOrAsync.execute {
                    guard issuedIdentifier == self.taskIdentifier else {
                        let reason: KingfisherError.ImageSettingErrorReason
                        do {
                            let value = try result.get()
                            reason = .notCurrentSourceTask(result: nil, error: nil, source: source)
                        } catch {
                            reason = .notCurrentSourceTask(result: nil, error: error, source: source)
                        }
                        let error = KingfisherError.imageSettingError(reason: reason)
                        completionHandler?(.failure(error))
                        return
                    }

                    mutatingSelf.imageTask = nil
                    mutatingSelf.taskIdentifier = nil

                    switch result {
                    case .success(let value):

                        if let url = value.diskCacheUrl {
                            self.base.sticker = try? MSSticker(contentsOfFileURL: url, localizedDescription: "")
                        }
                        completionHandler?(result)

                    case .failure:
                        self.base.sticker = nil
                        completionHandler?(result)
                    }
                }
            })
        mutatingSelf.imageTask = task
        return task
    }

    // MARK: Cancelling Downloading Task

    /// Cancels the image download task of the image view if it is running.
    /// Nothing will happen if the downloading has already finished.
    func cancelDownloadTask() {
        imageTask?.cancel()
    }
}

// MARK: - Associated Object

private var taskIdentifierKey: Void?
private var indicatorKey: Void?
private var indicatorTypeKey: Void?
private var placeholderKey: Void?
private var imageTaskKey: Void?

public extension KingfisherWrapper where Base: MSStickerView {
    // MARK: Properties

    private(set) var taskIdentifier: Source.Identifier.Value? {
        get {
            let box: Box<Source.Identifier.Value>? = getAssociatedObject(base, &taskIdentifierKey)
            return box?.value
        }
        set {
            let box = newValue.map { Box($0) }
            setRetainedAssociatedObject(base, &taskIdentifierKey, box)
        }
    }

    private var imageTask: DownloadTask? {
        get { return getAssociatedObject(base, &imageTaskKey) }
        set { setRetainedAssociatedObject(base, &imageTaskKey, newValue) }
    }
}

extension MSStickerView {
    @objc func shouldPreloadAllAnimation() -> Bool { return true }
}

extension KingfisherManager {
    func retrieveSticker(
        with source: Source,
        options: KingfisherParsedOptionsInfo,
        downloadTaskUpdated: DownloadTaskUpdatedBlock? = nil,
        completionHandler: ((Result<RetrieveStickerResult, KingfisherError>) -> Void)?) -> DownloadTask?
    {
        var options = options

        let retrievingContext = RetrievingContext(options: options, originalSource: source)
        var retryContext: RetryContext?

        func startNewRetrieveTask(
            with source: Source,
            downloadTaskUpdated: DownloadTaskUpdatedBlock?)
        {
            let newTask = retrieveSticker(with: source, context: retrievingContext) { result in
                handler(currentSource: source, result: result)
            }
            downloadTaskUpdated?(newTask)
        }

        func failCurrentSource(_ source: Source, with error: KingfisherError) {
            // Skip alternative sources if the user cancelled it.
            guard !error.isTaskCancelled else {
                completionHandler?(.failure(error))
                return
            }
            // When low data mode constrained error, retry with the low data mode source instead of use alternative on fly.
            guard !error.isLowDataModeConstrained else {
                if let source = retrievingContext.options.lowDataModeSource {
                    retrievingContext.options.lowDataModeSource = nil
                    startNewRetrieveTask(with: source, downloadTaskUpdated: downloadTaskUpdated)
                } else {
                    // This should not happen.
                    completionHandler?(.failure(error))
                }
                return
            }
            if let nextSource = retrievingContext.popAlternativeSource() {
                retrievingContext.appendError(error, to: source)
                startNewRetrieveTask(with: nextSource, downloadTaskUpdated: downloadTaskUpdated)
            } else {
                // No other alternative source. Finish with error.
                if retrievingContext.propagationErrors.isEmpty {
                    completionHandler?(.failure(error))
                } else {
                    retrievingContext.appendError(error, to: source)
                    let finalError = KingfisherError.imageSettingError(
                        reason: .alternativeSourcesExhausted(retrievingContext.propagationErrors)
                    )
                    completionHandler?(.failure(finalError))
                }
            }
        }

        func handler(currentSource: Source, result: Result<RetrieveStickerResult, KingfisherError>) {
            switch result {
            case .success:
                completionHandler?(result)
            case .failure(let error):
                if let retryStrategy = options.retryStrategy {
                    let context = retryContext?.increaseRetryCount() ?? RetryContext(source: source, error: error)
                    retryContext = context

                    retryStrategy.retry(context: context) { decision in
                        switch decision {
                        case .retry(let userInfo):
                            retryContext?.userInfo = userInfo
                            startNewRetrieveTask(with: source, downloadTaskUpdated: downloadTaskUpdated)
                        case .stop:
                            failCurrentSource(currentSource, with: error)
                        }
                    }
                } else {
                    failCurrentSource(currentSource, with: error)
                }
            }
        }

        return retrieveSticker(
            with: source,
            context: retrievingContext)
        {
            result in
            handler(currentSource: source, result: result)
        }
    }

    private func retrieveSticker(
        with source: Source,
        context: RetrievingContext,
        completionHandler: ((Result<RetrieveStickerResult, KingfisherError>) -> Void)?) -> DownloadTask?
    {
        let options = context.options
        if options.forceRefresh {
            return loadAndCacheSticker(
                source: source,
                context: context,
                completionHandler: completionHandler)?.value

        } else {
            let loadedFromCache = retrieveStickerFromCache(
                source: source,
                context: context,
                completionHandler: completionHandler)

            if loadedFromCache {
                return nil
            }

            return loadAndCacheSticker(
                source: source,
                context: context,
                completionHandler: completionHandler)?.value
        }
    }

    private func cacheSticker(
        source: Source,
        options: KingfisherParsedOptionsInfo,
        context: RetrievingContext,
        result: Result<ImageLoadingResult, KingfisherError>,
        completionHandler: ((Result<RetrieveStickerResult, KingfisherError>) -> Void)?)
    {
        switch result {
        case .success(let value):
            let coordinator = CacheCallbackCoordinator(
                shouldWaitForCache: options.waitForCache, shouldCacheOriginal: false)
            var result = RetrieveStickerResult(
                diskCacheUrl: nil,
                source: source)

            // Add image to cache.
            let targetCache = stickerCache
            targetCache.diskStorage.config.autoExtAfterHashedFileName = true

            do {
                try targetCache.diskStorage.store(value: value.originalData, forKey: source.cacheKey)

                result.diskCacheUrl = targetCache.diskStorage.cacheFileURL(forKey: source.cacheKey)

                coordinator.apply(.cachingImage) {
                    completionHandler?(.success(result))
                }
            } catch {
                completionHandler?(.failure(KingfisherError.cacheError(reason: .diskStorageIsNotReady(cacheURL: source.url!))))
            }

            coordinator.apply(.cacheInitiated) {
                completionHandler?(.success(result))
            }

        case .failure(let error):
            completionHandler?(.failure(error))
        }
    }

    @discardableResult
    func loadAndCacheSticker(
        source: Source,
        context: RetrievingContext,
        completionHandler: ((Result<RetrieveStickerResult, KingfisherError>) -> Void)?) -> DownloadTask.WrappedTask?
    {
        let options = context.options
        func _cacheSticker(_ result: Result<ImageLoadingResult, KingfisherError>) {
            cacheSticker(
                source: source,
                options: options,
                context: context,
                result: result,
                completionHandler: completionHandler)
        }

        switch source {
        case .network(let resource):
            let downloader = options.downloader ?? self.downloader
            let task = downloader.downloadImage(
                with: resource.downloadURL, options: options, completionHandler: _cacheSticker)

            // The code below is neat, but it fails the Swift 5.2 compiler with a runtime crash when
            // `BUILD_LIBRARY_FOR_DISTRIBUTION` is turned on. I believe it is a bug in the compiler.
            // Let's fallback to a traditional style before it can be fixed in Swift.
            //
            // https://github.com/onevcat/Kingfisher/issues/1436
            //
            // return task.map(DownloadTask.WrappedTask.download)

            if let task = task {
                return .download(task)
            } else {
                return nil
            }

//        case .provider(let provider):
//            provideImage(provider: provider, options: options, completionHandler: _cacheImage)
//            return .dataProviding
        default:
            return nil
        }
    }

    func retrieveStickerFromCache(
        source: Source,
        context: RetrievingContext,
        completionHandler: ((Result<RetrieveStickerResult, KingfisherError>) -> Void)?) -> Bool
    {
        let key = source.cacheKey

        let url = stickerCache.diskStorage.cacheFileURL(forKey: key)

        if FileManager.default.fileExists(atPath: url.path) {
            let value = RetrieveStickerResult(
                diskCacheUrl: url,
                source: source)

            completionHandler?(.success(value))

            return true
        } else {
            return false
        }
    }
}

#endif
