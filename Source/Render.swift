//
//  Render.swift
//  RenderKit
//
//  Created by Anton Heestand on 2019-10-02.
//

import Foundation
import CoreGraphics
import MetalKit
import simd

public class Render: EngineInternalDelegate, LoggerDelegate {
    
//    public weak var delegate: RenderDelegate?
    
    // MARK: - Version
    
    public var version: String? {
        guard let infos = Bundle(for: Render.self).infoDictionary else { return nil }
        guard let appVersion: String = infos["CFBundleShortVersionString"] as? String else { return nil }
        return appVersion
    }
    
    // MARK: Metal Lib
    
//    let metalLibURL: URL
    
    // MARK: Engine
    
    public let engine: Engine
    
    // MARK: Queuer
    
    public let queuer: Queuer
    
    // MARK: - Frame Loop Active
    
    public var frameLoopActive: Bool = true
    
    // MARK: Checker
    
    public var backgroundAlphaCheckerActive: Bool = true
    
    // MARK: Log
    
    public let logger: Logger

    // MARK: Color
    
    public var bits: Bits = ._8
    public var colorSpace: CGColorSpace = CGColorSpace(name: CGColorSpace.displayP3)!
    
    // MARK: Linked NODEs
    
    public var finalNode: NODE?
    
    public var linkedNodes: [WeakNODE] = []
    
    /// Render Time is in Milliseconds
    public var lastRenderTimes: [UUID: Double] = [:]

    public func linkIndex(of node: NODE) -> Int? {
        for (i, linkedNode) in linkedNodes.compactMap(\.node).enumerated() {
            if linkedNode.isEqual(to: node) {
                return i
            }
        }
        return nil
    }
    
    // MARK: Frames
    
    #if os(iOS) || os(tvOS)
    typealias _DisplayLink = CADisplayLink
    #elseif os(macOS)
    typealias _DisplayLink = CVDisplayLink
    #endif
    var displayLink: _DisplayLink?
    
    var frameCallbacks: [(id: UUID, callback: () -> ())] = []
    
    public var frameIndex = 0
    public var finalFrame = 0
    let startDate = Date()
    var frameDate = Date()
    var finalFrameDate: Date?
    public var seconds: CGFloat {
        return CGFloat(-startDate.timeIntervalSinceNow)
    }

    var _fps: Int = -1
    public var fps: Int { return min(_fps, fpsMax) }
    var _finalFps: Int = -1
    public var finalFps: Int? { return finalNode != nil && _finalFps != -1 ? min(_finalFps, fpsMax) : nil }
    public var fpsMax: Int {
        #if os(macOS)
        let id = CGMainDisplayID()
        guard let display = CGDisplayCopyDisplayMode(id) else { return 60 }
        return Int(display.refreshRate)
        #else
        return Int(UIScreen.main.maximumFramesPerSecond)
        #endif
    }
    public var secondsPerFrame: Double {
        1.0 / Double(fps)
    }
    public var maxSecondsPerFrame: Double {
        1.0 / Double(fpsMax)
    }
    
    var fpxFirstPreDate: Date?
    var fpxLastPostDate: Date?
    var fpxEmptyFrameCount: Int = 0
    let fpxEmptyFrameCountLimit: Int = 3
    public var fFpx: Double?
    public var fpx: Int? { fFpx != nil ? Int(round(fFpx!)) : nil }
    
//    public var linkedNodesRendering: Int { linkedNodes.filter({ $0.renderInProgress }).count }
//    public var rendering: Bool { linkedNodesRendering > 0 }
//    public var frameCountSinceLastRender: Int?
    
    /// guards the frame loop; waits for all linked nodes to finish rendering
//    public var waitForAllRenders: Bool = false

    // MARK: Metal
    
    public var metalDevice: MTLDevice!
    public var commandQueue: MTLCommandQueue!
    public var textureCache: CVMetalTextureCache!
//    public var metalLibrary: MTLLibrary!
    var quadVertecis: Vertices!
    var quadVertexShader: MTLFunction!
    
    // MARK: - Life Cycle
    
    public init(/*metalLibURL: URL*/) {
        
//        self.metalLibURL = metalLibURL
        
        engine = Engine()
        queuer = Queuer()
        logger = Logger(name: "RenderKit")
        
        engine.internalDelegate = self
        logger.delegate = self
        
        metalDevice = MTLCreateSystemDefaultDevice()
        guard metalDevice != nil else {
            logger.log(.fatal, .pixelKit, "Metal Device not found.")
            return
        }
        
        commandQueue = metalDevice.makeCommandQueue()
        guard commandQueue != nil else {
            logger.log(.fatal, .pixelKit, "Command Queue failed to make.")
            return
        }
        
        do {
            textureCache = try makeTextureCache()
//            metalLibrary = try loadMetalShaderLibrary()
            quadVertecis = try makeQuadVertecis()
            quadVertexShader = try loadQuadVertexShader()
        } catch {
            logger.log(.fatal, .pixelKit, "Initialization failed.", e: error)
        }
        
        #if os(iOS) || os(tvOS)
        if [.main, .none].contains(frameLoopRenderThread) {
            displayLink = CADisplayLink(target: self, selector: #selector(self.frameLoop))
            if #available(iOS 15.0, tvOS 15.0, *) {
                displayLink!.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 120, preferred: 120)
            }
            displayLink!.add(to: RunLoop.main, forMode: .common)
        } else {
            let frameTime: Double = 1.0 / Double(self.fpsMax)
            frameLoopRenderThread.timerLoop(duration: frameTime, frameLoop)
        }
        #elseif os(macOS)
        let frameTime: Double = 1.0 / Double(self.fpsMax)
        frameLoopRenderThread.timerLoop(duration: frameTime, frameLoop)
        #endif
        
        queuer.delegate = self
        
        logger.log(.info, .pixelKit, "ready to render.", clean: true)
        
    }
    
    // MARK: - Frame Loop
    
    @objc func frameLoop() {
        frameLoopRenderThread.call(doFrameLoop)
    }
    
    /// Force a Frame Loop Render when `frameLoopActive` is `false`.
    public func forceOneFrameLoop() {
        frameLoopRenderThread.call(doFrameLoop)
    }
    
    func doFrameLoop() {
//        frameCountSinceLastRender? += 1
//        guard !waitForAllRenders || !rendering else { return }
//        preFrameFPX()
        guard frameLoopActive else { return }
//        self.delegate?.pixelFrameLoop()
        queuer.frameLoop()
        for frameCallback in self.frameCallbacks {
            frameCallback.callback()
        }
//        self.engine.frameLoop()
        self.calcFPS()
    }
    
    // MARK: - FPX
    
//    func preFrameFPX() {
//        guard frameLoopActive else {
//            if fFpx != nil { fFpx = nil }
//            return
//        }
//        if let fpxFromDate: Date = fpxFirstPreDate,
//            let fpxToDate: Date = fpxLastPostDate {
//            let fpxFrom: Double = fpxFromDate.timeIntervalSinceNow
//            let fpxTo: Double = fpxToDate.timeIntervalSinceNow
//            let fpxSec: Double = fpxTo - fpxFrom
//            fFpx = 1.0 / fpxSec
//            fpxEmptyFrameCount = 0
//        } else {
//            fpxEmptyFrameCount += 1
//            if fpxEmptyFrameCount > fpxEmptyFrameCountLimit {
//                if fFpx != nil { fFpx = nil }
//            }
//        }
//        fpxFirstPreDate = nil
//        fpxLastPostDate = nil
//    }
//
//    func willRenderFPX() {
//        if fpxFirstPreDate == nil {
//            fpxFirstPreDate = Date()
//        }
//    }
//
//    func didRenderFPX() {
//        fpxLastPostDate = Date()
//    }
    
    // MARK: - Live
    
    func calcFPS() {

        let frameTime = -frameDate.timeIntervalSinceNow
        _fps = Int(round(1.0 / frameTime))
        frameDate = Date()
        frameIndex += 1

        if let finalFrameDate = finalFrameDate {
            let finalFrameTime = -finalFrameDate.timeIntervalSinceNow
            _finalFps = Int(round(1.0 / finalFrameTime))
        }
        let finalFrame = finalNode?.renderIndex ?? 0
        if finalFrame != self.finalFrame {
            finalFrameDate = Date()
        }
        self.finalFrame = finalFrame
        
    }
    
    public enum ListenState {
        case `continue`
        case done
    }

    public func listenToFramesUntil(callback: @escaping () -> (ListenState)) {
        let id = UUID()
        frameCallbacks.append((id: id, callback: { [weak self] in
            if callback() == .done {
                self?.unlistenToFrames(for: id)
            }
        }))
    }

    public func listenToFrames(id: UUID, callback: @escaping () -> ()) {
        frameCallbacks.append((id: id, callback: {
            callback()
        }))
    }

    public func listenToFrames(callback: @escaping () -> ()) {
        frameCallbacks.append((id: UUID(), callback: {
            callback()
        }))
    }

    public func unlistenToFrames(for id: UUID) {
        for (i, frameCallback) in self.frameCallbacks.enumerated() {
            if frameCallback.id == id {
                frameCallbacks.remove(at: i)
                break
            }
        }
    }
    
    public func delay(frames: Int, done: @escaping () -> ()) {
        let startFrameIndex = frameIndex
        listenToFramesUntil(callback: { [weak self] in
            guard let self = self else { return .done }
            if self.frameIndex >= startFrameIndex + frames {
                done()
                return .done
            } else {
                return .continue
            }
        })
    }
    
    // MARK: - NODE Linking
    
    public func add(node: NODE) {
        logger.log(node: node, .detail, .connection, "Linked Node \"\(node.name)\"")
        linkedNodes.append(WeakNODE(node))
    }
    
    public func remove(node: NODE) {
        for (i, linkedNode) in linkedNodes.map(\.node).enumerated() {
            if linkedNode?.isEqual(to: node) == true {
                lastRenderTimes.removeValue(forKey: node.id)
                linkedNodes.remove(at: i)
                break
            }
        }
    }
    
    
    // MARK: - Setup
    
    // MARK: Shaders
    
    enum MetalLibraryError: Error {
        case runtimeERROR(String)
    }
    
//    func loadMetalShaderLibrary() throws -> MTLLibrary {
//        do {
//            return try metalDevice.makeLibrary(filepath: metalLibURL.path)
//        } catch { throw error }
//    }
    
    // MARK: Quad
    
    enum QuadError: Error {
        case runtimeERROR(String)
    }
    
    public func makeQuadVertecis() throws -> Vertices {
        return Vertices(buffer: try makeQuadVertexBuffer(), vertexCount: 6)
    }
    
    public func makeQuadVertexBuffer() throws -> MTLBuffer {
        let vUp: CGFloat = 0.0
        let vDown: CGFloat = 1.0
        let a = Vertex(x: -1.0, y: -1.0, z: 0.0, s: 0.0, t: CGFloat(vDown))
        let b = Vertex(x: 1.0, y: -1.0, z: 0.0, s: 1.0, t: CGFloat(vDown))
        let c = Vertex(x: -1.0, y: 1.0, z: 0.0, s: 0.0, t: CGFloat(vUp))
        let d = Vertex(x: 1.0, y: 1.0, z: 0.0, s: 1.0, t: CGFloat(vUp))
        let verticesArray: Array<Vertex> = [a,b,c,b,c,d]
        var vertexData = Array<Float>()
        for vertex in verticesArray {
            vertexData += vertex.buffer
        }
        let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
        guard let buffer = metalDevice.makeBuffer(bytes: vertexData, length: dataSize, options: []) else {
            throw QuadError.runtimeERROR("Quad Buffer failed to create.")
        }
        return buffer
    }
    
    func loadQuadVertexShader() throws -> MTLFunction {
        let metalLibrary: MTLLibrary = try metalDevice.makeDefaultLibrary(bundle: Bundle.module)
        guard let vtxShader = metalLibrary.makeFunction(name: "quadVTX") else {
            throw QuadError.runtimeERROR("Quad Vertex Shader failed to make.")
        }
        return vtxShader
    }
    
    // MARK: Vertex
    
//    public func makeVertexShader(_ vertexShaderName: String, with customMetalLibrary: MTLLibrary? = nil) throws -> MTLFunction {
//        let lib = (customMetalLibrary ?? metalLibrary)!
//        guard let vtxShader = lib.makeFunction(name: vertexShaderName) else {
//            throw QuadError.runtimeERROR("Custom Vertex Shader failed to make.")
//        }
//        return vtxShader
//    }
    
    // MARK: Cache
    
    enum CacheError: Error {
        case runtimeERROR(String)
    }
    
    public func makeTextureCache() throws -> CVMetalTextureCache {
        var textureCache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &textureCache) != kCVReturnSuccess {
            throw CacheError.runtimeERROR("Texture Cache failed to create.")
        } else {
            guard let tc = textureCache else {
                throw CacheError.runtimeERROR("Texture Cache is nil.")
            }
            return tc
        }
    }
    
    
    // MARK: - Shader
    
    public enum ShaderError: Error {
        case metal(String)
        case sampler(String)
        case metalCode
        case metalError(Error, MTLFunction)
        case metalLibraryError
        case metalErrorError
        case notFound(String)
    }
    
    // MARK: Frag
    
//    public func makeFrag(_ shaderName: String, with customMetalLibrary: MTLLibrary? = nil, from node: NODE) throws -> MTLFunction {
//        let frag: MTLFunction
//        if let metalNode = node as? NODEMetal {
//            return try makeMetalFrag(shaderName, from: metalNode)
//        } else {
//            let lib = (customMetalLibrary ?? metalLibrary)!
//            guard let shaderFrag = lib.makeFunction(name: shaderName) else {
//                throw ShaderError.notFound(shaderName)
//            }
//            frag = shaderFrag
//        }
//        return frag
//    }
    
    public func makeMetalFrag(_ shaderName: String, from metalNode: NODEMetal) throws -> MTLFunction {
        let frag: MTLFunction
        do {
            guard let metalCode = metalNode.metalCode else {
                throw ShaderError.metalCode
            }
            let metalFrag = try shader(code: metalCode, funcName: shaderName)
            frag = metalFrag
        } catch {
            logger.log(.error, nil, "Metal error in \"\(shaderName)\".", e: error)
            guard let metalLibrary: MTLLibrary = try? metalDevice.makeDefaultLibrary(bundle: Bundle.module) else {
                throw ShaderError.metalLibraryError
            }
            guard let errorFrag = metalLibrary.makeFunction(name: "error") else {
                throw ShaderError.metalErrorError
            }
            throw ShaderError.metalError(error, errorFrag)
        }
        return frag
    }
    
    // MARK: Metal
    
    @available(*, deprecated, renamed: "shader(code:funcName:)")
    public func makeMetalFrag(code: String, name: String) throws -> MTLFunction {
        try shader(code: code, funcName: name)
    }
    public func shader(code: String, funcName: String) throws -> MTLFunction {
        do {
            let codeLib = try metalDevice!.makeLibrary(source: code, options: nil)
            guard let frag = codeLib.makeFunction(name: funcName) else {
                throw ShaderError.metal("makeMetalFrag: Metal func \"\(funcName)\" not found.")
            }
            return frag
        } catch {
            throw error
        }
    }
    
    // MARK: Pipeline
    
    public func makeShaderPipeline(_ fragmentShader: MTLFunction, with customVertexShader: MTLFunction? = nil, addMode: Bool = false, overrideBits: Bits? = nil) throws -> MTLRenderPipelineState {
        logger.log(.detail, .fileIO, "Pipeline - Fragment Shader: \(fragmentShader.name)")
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = customVertexShader ?? quadVertexShader
        pipelineStateDescriptor.fragmentFunction = fragmentShader
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = (overrideBits ?? bits).pixelFormat
        pipelineStateDescriptor.colorAttachments[0].isBlendingEnabled = true
        if addMode {
            pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
            pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
            pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = .add
        } else {
            pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = .blendAlpha
        }
        do {
            return try metalDevice.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        } catch { throw error }
    }
    
    public func makeShaderPipeline3d(_ computeShader: MTLFunction) throws -> MTLComputePipelineState {
        logger.log(.detail, .fileIO, "Pipeline 3D - Compute Shader: \(computeShader.name)")
        do {
            return try metalDevice.makeComputePipelineState(function: computeShader)
        } catch { throw error }
    }
    
    // MARK: Sampler
    
    public func makeSampler(interpolate: MTLSamplerMinMagFilter, extend: MTLSamplerAddressMode, mipFilter: MTLSamplerMipFilter, compare: MTLCompareFunction = .never) throws -> MTLSamplerState {
        let samplerInfo = MTLSamplerDescriptor()
        samplerInfo.minFilter = interpolate
        samplerInfo.magFilter = interpolate
        samplerInfo.sAddressMode = extend
        samplerInfo.tAddressMode = extend
        samplerInfo.rAddressMode = extend
        samplerInfo.compareFunction = compare
        samplerInfo.mipFilter = mipFilter
        guard let sampler = metalDevice.makeSamplerState(descriptor: samplerInfo) else {
            throw ShaderError.sampler("Shader Sampler failed to make.")
        }
        return sampler
    }
    
    // MARK: - Metal
    
    enum MetalError: Error {
        case fileNotFound(String)
        case uniform(String)
        case placeholder(String)
    }
    
    public func embedMetalCode(uniforms: [MetalUniform], code: String, metalBaseCode: String) throws -> String {
        do {
            var metalCode: String = metalBaseCode
            let uniformsCode: String = try dynamicUniforms(uniforms: uniforms)
            metalCode = try insert(uniformsCode, in: metalCode, at: "uniforms")
            let comment: String = "/// PixelKit Dynamic Shader Code"
            metalCode = try insert("\(comment)\n\n\n\(code)\n", in: metalCode, at: "code")
            #if DEBUG
            if logger.dynamicShaderCode {
                print("\nDynamic Shader Code:\n\n\(metalCode)\n\n")
            }
            #endif
            return metalCode
        } catch {
            throw error
        }
    }
    
    public func embedMetalColorCode(uniforms: [MetalUniform],
                                    whiteCode: String,
                                    redCode: String,
                                    greenCode: String,
                                    blueCode: String,
                                    alphaCode: String,
                                    metalBaseCode: String) throws -> String {
        do {
            var metalCode: String = metalBaseCode
            let uniformsCode: String = try dynamicUniforms(uniforms: uniforms)
            metalCode = try insert(uniformsCode, in: metalCode, at: "uniforms")
            let comment: String = "/// PixelKit Dynamic Shader Code"
            metalCode = try insert("\(comment)\n\n\n\(whiteCode)\n", in: metalCode, at: "white")
            metalCode = try insert("\(comment)\n\n\n\(redCode)\n", in: metalCode, at: "red")
            metalCode = try insert("\(comment)\n\n\n\(greenCode)\n", in: metalCode, at: "green")
            metalCode = try insert("\(comment)\n\n\n\(blueCode)\n", in: metalCode, at: "blue")
            metalCode = try insert("\(comment)\n\n\n\(alphaCode)\n", in: metalCode, at: "alpha")
            #if DEBUG
            if logger.dynamicShaderCode {
                print("\nDynamic Shader Code:\n\n\(metalCode)\n\n")
            }
            #endif
            return metalCode
        } catch {
            throw error
        }
    }
    
    func dynamicUniforms(uniforms: [MetalUniform]) throws -> String {
        var code = ""
        for (i, uniform) in uniforms.enumerated() {
            guard uniform.name.range(of: " ") == nil else {
                throw MetalError.uniform("Uniform \"\(uniform.name)\" can not contain a spaces.")
            }
            if i > 0 {
                code += "\t"
            }
            code += "float \(uniform.name);"
            if i < uniforms.count - 1 {
                code += "\n"
            }
        }
        return code
    }
    
    func insert(_ snippet: String, in code: String, at placeholder: String) throws -> String {
        let placeholderComment = "/*<\(placeholder)>*/"
        guard code.range(of: placeholderComment) != nil else {
            throw MetalError.placeholder("Placeholder <\(placeholder)> not found.")
        }
        return code.replacingOccurrences(of: placeholderComment, with: snippet)
    }
    
    // MARK: - Logger Delegate
    
    public func loggerFrameIndex() -> Int {
        frameIndex
    }
    
    public func loggerLinkIndex(of node: NODE) -> Int? {
        linkIndex(of: node)
    }
    
    // MARK: - Engine Internal Delegate
    
    func engineFrameIndex() -> Int {
        frameIndex
    }
    
    func engineLinkIndex(of node: NODE) -> Int? {
        linkIndex(of: node)
    }
    
//    func engineDelay(frames: Int, done: @escaping () -> ()) {
//        delay(frames: frames, done: done)
//    }
    
    func didSetup(node: NODE, success: Bool) {
        if !success {
            lastRenderTimes.removeValue(forKey: node.id)
        }
    }
    
    func willRender(node: NODE) {
//        willRenderFPX()
        logger.log(node: node, .info, .render, "NODE Will Render", loop: true)
    }
    
    func didRender(node: NODE, renderTime: Double, success: Bool) {
        if success {
            logger.log(node: node, .info, .render, "NODE Did Render - Success", loop: true)
            lastRenderTimes[node.id] = renderTime
//            didRenderFPX()
//            frameCountSinceLastRender = 0
        } else {
            logger.log(node: node, .info, .render, "NODE Did Render - Failed", loop: true)
            lastRenderTimes.removeValue(forKey: node.id)
        }
    }
    
}

extension Render: QueuerDelegate {
    func queuerNode(id: UUID) -> NODE? {
        linkedNodes.compactMap(\.node).first { node in
            node.id == id
        }
    }
    
    
}
