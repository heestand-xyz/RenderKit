//
//  PixelKitRender.swift
//  PixelKit
//
//  Created by Heestand XYZ on 2018-08-22.
//  Open Source - MIT License
//

import CoreGraphics
import Metal
import QuartzCore.CoreAnimation
import Resolution

public enum RenderThread {
    case none
    case main
    case background
    var queue: DispatchQueue? {
        switch self {
        case .none:
            return nil
        case .main:
            return .main
        case .background:
            return .global(qos: .background)
        }
    }
    func call(_ callback: @escaping () -> ()) {
        if self == .none || (self == .main && Thread.isMainThread) {
            callback()
            return
        }
        queue!.async {
            callback()
        }
    }
    func timerLoop(duration: Double, _ callback: @escaping () -> ()) {
        if self == .none {
            RunLoop.current.add(Timer(timeInterval: duration, repeats: false, block: { _ in
                callback()
                self.timerLoop(duration: duration, callback)
            }), forMode: .common)
            return
        }
        queue!.asyncAfter(deadline: .now() + .milliseconds(Int(duration * 1_000.0))) {
            callback()
            self.timerLoop(duration: duration, callback)
        }
    }
}
public var frameLoopRenderThread: RenderThread = .main

public protocol EngineDelegate {
    func textures(from node: NODE, with commandBuffer: MTLCommandBuffer) throws -> (a: MTLTexture?, b: MTLTexture?, custom: MTLTexture?)
    func tileTextures(from node: NODE & NODETileable, at tileIndex: TileIndex, with commandBuffer: MTLCommandBuffer) throws -> (a: MTLTexture?, b: MTLTexture?, custom: MTLTexture?)
}

protocol EngineInternalDelegate {
    var linkedNodes: [WeakNODE] { get set }
    var commandQueue: MTLCommandQueue! { get set }
    var metalDevice: MTLDevice! { get set }
    var bits: Bits { get set }
    var quadVertecis: Vertices! { get set }
    func makeSampler(interpolate: MTLSamplerMinMagFilter, extend: MTLSamplerAddressMode, mipFilter: MTLSamplerMipFilter, compare: MTLCompareFunction) throws -> MTLSamplerState
    func engineFrameIndex() -> Int
    func engineLinkIndex(of node: NODE) -> Int?
//    func engineDelay(frames: Int, done: @escaping () -> ())
    func didSetup(node: NODE, success: Bool)
    func willRender(node: NODE)
    func didRender(node: NODE, renderTime: Double, success: Bool)
}

public class Engine: LoggerDelegate {
    
    public var deleagte: EngineDelegate?
    var internalDelegate: EngineInternalDelegate!
    
    public enum RenderMode {
        case manual
        case auto
//        case manualTiles
//        case frameTree
//        case frameLoop
//        case frameLoopTiles
//        case frameLoopQueue
//        case instantQueue
//        case instantQueueSemaphore
//        case direct
//        public var isManual: Bool {
//            [.manual, .manualTiles].contains(self)
//        }
//        public var isFrameLoop: Bool {
//            [.frameLoop, .frameLoopTiles, .frameLoopQueue].contains(self)
//        }
//        public var isTile: Bool {
//            [.manualTiles, .frameLoopTiles].contains(self)
//        }
    }
    public var renderMode: Engine.RenderMode = .auto
    
    var frameTreeRendering: Bool = false
    
    public var renderInSync: Bool = false
    
    public var template: Bool = true
    
    public let logger: Logger

    public enum MetalErrorCode {
        case IOAF(Error)
        public var info: String {
            switch self {
            case .IOAF(let error):
                return "IOAF Error: \(error.localizedDescription)"
            }
        }
    }
    
    var instantQueueActivated: Bool = false
    
    public var metalErrorCodeCallback: ((Engine.MetalErrorCode) -> ())?
    
    // MARK: Manual Render
    
    public var manualRenderDelegate: ManualRenderDelegate?
    
    var manualRenderInProgress: Bool = false
    var manualRenderCallback: (() -> ())?
    
    // MARK: - Life Cycle -
    
    init() {
        self.logger = Logger(name: "RenderKit Engine")
        self.logger.delegate = self
    }
    
    // MARK: - Frame Loop
    
//    func frameLoop() {
//        if self.renderMode == .frameTree {
//            if !self.frameTreeRendering {
//                self.renderNODEsTree()
//            }
//        } else if self.renderMode.isFrameLoop {
//            self.renderNODEs()
//        } else if [.instantQueue, .instantQueueSemaphore].contains(self.renderMode) {
//            if !self.instantQueueActivated {
//                frameLoopRenderThread.call {
//                    while true {
//                        self.renderNODEs()
//                    }
//                }
//                self.instantQueueActivated = true
//            }
//        } else if self.renderMode.isManual {
//            self.checkManualRender()
//        }
//    }
    
    // MARK: - Logger Delegate
    
    public func loggerFrameIndex() -> Int {
        internalDelegate.engineFrameIndex()
    }
    
    public func loggerLinkIndex(of node: NODE) -> Int? {
        internalDelegate.engineLinkIndex(of: node)
    }
    
    // MARK: - Maual Render
    
//    enum ManualRenderError: Error {
//        case renderInProgress
//    }
//    
//    public func manuallyRender(_ done: @escaping () -> ()) throws {
//        guard !manualRenderInProgress else {
//            throw ManualRenderError.renderInProgress
//        }
//        logger.log(.info, .render, "Manual Render Started.")
//        manualRenderInProgress = true
//        manualRenderCallback = { frameLoopRenderThread.call(done) }
//    }
    
//    func checkManualRender() {
//
////        #if os(macOS)
////        let frameIndex = internalDelegate.engineFrameIndex()
////        guard frameIndex >= 2 else {
//////            internalDelegate.engineDelay(frames: 1) {
//////                self.checkManualRender()
//////            }
////            return
////        }
////        #endif
//
//        var someNodesNeedsRender: Bool = false
//        for node in internalDelegate.linkedNodes {
//            if node.needsRender {
//                someNodesNeedsRender = true
//                break
//            }
//        }
//
//        guard manualRenderInProgress else {
//            if someNodesNeedsRender {
//                manualRenderDelegate?.pixelNeedsManualRender()
//            }
//            return
//        }
//
//        if someNodesNeedsRender {
//
//            self.renderNODEs()
//
//        } else {
//
//            var someNodesAreInRender: Bool = false
//            for node in internalDelegate.linkedNodes {
//                if node.inRender {
//                    someNodesAreInRender = true
//                    break
//                }
//            }
//
//            if !someNodesAreInRender {
//
//                logger.log(.info, .render, "Manual Render Done.")
//                manualRenderInProgress = false
//                let cachedManualRenderCallback = manualRenderCallback!
//                manualRenderCallback = nil
//                cachedManualRenderCallback()
//
//            }
//
//        }
//
//    }
    
    // MARK: - Render
    
//    func renderNODEsTree() {
//        let nodesNeedsRender: [NODE] = internalDelegate.linkedNodes.filter { node -> Bool in
//            return node.needsRender
//        }
//        guard !nodesNeedsRender.isEmpty else { return }
//        frameTreeRendering = true
//        frameLoopRenderThread.call {
//            self.logger.log(.debug, .render, "-=-=-=-> Tree Started <-=-=-=-", loop: true)
//            var renderedNodes: [NODE] = []
//            func render(_ node: NODE) {
//                self.logger.log(.debug, .render, "-=-=-=-> Tree Render NODE: \"\(node.name)\"", loop: true)
//                let semaphore = DispatchSemaphore(value: 0)
//                frameLoopRenderThread.call {
//                    if node.view.superview != nil {
//                        #if os(iOS) || os(tvOS)
//                        node.view.metalView.setNeedsDisplay()
//                        #elseif os(macOS)
//                        let size = node.finalResolution.size
////                            logger.log(node: node, .warning, .render, "NODE Resolutuon unknown. Can't render in view.", loop: true)
////                            return
////                        }
//                        node.view.metalView.setNeedsDisplay(CGRect(x: 0, y: 0, width: size.width, height: size.height))
//                        #endif
//                        self.logger.log(node: node, .detail, .render, "View Render requested.", loop: true)
//                        guard let currentDrawable: CAMetalDrawable = node.view.metalView.currentDrawable else {
//                            self.logger.log(node: node, .error, .render, "Current Drawable not found.", loop: true)
//                            return
//                        }
//                        node.view.metalView.readyToRender = {
//                            node.view.metalView.readyToRender = nil
//                            self.renderNODE(node, with: currentDrawable, done: { success in
//                                self.logger.log(.debug, .render, "-=-=-=-> View Tree Did Render NODE: \"\(node.name)\"", loop: true)
//                                semaphore.signal()
//                            })
//                        }
//                    } else {
//                        self.renderNODE(node, done: { success in
//                            self.logger.log(.debug, .render, "-=-=-=-> Tree Did Render NODE: \"\(node.name)\"", loop: true)
//                            semaphore.signal()
//                        })
//                    }
//                }
//                _ = semaphore.wait(timeout: .distantFuture)
//                renderedNodes.append(node)
//            }
//            func reverse(_ inNode: NODE & NODEInIO) {
//                self.logger.log(.debug, .render, "-=-=-=-> Tree Reverse NODE: \"\(inNode.name)\"", loop: true)
//                for subNode in inNode.inputList {
//                    if !subNode.contained(in: renderedNodes) {
//                        if let subInNode = subNode as? NODE & NODEInIO {
//                            reverse(subInNode)
//                        }
//                        render(subNode)
//                    }
//                }
//            }
//            func traverse(_ node: NODE) {
//                self.logger.log(.debug, .render, "-=-=-=-> Tree Traverse NODE: \"\(node.name)\"", loop: true)
//                if let outNode = node as? NODEOutIO {
//                    for inNodePath in outNode.outputPathList {
//                        let inNode = inNodePath.nodeIn as! NODE & NODEInIO
//                        self.logger.log(.debug, .render, "-=-=-=-> Tree Traverse Sub NODE: \"\(inNode.name)\"", loop: true)
//                        var allInsRendered = true
//                        for subNode in inNode.inputList {
//                            if !subNode.contained(in: renderedNodes) {
//                                allInsRendered = false
//                                break
//                            }
//                        }
//                        if !allInsRendered {
//                            reverse(inNode)
//                        }
//                        if !inNode.contained(in: renderedNodes) {
//                            render(inNode)
//                            traverse(inNode)
//                        }
//                    }
//                }
//            }
//            for node in nodesNeedsRender {
//                if !node.contained(in: renderedNodes) {
//                    render(node)
//                    traverse(node)
//                }
//            }
//            self.logger.log(.debug, .render, "-=-=-=-> Tree Ended <-=-=-=-", loop: true)
//            self.frameTreeRendering = false
//        }
//    }
    
//    func renderNODEs() {
//        loop: for node in internalDelegate.linkedNodes {
//            var node = node
//            if node.needsRender {
//                
//                if [.frameLoopQueue, .instantQueue, .instantQueueSemaphore].contains(renderMode) {
//                    guard !node.rendering else {
//                        logger.log(node: node, .warning, .render, "Render in progress.", loop: true)
//                        continue
//                    }
//                    if let nodeIn = node as? NODEInIO {
//                        for nodeOut in nodeIn.inputList {
//                            guard node.renderIndex + 1 == nodeOut.renderIndex else {
//                                logger.log(node: node, .detail, .render, "Queue In: \(node.renderIndex) + 1 != \(nodeOut.renderIndex)", loop: true)
//                                continue
//                            }
////                            log(node: node, .warning, .render, ">>> Queue In: \(node.renderIndex) + 1 == \(nodeOut.renderIndex)")
//                        }
//                    }
//                    if let nodeOut = node as? NODEOutIO {
//                        for nodeOutPath in nodeOut.outputPathList {
//                            guard node.renderIndex == nodeOutPath.nodeIn.renderIndex else {
//                                logger.log(node: node, .detail, .render, "Queue Out: \(node.renderIndex) != \(nodeOutPath.nodeIn.renderIndex)", loop: true)
//                                continue
//                            }
////                            log(node: node, .warning, .render, ">>> Queue Out: \(node.renderIndex) == \(nodeOutPath.nodeIn.renderIndex)")
//                        }
//                    }
//                }
//                
//                if let nodeIn = node as? NODE & NODEInIO {
//                    let nodeOuts = nodeIn.inputList
//                    for (i, nodeOut) in nodeOuts.enumerated() {
//                        var rendered: Bool = false
//                        if renderMode.isTile {
//                            if let tileNode2d = nodeOut as? NODETileable2D {
//                                rendered = tileNode2d.tileTextures != nil
//                            } else if let tileNode3d = nodeOut as? NODETileable3D {
//                                rendered = tileNode3d.tileTextures != nil
//                            }
//                        } else {
//                            rendered = nodeOut.texture != nil
//                        }
//                        if !rendered {
//                            logger.log(node: node, .warning, .render, "NODE Ins \(i) not rendered.", loop: true)
//                            /// The chained node will call setNeedsRender when done
//                            node.needsRender = false
//                            continue loop
//                        }
//                    }
//                }
//                
//                var semaphore: DispatchSemaphore?
//                if renderMode == .instantQueueSemaphore {
//                    semaphore = DispatchSemaphore(value: 0)
//                }
//                
//                frameLoopRenderThread.call {
//                    if frameLoopRenderThread == .main && node.view.superview != nil {
//                        #if os(iOS) || os(tvOS)
//                        node.view.metalView.setNeedsDisplay()
//                        #elseif os(macOS)
//                        let size = node.finalResolution.size
//                        node.view.metalView.setNeedsDisplay(CGRect(x: 0, y: 0, width: size.width, height: size.height))
//                        #endif
//                        self.logger.log(node: node, .detail, .render, "View Render requested.", loop: true)
//                        let currentDrawable: CAMetalDrawable? = node.view.metalView.currentDrawable
//                        if currentDrawable == nil {
//                            self.logger.log(node: node, .error, .render, "Current Drawable not found.", loop: true)
//                        }
//                        node.view.metalView.readyToRender = {
//                            node.view.metalView.readyToRender = nil
//                            self.renderNODE(node, with: currentDrawable, done: { success in
//                                if self.renderMode == .instantQueueSemaphore {
//                                    semaphore!.signal()
//                                }
//                            })
//                        }
//                    } else {
//                        self.renderNODE(node, done: { success in
//                            if self.renderMode == .instantQueueSemaphore {
//                                semaphore!.signal()
//                            }
//                        })
//                    }
//                }
//                
//                if self.renderMode == .instantQueueSemaphore {
//                    _ = semaphore!.wait(timeout: .distantFuture)
//                }
//                
//            }
//        }
//    }
    
    // MARK: - Render NODE
    
    enum RenderNODEError: LocalizedError {
        case bypassed
        case renderInProgress
        case tileRenderNotSupported
        case currentDrawableNotFound
        var errorDescription: String? {
            switch self {
            case .bypassed:
                return "Render NODE Error - Bypassed"
            case .renderInProgress:
                return "Render NODE Error - Render in Progress"
            case .tileRenderNotSupported:
                return "Render NODE Error - Tile Render Not Supported"
            case .currentDrawableNotFound:
                return "Render NODE Error - Current Drawable Not Found"
            }
        }
    }
    
    public func renderNODE(_ node: NODE,
                           renderRequest: RenderRequest,
                           completion: @escaping (RenderResult) -> ()) {
        
        logger.log(node: node, .info, .render, "Render NODE", loop: true)
        
        func wait(for currentDrawable: CAMetalDrawable, nodeView: NODEView, completion: @escaping () -> ()) {
            nodeView.metalView.readyToRender = {
                nodeView.metalView.readyToRender = nil
                completion()
            }
            #if os(iOS) || os(tvOS)
            nodeView.metalView.setNeedsDisplay()
            #elseif os(macOS)
            let size: CGSize = node.finalResolution.size
            let frame: CGRect = CGRect(origin: .zero, size: size)
            nodeView.metalView.setNeedsDisplay(frame)
            #endif
        }
        
        func renderAdditional(completion: @escaping () -> ()) {
            var additionalViews: [NODEView] = node.additionalViews
            func next() {
                if additionalViews.isEmpty {
                    completion()
                } else {
                    renderNextAdditional(nodeView: additionalViews.remove(at: 0))
                }
            }
            func renderNextAdditional(nodeView: NODEView) {
                guard let currentDrawable: CAMetalDrawable = nodeView.metalView.currentDrawable else {
                    next()
                    return
                }
                wait(for: currentDrawable, nodeView: nodeView) { [weak self] in
                    self?.renderNODE(node,
                                     renderRequest: renderRequest,
                                     with: currentDrawable,
                                     completion: { _ in
                                        next()
                                     })
                }
            }
            next()
        }
        
        frameLoopRenderThread.call { [weak self, weak node] in
            guard let self = self else { return }
            guard let node = node else { return }
            if frameLoopRenderThread == .main && node.view.superview != nil {
                
                guard let currentDrawable: CAMetalDrawable = node.view.metalView.currentDrawable else {
                    completion(.failure(RenderNODEError.currentDrawableNotFound))
                    return
                }
                
                wait(for: currentDrawable, nodeView: node.view) { [weak self] in
                    self?.renderNODE(node,
                                     renderRequest: renderRequest,
                                     with: currentDrawable,
                                     completion: { result in
                                        renderAdditional {
                                            completion(result)
                                        }
                                     })
                }
                
            } else {
                
                self.renderNODE(node,
                                renderRequest: renderRequest,
                                with: nil,
                                completion: { result in
                                    renderAdditional {
                                        completion(result)
                                    }
                                })
            }
        }
        
    }
    private func renderNODE(_ node: NODE,
                            renderRequest: RenderRequest,
                            with currentDrawable: CAMetalDrawable? = nil,
                            force: Bool = false,
                            completion: @escaping (RenderResult) -> ()) {
        guard !node.bypass || node is NODEGenerator else {
            logger.log(node: node, .debug, .render, "Render bypassed.", loop: true)
            completion(.failure(RenderNODEError.bypassed))
            return
        }
        guard !node.renderInProgress else {
            logger.log(node: node, .debug, .render, "Render in progress...", loop: true)
            completion(.failure(RenderNODEError.renderInProgress))
            return
        }
        node.renderInProgress = true
        internalDelegate.willRender(node: node)
        let renderStartTime = CFAbsoluteTimeGetCurrent()
        logger.log(node: node, .detail, .render, "Starting render.\(force ? " Forced." : "")", loop: true)
        func setupDone() {
            internalDelegate?.didSetup(node: node, success: true)
        }
        func setupFailed(with error: Error) {
            logger.log(node: node, .error, .render, "Render setup failed.\(force ? " Forced." : "")", loop: true, e: error)
            node.renderInProgress = false
            internalDelegate?.didSetup(node: node, success: false)
            completion(.failure(error))
        }
        func renderDone(node: NODE) {
            let renderTime = CFAbsoluteTimeGetCurrent() - renderStartTime
            let renderTimeMs = Double(Int(round(renderTime * 10_000))) / 10
            var finalResolutionText: String = "\(node.finalResolution)"
            if let node3d = node as? NODE3D {
                finalResolutionText = "\(node3d.finalResolution3d)"
            }
            self.logger.log(node: node, .info, .render, "Render Done at \(finalResolutionText) \(force ? "Forced. " : "")[\(renderTimeMs)ms]", loop: true)
            node.renderInProgress = false
            internalDelegate.didRender(node: node, renderTime: renderTimeMs, success: true)
        }
        func renderFailed(with error: Error, node: NODE) {
            let renderTime = CFAbsoluteTimeGetCurrent() - renderStartTime
            let renderTimeMs = Double(Int(round(renderTime * 10_000))) / 10
            var ioafMsg: String? = nil
            let err = error.localizedDescription
            if err.contains("IOAF") {
                frameLoopRenderThread.call { [weak self] in
                    self?.metalErrorCodeCallback?(.IOAF(error))
                }
                ioafMsg = "IOAF. Sorry, this is an Metal GPU error, usually seen on older devices. Error: \(err)"
            }
            self.logger.log(node: node, .error, .render, "Render of shader failed... \(force ? "Forced." : "") \(ioafMsg ?? "")", loop: true, e: error)
            node.renderInProgress = false
            internalDelegate.didRender(node: node, renderTime: renderTimeMs, success: false)
            completion(.failure(error))
        }
//        if self.renderMode.isTile {
//            node.renderInProgress = false
//            completion(.failure(RenderNODEError.tileRenderNotSupported))
//            guard let nodeTileable = node as? NODE & NODETileable else {
//                setupFailed(with: RenderError.nodeNotTileable)
//                return
//            }
//            frameLoopRenderThread.call {
//                do {
//                    try self.tileRender(nodeTileable, force: force, completed: {
//                        frameLoopRenderThread.call {
//                            renderDone()
//                            nodeTileable.didRenderTiles(force: force)
//                            done(true)
//                        }
//                    }, failed: { error in
//                        frameLoopRenderThread.call {
//                            renderFailed(with: error)
//                        }
//                    })
//                    setupDone()
//                } catch {
//                    setupFailed(with: error)
//                }
//            }
//        } else {
        let startFrameIndex: Int = internalDelegate.engineFrameIndex()
        do {
            try self.render(node,
                            with: currentDrawable,
                            force: force,
                            completed: { [weak self, weak node] texture in
                                guard let self = self else { return }
                                guard let node = node else { return }
                                renderDone(node: node)
                                let finalFrameIndex: Int = self.internalDelegate.engineFrameIndex()
                                let renderTime = CFAbsoluteTimeGetCurrent() - renderStartTime
                                let renderResponse = RenderResponse(id: renderRequest.id,
                                                                    startFrameIndex: startFrameIndex,
                                                                    finalFrameIndex: finalFrameIndex,
                                                                    renderTime: renderTime,
                                                                    texture: texture)
                                let renderPack = RenderPack(request: renderRequest, response: renderResponse)
                                completion(.success(renderPack))
                            }, failed: { [weak node] error in
                                guard let node = node else { return }
                                renderFailed(with: error, node: node)
                            })
            setupDone()
        } catch {
            setupFailed(with: error)
        }
//        }
    }
    
    public enum RenderError: Error {
        case delegateMissing
        case commandBuffer
        case texture(String)
        case custom(String)
        case drawable(String)
        case commandEncoder
        case uniformsBuffer
        case vertices
        case vertexTexture
        case nilCustomTexture
        case nodeNotTileable
        case noTitleableTextures
        case nodeNot3D
        case tileError(String, Error)
        case tileRenderCanceled
        case noSampler
        case noPipeline
    }
    
    // MARK: - Tile Render
    
//    func tileRender(_ node: NODE & NODETileable, force: Bool, completed: @escaping () -> (), failed: @escaping (Error) -> ()) throws {
//        if var nodeTileable2d = node as? NODETileable2D {
//            if (node.finalResolution.width / nodeTileable2d.tileResolution.width).remainder(dividingBy: 1.0) != 0.0 {
//                logger.log(node: node, .warning, .render, "Tile resolution not even in width.", loop: true)
//            }
//            if (node.finalResolution.height / nodeTileable2d.tileResolution.height).remainder(dividingBy: 1.0) != 0.0 {
//                logger.log(node: node, .warning, .render, "Tile resolution not even in height.", loop: true)
//            }
//            let tileCountResolution: Resolution = node.finalResolution / nodeTileable2d.tileResolution
//
//            var tileTextures: [[MTLTexture]] = []
//            for y in 0..<tileCountResolution.h {
//                var tileTextureRow: [MTLTexture] = []
//                for x in 0..<tileCountResolution.w {
//                    logger.log(node: node, .detail, .render, "Render Tile at x\(x) y\(y).", loop: true)
//                    let semaphore = DispatchSemaphore(value: 0)
//                    var didError = false
//                    try render(node, with: nil, tileIndex: TileIndex(x: x, y: y, z: 0), force: force, completed: { texture in
//                        tileTextureRow.append(texture)
//                        semaphore.signal()
//                    }) { error in
//                        failed(RenderError.tileError("Tile error at x\(x) y\(y).", error))
//                        didError = true
//                        semaphore.signal()
//                    }
//                    _ = semaphore.wait(timeout: .distantFuture)
//                    if didError {
//                        throw RenderError.tileRenderCanceled
//                    }
//                }
//                tileTextures.append(tileTextureRow)
//            }
//            nodeTileable2d.tileTextures = tileTextures
//            completed()
//
//        } else if var nodeTileable3d = node as? NODETileable3D {
//            guard let node3d = node as? NODE3D else {
//                throw RenderError.nodeNot3D
//            }
//            if (node3d.renderedResolution3d.vector.x / nodeTileable3d.tileResolution.vector.x).remainder(dividingBy: 1.0) != 0.0 {
//                logger.log(node: node, .warning, .render, "Tile resolution not even in x.", loop: true)
//            }
//            if (node3d.renderedResolution3d.vector.y / nodeTileable3d.tileResolution.vector.y).remainder(dividingBy: 1.0) != 0.0 {
//                logger.log(node: node, .warning, .render, "Tile resolution not even in y.", loop: true)
//            }
//            if (node3d.renderedResolution3d.vector.z / nodeTileable3d.tileResolution.vector.z).remainder(dividingBy: 1.0) != 0.0 {
//                logger.log(node: node, .warning, .render, "Tile resolution not even in z.", loop: true)
//            }
//            let tileCountResolution: Resolution3D = node3d.renderedResolution3d / nodeTileable3d.tileResolution
//
//            var tileTextures: [[[MTLTexture]]] = []
//            for z in 0..<tileCountResolution.z {
//                var tileTextureGrid: [[MTLTexture]] = []
//                for y in 0..<tileCountResolution.y {
//                    var tileTextureRow: [MTLTexture] = []
//                    for x in 0..<tileCountResolution.x {
//                        logger.log(node: node, .detail, .render, "Render Tile at x\(x) y\(y) z\(z).", loop: true)
//                        let semaphore = DispatchSemaphore(value: 0)
//                        var didError = false
//                        try render(node, with: nil, tileIndex: TileIndex(x: x, y: y, z: z), force: force, completed: { texture in
//                            tileTextureRow.append(texture)
//                            semaphore.signal()
//                        }) { error in
//                            failed(RenderError.tileError("Tile error at x\(x) y\(y) z\(z).", error))
//                            didError = true
//                            semaphore.signal()
//                        }
//                        _ = semaphore.wait(timeout: .distantFuture)
//                        if didError {
//                            throw RenderError.tileRenderCanceled
//                        }
//                    }
//                    tileTextureGrid.append(tileTextureRow)
//                }
//                tileTextures.append(tileTextureGrid)
//            }
//            nodeTileable3d.tileTextures = tileTextures
//            completed()
//
//        } else {
//            throw RenderError.nodeNotTileable
//        }
//    }
    
    // MARK: - Main Render -
    
    func render(_ node: NODE, with currentDrawable: CAMetalDrawable?, tileIndex: TileIndex? = nil, force: Bool, completed: @escaping (MTLTexture) -> (), failed: @escaping (Error) -> ()) throws {
        
//        print("RENDER::::::::::::::", node.name, node.finalResolution)
//        if node.finalResolution == ._128 {
//            print("---------------128-------------")
//        }
        
        let bits = node.overrideBits ?? internalDelegate.bits
        let device = internalDelegate.metalDevice!
        
        if tileIndex != nil {
            guard node is NODETileable else {
                throw RenderError.nodeNotTileable
            }
        }
        
        guard deleagte != nil else {
            logger.log(node: node, .error, .render, "Engine deleagte is not set.", loop: true)
            throw RenderError.delegateMissing
        }

        // Render Time
        let globalRenderTime = CFAbsoluteTimeGetCurrent()
        var localRenderTime = CFAbsoluteTimeGetCurrent()
        var renderTime: Double = -1
        var renderTimeMs: Double = -1
        logger.log(node: node, .debug, .metal, "Render Time: Started", loop: true)

        
        // MARK: Command Buffer
        
        guard let commandBuffer = internalDelegate.commandQueue.makeCommandBuffer() else {
            throw RenderError.commandBuffer
        }
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Time: [\(renderTimeMs)ms] Command Buffer ", loop: true)
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }
        
        // MARK: Template
        
        let template: Bool = false
        
        // MARK: Input Texture
        
        let generator: Bool = node is NODEGenerator
        let resourceCustom: Bool = node is NODEResourceCustom
        var (inputTexture, secondInputTexture, customTexture): (MTLTexture?, MTLTexture?, MTLTexture?)
        if !template {
            if tileIndex != nil {
                (inputTexture, secondInputTexture, customTexture) = try deleagte!.tileTextures(from: node as! NODE & NODETileable, at: tileIndex!, with: commandBuffer)
            } else {
                (inputTexture, secondInputTexture, customTexture) = try deleagte!.textures(from: node, with: commandBuffer)
            }
        }
        
        // MARK: Drawable
        
        let width: Int
        let height: Int
        let depth: Int
        if tileIndex != nil {
            width = node is NODE3D ? (node as! NODETileable3D).tileResolution.x : (node as! NODETileable2D).tileResolution.w
            height = node is NODE3D ? (node as! NODETileable3D).tileResolution.y : (node as! NODETileable2D).tileResolution.h
            depth = node is NODE3D ? (node as! NODETileable3D).tileResolution.z : 1
        } else {
            width = node is NODE3D ? (node as! NODE3D).renderedResolution3d.x : node.finalResolution.w
            height = node is NODE3D ? (node as! NODE3D).renderedResolution3d.y : node.finalResolution.h
            depth = node is NODE3D ? (node as! NODE3D).renderedResolution3d.z : 1
        }
        var tileCountX: Int = 0
        var tileCountY: Int = 0
        var tileCountZ: Int = 0
        var tileFraction: CGFloat = 0.0
        if tileIndex != nil {
            let realSize = node is NODE3D ? (node as! NODE3D).renderedResolution3d.x : node.finalResolution.w
            tileFraction = CGFloat(width) / CGFloat(realSize)
            tileCountX = realSize / width
            tileCountY = realSize / height
            tileCountZ = realSize / depth
        }
        
        var viewDrawable: CAMetalDrawable? = nil
        let drawableTexture: MTLTexture
        if currentDrawable != nil && !(node is NODE3D)/* && node.overrideBits == nil*/ {
            viewDrawable = currentDrawable!
            drawableTexture = currentDrawable!.texture
            logger.log(node: node, .detail, .render, "Drawable Texture - Current", loop: true)
        } else if node.texture != nil && width == node.texture!.width && height == node.texture!.height && depth == node.texture!.depth/* && node.overrideBits == nil*/ {
            drawableTexture = node.texture!
            logger.log(node: node, .detail, .render, "Drawable Texture - Reuse", loop: true)
        } else {
            if node is NODE3D {
                drawableTexture = try Texture.emptyTexture3D(at: .custom(x: width, y: height, z: depth), bits: bits, on: device)
            } else {
                drawableTexture = try Texture.emptyTexture(size: CGSize(width: width, height: height), bits: bits, on: device)
            }
            logger.log(node: node, .detail, .render, "Drawable Texture - New", loop: true)
        }
        
        if logger.highResWarnings {
            if node is NODE3D {
                let drawRes = Resolution3D(texture: drawableTexture)
                if (drawRes >= ._1024) != false {
                    logger.log(node: node, .detail, .render, "Epic resolution: \(drawRes)", loop: true)
                } else if (drawRes >= ._512) != false {
                    logger.log(node: node, .detail, .render, "Extreme resolution: \(drawRes)", loop: true)
                } else if (drawRes >= ._256) != false {
                    logger.log(node: node, .detail, .render, "High resolution: \(drawRes)", loop: true)
                }
            } else {
                let drawRes = Resolution(texture: drawableTexture)
                if (drawRes >= ._16384) != false {
                    logger.log(node: node, .detail, .render, "Epic resolution: \(drawRes)", loop: true)
                } else if (drawRes >= ._8192) != false {
                    logger.log(node: node, .detail, .render, "Extreme resolution: \(drawRes)", loop: true)
                } else if (drawRes >= ._4096) != false {
                    logger.log(node: node, .detail, .render, "High resolution: \(drawRes)", loop: true)
                }
            }
        }
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Time: [\(renderTimeMs)ms] Drawable", loop: true)
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }
        
        // MARK: Custom
        if let nodeCustom = node as? NODECustom {
            guard let customRenderedTexture = nodeCustom.customRender(drawableTexture, with: commandBuffer) else {
                throw RenderError.nilCustomTexture
            }
            customTexture = customRenderedTexture
        }
        // FIXME: Cleanup. Called in delegate already.
 //        else if node.customRenderActive {
 //            guard let customRenderDeleagte = node as? CustomRenderDelegate else {
 //                throw RenderError.custom("CustomRenderDelegate not set")
 //            }
 //            guard let customRenderedTexture = customRenderDeleagte.customRender(drawableTexture, with: commandBuffer) else {
 //                throw RenderError.nilCustomTexture
 //            }
 //            customTexture = customRenderedTexture
 //        }

        let customRenderActive = node.customRenderActive || node.customMergerRenderActive
        if customRenderActive, let customTexture = customTexture {
            inputTexture = customTexture
        }
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Time: [\(renderTimeMs)ms] Custom", loop: true)
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }

        
        // MARK: Command Encoder
        
        let commandEncoder: MTLCommandEncoder
        if node is NODE3D {
            guard let computeCommandEncoder: MTLComputeCommandEncoder = commandBuffer.makeComputeCommandEncoder() else {
                throw RenderError.commandEncoder
            }
            commandEncoder = computeCommandEncoder
        } else {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawableTexture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: node.clearColor.red, green: node.clearColor.green, blue: node.clearColor.blue, alpha: node.clearColor.alpha)
            guard let renderCommandEncoder: MTLRenderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                throw RenderError.commandEncoder
            }
            commandEncoder = renderCommandEncoder
        }
        
        if let node3d = node as? NODE3D {
            (commandEncoder as! MTLComputeCommandEncoder).setComputePipelineState(node3d.pipeline3d)
        } else {
            if node.pipeline == nil {
                commandEncoder.endEncoding()
                throw RenderError.noPipeline
            }
            (commandEncoder as! MTLRenderCommandEncoder).setRenderPipelineState(node.pipeline)
        }
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Time: [\(renderTimeMs)ms] Command Encoder", loop: true)
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }
        
        
        // MARK: Uniforms
        
        var uniforms: [Float] = []
        if !template {
            uniforms = node.uniforms.map { uniform -> Float in return Float(uniform) }
        }
        if let genNode = node as? NODEGenerator, !template {
            uniforms.append(genNode.premultiply ? 1 : 0)
        }
        if let mergerEffectNode = node as? NODEMergerEffect {
            uniforms.append(Float(mergerEffectNode.placement.index))
        }
        if node.shaderNeedsResolution || template {
            uniforms.append(Float(width))
            uniforms.append(Float(height))
            uniforms.append(Float(width) / Float(height))
        }
        if node is NODEGenerator {
            uniforms.append(tileIndex != nil ? 1 : 0)
            uniforms.append(Float(tileIndex?.x ?? 0))
            uniforms.append(Float(tileIndex?.y ?? 0))
            if node is NODE3D {
                uniforms.append(Float(tileIndex?.z ?? 0))
            }
            uniforms.append(Float(tileCountX))
            uniforms.append(Float(tileCountY))
            if node is NODE3D {
                uniforms.append(Float(tileCountZ))
            }
            uniforms.append(Float(tileFraction))
        }
        if !uniforms.isEmpty {
            let size = MemoryLayout<Float>.size * uniforms.count
            guard let uniformsBuffer = device.makeBuffer(length: size, options: []) else {
                commandEncoder.endEncoding()
                throw RenderError.uniformsBuffer
            }
            let bufferPointer = uniformsBuffer.contents()
            memcpy(bufferPointer, &uniforms, size)
            if node is NODE3D {
                (commandEncoder as! MTLComputeCommandEncoder).setBuffer(uniformsBuffer, offset: 0, index: 0)
            } else {
                (commandEncoder as! MTLRenderCommandEncoder).setFragmentBuffer(uniformsBuffer, offset: 0, index: 0)
            }
        }
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Time: [\(renderTimeMs)ms] Uniforms", loop: true)
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }
        
        
        // MARK: Uniform Arrays

        var uniformArrayInUse = false

        if let mainUniformArray: [[CGFloat]] = node.uniformArray {
            
            /// Hardcoded at 128
            /// Defined as ARRMAX in shaders
            let uniformArrayMaxLimit = node.uniformArrayMaxLimit ?? 128
            
            var uniformArray: [[Float]] = mainUniformArray.map { $0.map({ Float($0) }) }
            
            if !template {
                uniformArrayInUse = true
                
                var uniformArrayActive: [Bool] = uniformArray.map { _ -> Bool in return true }
                
                if uniformArray.count < uniformArrayMaxLimit {
                    let arrayCount: Int = node.uniformArrayLength ?? 1
                    for _ in uniformArray.count..<uniformArrayMaxLimit {
                        var emptyArray: [Float] = []
                        for _ in 0..<arrayCount {
                            emptyArray.append(0.0)
                        }
                        uniformArray.append(emptyArray)
                        uniformArrayActive.append(false)
                    }
                } else if uniformArray.count > uniformArrayMaxLimit {
                    let originalCount = uniformArray.count
                    let overflow = originalCount - uniformArrayMaxLimit
                    for _ in 0..<overflow {
                        uniformArray.removeLast()
                        uniformArrayActive.removeLast()
                    }
                    logger.log(node: node, .warning, .render, "Max limit of uniform arrays exceeded. Last values will be truncated. \(originalCount) / \(uniformArrayMaxLimit)", loop: true)
                }
                
                var uniformFlatMap = uniformArray.flatMap { uniformValues -> [Float] in return uniformValues }
                
                let size: Int = MemoryLayout<Float>.size * uniformFlatMap.count
                guard let uniformsArraysBuffer = device.makeBuffer(length: size, options: []) else {
                    commandEncoder.endEncoding()
                    throw RenderError.uniformsBuffer
                }
                let bufferPointer = uniformsArraysBuffer.contents()
                memcpy(bufferPointer, &uniformFlatMap, size)
                if node is NODE3D {
                    (commandEncoder as! MTLComputeCommandEncoder).setBuffer(uniformsArraysBuffer, offset: 0, index: 1)
                } else {
                    (commandEncoder as! MTLRenderCommandEncoder).setFragmentBuffer(uniformsArraysBuffer, offset: 0, index: 1)
                }
                
                let activeSize: Int = MemoryLayout<Bool>.size * uniformArrayActive.count
                guard let uniformsArraysActiveBuffer = device.makeBuffer(length: activeSize, options: []) else {
                    commandEncoder.endEncoding()
                    throw RenderError.uniformsBuffer
                }
                let activeBufferPointer = uniformsArraysActiveBuffer.contents()
                memcpy(activeBufferPointer, &uniformArrayActive, activeSize)
                if node is NODE3D {
                    (commandEncoder as! MTLComputeCommandEncoder).setBuffer(uniformsArraysActiveBuffer, offset: 0, index: 2)
                } else {
                    (commandEncoder as! MTLRenderCommandEncoder).setFragmentBuffer(uniformsArraysActiveBuffer, offset: 0, index: 2)
                }
                
            }
            
            // Render Time
            if logger.time {
                renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
                renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
                logger.log(node: node, .debug, .metal, "Render Time: [\(renderTimeMs)ms] Uniform Arrays", loop: true)
                localRenderTime = CFAbsoluteTimeGetCurrent()
            }
            
        }
        
        // MARK: Uniform Index Arrays
        
        if let mainUniformIndexArray: [[Int]] = node.uniformIndexArray {
        
            let uniformIndexArrayMaxLimit = node.uniformIndexArrayMaxLimit ?? 128
            
            var uniformIndexArray: [[UInt32]] = mainUniformIndexArray.map({ $0.map({ UInt32($0) }) })
            
            if !uniformIndexArray.isEmpty && !template {
                
                if uniformIndexArray.count < uniformIndexArrayMaxLimit {
                    let arrayCount = uniformIndexArray.first!.count
                    for _ in uniformIndexArray.count..<uniformIndexArrayMaxLimit {
                        let emptyArray = [UInt32].init(repeating: 0, count: arrayCount)
                        uniformIndexArray.append(emptyArray)
                    }
                } else if uniformIndexArray.count > uniformIndexArrayMaxLimit {
                    let originalCount = uniformIndexArray.count
                    let overflow = originalCount - uniformIndexArrayMaxLimit
                    for _ in 0..<overflow {
                        uniformIndexArray.removeLast()
                    }
                    logger.log(node: node, .warning, .render, "Max limit of uniform index arrays exceeded. Last values will be truncated. \(originalCount) / \(uniformIndexArrayMaxLimit)", loop: true)
                }
                
                var uniformFlatMap = uniformIndexArray.flatMap { uniformValues -> [UInt32] in return uniformValues }
                
                let size: Int = MemoryLayout<UInt32>.size * uniformFlatMap.count
                guard let uniformsArraysBuffer = device.makeBuffer(length: size, options: []) else {
                    commandEncoder.endEncoding()
                    throw RenderError.uniformsBuffer
                }
                let bufferPointer = uniformsArraysBuffer.contents()
                memcpy(bufferPointer, &uniformFlatMap, size)
                if node is NODE3D {
                    (commandEncoder as! MTLComputeCommandEncoder).setBuffer(uniformsArraysBuffer, offset: 0, index: uniformArrayInUse ? 3 : 1)
                } else {
                    (commandEncoder as! MTLRenderCommandEncoder).setFragmentBuffer(uniformsArraysBuffer, offset: 0, index: uniformArrayInUse ? 3 : 1)
                }
                
            }
            
            // Render Time
            if logger.time {
                renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
                renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
                logger.log(node: node, .debug, .metal, "Render Time: [\(renderTimeMs)ms] Uniform Index Arrays", loop: true)
                localRenderTime = CFAbsoluteTimeGetCurrent()
            }
            
        }
        
        
        // MARK: Texture
        
        var tex3dIndex = 0
        
        if !generator && !template && !resourceCustom {
            if node is NODE3D {
                (commandEncoder as! MTLComputeCommandEncoder).setTexture(inputTexture!, index: 0)
                tex3dIndex = 1
            } else {
                (commandEncoder as! MTLRenderCommandEncoder).setFragmentTexture(inputTexture!, index: 0)
            }
        }
        
        if secondInputTexture != nil {
            if node is NODE3D {
                (commandEncoder as! MTLComputeCommandEncoder).setTexture(secondInputTexture!, index: 1)
                tex3dIndex = 2
            } else {
                (commandEncoder as! MTLRenderCommandEncoder).setFragmentTexture(secondInputTexture!, index: 1)
            }
        }
        
        if node is NODE3D {
            (commandEncoder as! MTLComputeCommandEncoder).setTexture(drawableTexture, index: tex3dIndex)
        }
        
        // MARK: Sampler
        
        guard node.sampler != nil else {
            commandEncoder.endEncoding()
            throw RenderError.noSampler
        }
        if node is NODE3D {
            (commandEncoder as! MTLComputeCommandEncoder).setSamplerState(node.sampler, index: 0)
        } else {
            (commandEncoder as! MTLRenderCommandEncoder).setFragmentSamplerState(node.sampler, index: 0)
        }
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Time: [\(renderTimeMs)ms] Fragment Texture", loop: true)
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }
        
        
        // MARK: Vertices
        
        let vertices: Vertices
        if node.customGeometryActive {
            guard let customVertices = node.customGeometryDelegate?.customVertices() else {
                commandEncoder.endEncoding()
                throw RenderError.vertices
            }
            vertices = customVertices
        } else {
            vertices = internalDelegate.quadVertecis
        }
        
        if vertices.wireframe {
            if !(node is NODE3D) {
                (commandEncoder as! MTLRenderCommandEncoder).setTriangleFillMode(.lines)
            }
        }

        if !(node is NODE3D) {
            (commandEncoder as! MTLRenderCommandEncoder).setVertexBuffer(vertices.buffer, offset: 0, index: 0)
        }
        
        // MARK: Matrix
        
        if !node.customMatrices.isEmpty {
            var matrices = node.customMatrices
            guard let uniformBuffer = device.makeBuffer(length: MemoryLayout<Float>.size * 16 * matrices.count, options: []) else {
                commandEncoder.endEncoding()
                throw RenderError.uniformsBuffer
            }
            let bufferPointer = uniformBuffer.contents()
            memcpy(bufferPointer, &matrices, MemoryLayout<Float>.size * 16 * matrices.count)
            if !(node is NODE3D) {
                (commandEncoder as! MTLRenderCommandEncoder).setVertexBuffer(uniformBuffer, offset: 0, index: 1)
            }
        }

        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Time: [\(renderTimeMs)ms] Vertices", loop: true)
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }
        
        
        // MARK: Vertex Uniforms
        
        var vertexUniforms: [Float] = node.vertexUniforms.map { uniform -> Float in return Float(uniform) }
        if !vertexUniforms.isEmpty {
            let size = MemoryLayout<Float>.size * vertexUniforms.count
            guard let uniformsBuffer = device.makeBuffer(length: size, options: []) else {
                commandEncoder.endEncoding()
                throw RenderError.uniformsBuffer
            }
            let bufferPointer = uniformsBuffer.contents()
            memcpy(bufferPointer, &vertexUniforms, size)
            if !(node is NODE3D) {
                (commandEncoder as! MTLRenderCommandEncoder).setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
            }
        }
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Time: [\(renderTimeMs)ms] Vertex Uniforms", loop: true)
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }
        
        
        // MARK: Custom Vertex Texture
        
        if node.customVertexTextureActive {
            
            guard let vtxNodeInTexture = node.customVertexNodeIn?.texture else {
                commandEncoder.endEncoding()
                throw RenderError.vertexTexture
            }
            
            if node is NODE3D {
//                (commandEncoder as! MTLComputeCommandEncoder)
            } else {
                (commandEncoder as! MTLRenderCommandEncoder).setVertexTexture(vtxNodeInTexture, index: 0)
            }
            
            if node is NODE3D {
//                (commandEncoder as! MTLComputeCommandEncoder)
            } else {
                let sampler = try internalDelegate.makeSampler(interpolate: .linear, extend: .clampToEdge, mipFilter: .linear, compare: .never)
                (commandEncoder as! MTLRenderCommandEncoder).setVertexSamplerState(sampler, index: 0)
            }
            
        }
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Time: [\(renderTimeMs)ms] Custom Vertex Texture", loop: true)
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }
        
        
        // MARK: Draw
        
        if !(node is NODE3D) {
            if vertices.vertexCount >= 1 {
                (commandEncoder as! MTLRenderCommandEncoder).drawPrimitives(type: vertices.type, vertexStart: 0, vertexCount: vertices.vertexCount, instanceCount: 1)
            }
        }
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Time: [\(renderTimeMs)ms] Draw", loop: true)
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }
        
        
        // MARK: Threads
        
        if node is NODE3D {
//            let max = node3d.pipeline3d.maxTotalThreadsPerThreadgroup
//            let width = node3d.pipeline3d.threadExecutionWidth
//            let w = width
//            let h = max / w
//            let l = 1
//            let threadsPerThreadgroup = MTLSize(width: w, height: h, depth: l)
//            let threadsPerGrid = MTLSize(width: Int(ceil(CGFloat(width) / CGFloat(w))),
//                                         height: Int(ceil(CGFloat(height) / CGFloat(h))),
//                                         depth: Int(ceil(CGFloat(depth) / CGFloat(l))))
            let threadsPerThreadgroup = MTLSize(width: 8, height: 8, depth: 8)
            let threadsPerGrid = MTLSize(width: width, height: height, depth: depth)
            #if !os(tvOS)
            (commandEncoder as! MTLComputeCommandEncoder).dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            #endif
        }
        
        // MARK: Encode
        
        commandEncoder.endEncoding()
        
        if viewDrawable != nil {
            commandBuffer.present(viewDrawable!)
        }
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Time: [\(renderTimeMs)ms] Encode", loop: true)
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - globalRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Time: [\(renderTimeMs)ms] CPU", loop: true)
        }
        
        
        // MARK: Render
        
        commandBuffer.addCompletedHandler({ [weak self, weak node] _ in
            guard let self = self else { return }
            guard let node = node else { return }

            if let error = commandBuffer.error {
                failed(error)
                return
            }
            
            // Render Time
            if self.logger.time {
                
                renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
                renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
                self.logger.log(node: node, .debug, .metal, "Render Time: [\(renderTimeMs)ms] GPU", loop: true)
                
                renderTime = CFAbsoluteTimeGetCurrent() - globalRenderTime
                renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
                self.logger.log(node: node, .debug, .metal, "Render Time: [\(renderTimeMs)ms] CPU + GPU", loop: true)
                
                self.logger.log(node: node, .debug, .metal, "Render Time: Ended", loop: true)
                
            }

            frameLoopRenderThread.call {
                completed(drawableTexture)
            }
        })
        
        commandBuffer.commit()
        if renderInSync {
            commandBuffer.waitUntilCompleted()
        }
        
    }
    
}
