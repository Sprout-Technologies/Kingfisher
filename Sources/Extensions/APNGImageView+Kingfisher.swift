//
//  APNGImageView+Kingfisher.swift
//  Kingfisher
//
//  Created by ljc on 2023/2/16.
//
//  Copyright (c) 2023 Wei Wang <onevcat@gmail.com>
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

#if os(iOS)

import APNGKit
import UIKit

private let memoryCache = {
    let totalMemory = ProcessInfo.processInfo.physicalMemory
    let costLimit = totalMemory / 4
    let memoryStorage = MemoryStorage.Backend<APNGImage>(
        config: .init(totalCostLimit: (costLimit > Int.max) ? Int.max : Int(costLimit))
    )
    return memoryStorage
}()

private let diskCache = {
    let config = DiskStorage.Config(
        name: "apng",
        sizeLimit: 0,
        directory: nil)
    return DiskStorage.Backend<Data>(noThrowConfig: config, creatingDirectory: true)
}()

public struct RetrieveAPNGResult {
    /// Gets the image object of this result.
    public let image: APNGImage

    /// Gets the cache source of the image. It indicates from which layer of cache this image is retrieved.
    /// If the image is just downloaded from network, `.none` will be returned.
    public let cacheType: CacheType

    /// The `Source` which this result is related to. This indicated where the `image` of `self` is referring.
    public let source: Source

    /// The original `Source` from which the retrieve task begins. It can be different from the `source` property.
    /// When an alternative source loading happened, the `source` will be the replacing loading target, while the
    /// `originalSource` will be kept as the initial `source` which issued the image loading process.
    public let originalSource: Source

    /// Gets the data behind the result.
    ///
    /// If this result is from a network downloading (when `cacheType == .none`), calling this returns the downloaded
    /// data. If the reuslt is from cache, it serializes the image with the given cache serializer in the loading option
    /// and returns the result.
    ///
    /// - Note:
    /// This can be a time-consuming action, so if you need to use the data for multiple times, it is suggested to hold
    /// it and prevent keeping calling this too frequently.
    public let data: () -> Data?
}

public extension KingfisherWrapper where Base: APNGImageView {
    @discardableResult
    func setImage(
        with resource: Resource?,
        placeholder: Placeholder? = nil,
        options: KingfisherOptionsInfo? = nil,
        completionHandler: ((Result<RetrieveAPNGResult, KingfisherError>) -> Void)? = nil) -> DownloadTask?
    {
        return setImage(
            with: resource?.convertToSource(),
            placeholder: placeholder,
            parsedOptions: KingfisherParsedOptionsInfo(options),
            completionHandler: completionHandler)
    }

    internal func setImage(
        with source: Source?,
        placeholder: Placeholder? = nil,
        parsedOptions: KingfisherParsedOptionsInfo,
        completionHandler: ((Result<RetrieveAPNGResult, KingfisherError>) -> Void)? = nil) -> DownloadTask?
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

        let task = KingfisherManager.shared.retrieveAPNG(
            with: source,
            options: options,
            downloadTaskUpdated: { mutatingSelf.imageTask = $0 },
            referenceTaskIdentifierChecker: { issuedIdentifier == self.taskIdentifier },
            completionHandler: { result in
                CallbackQueue.mainCurrentOrAsync.execute {
                    guard issuedIdentifier == self.taskIdentifier else {
                        let reason: KingfisherError.ImageSettingErrorReason = .notCurrentSourceTask(result: nil, error: nil, source: source)
                        let error = KingfisherError.imageSettingError(reason: reason)
                        completionHandler?(.failure(error))
                        return
                    }

                    mutatingSelf.imageTask = nil
                    mutatingSelf.taskIdentifier = nil

                    switch result {
                    case .success(let value):
                        self.base.image = value.image
                        completionHandler?(result)

                    case .failure:
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

public extension KingfisherWrapper where Base: APNGImageView {
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

extension APNGImageView {
    @objc func shouldPreloadAllAnimation() -> Bool { return true }
}

extension APNGImage: CacheCostCalculable {
    /// Cost of an image
    public var cacheCost: Int {
        let pixel = Int(size.width * size.height * scale * scale)
        return pixel * 4 * numberOfFrames
    }
}

extension KingfisherManager {
    func retrieveAPNG(
        with source: Source,
        options: KingfisherParsedOptionsInfo,
        downloadTaskUpdated: DownloadTaskUpdatedBlock? = nil,
        referenceTaskIdentifierChecker: (() -> Bool)? = nil,
        completionHandler: ((Result<RetrieveAPNGResult, KingfisherError>) -> Void)?) -> DownloadTask?
    {
        if let checker = referenceTaskIdentifierChecker {
            options.onDataReceived?.forEach {
                $0.onShouldApply = checker
            }
        }

        let retrievingContext = RetrievingContext(options: options, originalSource: source)
        var retryContext: RetryContext?

        func startNewRetrieveTask(
            with source: Source,
            downloadTaskUpdated: DownloadTaskUpdatedBlock?)
        {
            let newTask = retrieveAPNG(with: source, context: retrievingContext) { result in
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

        func handler(currentSource: Source, result: Result<RetrieveAPNGResult, KingfisherError>) {
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

        return retrieveAPNG(
            with: source,
            context: retrievingContext)
        {
            result in
            handler(currentSource: source, result: result)
        }
    }

    private func retrieveAPNG(
        with source: Source,
        context: RetrievingContext,
        completionHandler: ((Result<RetrieveAPNGResult, KingfisherError>) -> Void)?) -> DownloadTask?
    {
        let options = context.options
        if options.forceRefresh {
            return loadAndCacheAPNG(
                source: source,
                context: context,
                completionHandler: completionHandler)?.value

        } else {
            let loadedFromCache = retrieveAPNGFromCache(
                source: source,
                context: context,
                completionHandler: completionHandler)

            if loadedFromCache {
                return nil
            }

            if options.onlyFromCache {
                let error = KingfisherError.cacheError(reason: .imageNotExisting(key: source.cacheKey))
                completionHandler?(.failure(error))
                return nil
            }

            return loadAndCacheAPNG(
                source: source,
                context: context,
                completionHandler: completionHandler)?.value
        }
    }

    private func cacheAPNG(
        source: Source,
        options: KingfisherParsedOptionsInfo,
        context: RetrievingContext,
        result: Result<ImageLoadingResult, KingfisherError>,
        completionHandler: ((Result<RetrieveAPNGResult, KingfisherError>) -> Void)?)
    {
        switch result {
        case .success(let value):
            let coordinator = CacheCallbackCoordinator(
                shouldWaitForCache: options.waitForCache, shouldCacheOriginal: false)

            guard let apng = try? APNGImage(data: value.originalData) else {
                completionHandler?(.failure(KingfisherError.cacheError(reason: KingfisherError.CacheErrorReason.cannotConvertToAPNG(url: value.url))))
                return
            }

            let result = RetrieveAPNGResult(
                image: apng,
                cacheType: .none,
                source: source,
                originalSource: context.originalSource,
                data: { value.originalData })

            memoryCache.store(value: apng, forKey: source.cacheKey)

            try? diskCache.store(value: value.originalData, forKey: source.cacheKey)

            coordinator.apply(.cachingImage) {
                completionHandler?(.success(result))
            }

            coordinator.apply(.cacheInitiated) {
                completionHandler?(.success(result))
            }

        case .failure(let error):
            completionHandler?(.failure(error))
        }
    }

    @discardableResult
    func loadAndCacheAPNG(
        source: Source,
        context: RetrievingContext,
        completionHandler: ((Result<RetrieveAPNGResult, KingfisherError>) -> Void)?) -> DownloadTask.WrappedTask?
    {
        let options = context.options
        func _cacheAPNG(_ result: Result<ImageLoadingResult, KingfisherError>) {
            cacheAPNG(
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
                with: resource.downloadURL, options: options, completionHandler: _cacheAPNG)

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

    func retrieveAPNGFromCache(
        source: Source,
        context: RetrievingContext,
        completionHandler: ((Result<RetrieveAPNGResult, KingfisherError>) -> Void)?) -> Bool
    {
        let key = source.cacheKey

        if let image = memoryCache.value(forKey: key) {
            let result = RetrieveAPNGResult(
                image: image,
                cacheType: .memory,
                source: source,
                originalSource: context.originalSource,
                data: { nil })

            completionHandler?(.success(result))
            return true
        }

        if let data = try? diskCache.value(forKey: key),
           let image = try? APNGImage(data: data)
        {
            let result = RetrieveAPNGResult(
                image: image,
                cacheType: .disk,
                source: source,
                originalSource: context.originalSource,
                data: { nil })

            completionHandler?(.success(result))
            return true
        }

        return false
    }
}

#endif
