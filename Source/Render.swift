//
//  Render.swift
//  RenderKit
//
//  Created by Anton Heestand on 2019-10-02.
//  Copyright © 2019 Hexagons. All rights reserved.
//

import Foundation
import LiveValues
import CoreGraphics
import MetalKit
import simd

public class Render: EngineInternalDelegate, LoggerDelegate {
    
    public weak var delegate: RenderDelegate?
    
    // MARK: - Version
    
    public var version: String? {
        guard let infos = Bundle(for: Render.self).infoDictionary else { return nil }
        guard let appVersion: String = infos["CFBundleShortVersionString"] as? String else { return nil }
        return appVersion
    }
    
    // MARK: Metal Lib
    
    let metalLibURL: URL
    
    // MARK: Engine
    
    public let engine: Engine
    
    // MARK: - Frame Loop Active
    
    public var frameLoopActive: Bool = true
    
    // MARK: Checker
    
    public var backgroundAlphaCheckerActive: Bool = true
    
    // MARK: Log
    
    public let logger: Logger

    // MARK: Color
    
    public var bits: LiveColor.Bits = ._8
    public var colorSpace: LiveColor.Space = .sRGB
    
    // MARK: Linked NODEs
    
    public var finalNode: NODE?
    
    public var linkedNodes: [NODE] = []
    
    /// Render Time is in Milliseconds
    public var lastRenderTimes: [UUID: Double] = [:]
    
//    struct RenderedNODE {
//        let node: NODE
//        let rendered: Bool
//    }
//    var renderedNodes: [RenderedNODE] = []
//    var allNodeRendered: Bool {
//        for renderedNode in renderedNodes {
//            if !renderedNode.rendered {
//                return false
//            }
//        }
//        return true
//    }
//    var noNodeRendered: Bool {
//        for renderedNode in renderedNodes {
//            if renderedNode.rendered {
//                return false
//            }
//        }
//        return true
//    }

    public func linkIndex(of node: NODE) -> Int? {
        for (i, linkedNode) in linkedNodes.enumerated() {
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
    
    public var frame = 0
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
    public var fpsMax: Int { if #available(iOS 10.3, *) {
        #if os(iOS) || os(tvOS)
        return UIScreen.main.maximumFramesPerSecond
        #elseif os(macOS)
        return 60
        #endif
    } else { return -1 } }
    
    var fpxFirstPreDate: Date?
    var fpxLastPostDate: Date?
    var fpxEmptyFrameCount: Int = 0
    let fpxEmptyFrameCountLimit: Int = 3
    public var fFpx: Double?
    public var fpx: Int? { fFpx != nil ? Int(round(fFpx!)) : nil }
    
    public var linkedNodesRendering: Int { linkedNodes.filter({ $0.inRender }).count }
    public var rendering: Bool { linkedNodesRendering > 0 }
    public var frameCountSinceLastRender: Int?
    
    /// guards the frame loop; waits for all linked nodes to finish rendering
    public var waitForAllRenders: Bool = false

    // MARK: Metal
    
    public var metalDevice: MTLDevice!
    public var commandQueue: MTLCommandQueue!
    public var textureCache: CVMetalTextureCache!
    public var metalLibrary: MTLLibrary!
    var quadVertecis: Vertices!
    var quadVertexShader: MTLFunction!
    
    // MARK: - Life Cycle
    
    public init(metalLibURL: URL) {
        
        self.metalLibURL = metalLibURL
        
        engine = Engine()
        
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
            metalLibrary = try loadMetalShaderLibrary()
            quadVertecis = try makeQuadVertecis()
            quadVertexShader = try loadQuadVertexShader()
        } catch {
            logger.log(.fatal, .pixelKit, "Initialization failed.", e: error)
        }
        
        #if os(iOS) || os(tvOS)
        if [.main, .none].contains(frameLoopRenderThread) {
            displayLink = CADisplayLink(target: self, selector: #selector(self.frameLoop))
            displayLink!.add(to: RunLoop.main, forMode: .common)
        } else {
            let frameTime: Double = 1.0 / Double(self.fpsMax)
            frameLoopRenderThread.timerLoop(duration: frameTime, frameLoop)
        }
        #elseif os(macOS)
//        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
//        let displayLinkOutputCallback: CVDisplayLinkOutputCallback = {
//                (displayLink: CVDisplayLink,
//                inNow: UnsafePointer<CVTimeStamp>,
//                inOutputTime: UnsafePointer<CVTimeStamp>,
//                flagsIn: CVOptionFlags,
//                flagsOut: UnsafeMutablePointer<CVOptionFlags>,
//                displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn in
//            self.frameLoop()
//            return kCVReturnSuccess
//        }
//        CVDisplayLinkSetOutputCallback(displayLink!, displayLinkOutputCallback, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
//        CVDisplayLinkStart(displayLink!)
        let frameTime: Double = 1.0 / Double(self.fpsMax)
        frameLoopRenderThread.timerLoop(duration: frameTime, frameLoop)
//        RunLoop.current.add(Timer(timeInterval: 1.0 / Double(self.fpsMax), repeats: true, block: { _ in
//            print("FRAME LOOP")
//            self.frameLoop()
//        }), forMode: .common)
        #endif
        
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
        frameCountSinceLastRender? += 1
        guard !waitForAllRenders || !rendering else { return }
        preFrameFPX()
        guard frameLoopActive else { return }
        self.delegate?.pixelFrameLoop()
        for frameCallback in self.frameCallbacks {
            frameCallback.callback()
        }
//        self.checkAutoRes()
        self.checkAllLive()
        self.engine.frameLoop()
        self.calcFPS()
    }
    
    // MARK: - FPX
    
    func preFrameFPX() {
        guard frameLoopActive else {
            if fFpx != nil { fFpx = nil }
            return
        }
        if let fpxFromDate: Date = fpxFirstPreDate,
            let fpxToDate: Date = fpxLastPostDate {
            let fpxFrom: Double = fpxFromDate.timeIntervalSinceNow
            let fpxTo: Double = fpxToDate.timeIntervalSinceNow
            let fpxSec: Double = fpxTo - fpxFrom
            fFpx = 1.0 / fpxSec
            fpxEmptyFrameCount = 0
        } else {
            fpxEmptyFrameCount += 1
            if fpxEmptyFrameCount > fpxEmptyFrameCountLimit {
                if fFpx != nil { fFpx = nil }
            }
        }
        fpxFirstPreDate = nil
        fpxLastPostDate = nil
    }
    
    func willRenderFPX() {
        if fpxFirstPreDate == nil {
            fpxFirstPreDate = Date()
        }
    }
    
    func didRenderFPX() {
        fpxLastPostDate = Date()
    }
    
    // MARK: - Check Auto Res
    
//    func checkAutoRes() {
//        for node in linkedNodes {
//            if node.resolution.size.cg != node.view.resSize {
//                logger.log(node: node, .info, .render, "Res Change Detected.")
//                node.applyRes {
//                    node.setNeedsRender()
//                }
//            }
//        }
//    }
    
    // MARK: - Live
    
    func checkAllLive() {
        for linkedNode in linkedNodes {
            linkedNode.checkLive()
        }
    }
    
    func calcFPS() {

        let frameTime = -frameDate.timeIntervalSinceNow
        _fps = Int(round(1.0 / frameTime))
        frameDate = Date()
        frame += 1

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
        frameCallbacks.append((id: id, callback: {
            if callback() == .done {
                self.unlistenToFrames(for: id)
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
        let startFrameIndex = frame
        listenToFramesUntil(callback: {
            if self.frame >= startFrameIndex + frames {
                done()
                return .done
            } else {
                return .continue
            }
        })
    }
    
    // MARK: Flow Timer
    
//    public struct NodeRenderState {
//        public let ref: NODERef
//        public var requested: Bool = false
//        public va´r rendered: Bool = false
//        init(_ node: NODE) {
//            ref = NODERef(for: node)
//        }
//    }
//    public class FlowTime: Equatable {
//        let id: UUID = UUID()
//        public let requestTime: Date = Date()
//        public var startTime: Date!
//        public var renderedFrames: Int = 0
//        public var fromNodeRenderState: NODEodeRenderState
//        public var thoughNodeRenderStates: [NodeRenderState] = []
//        public var toNodeRenderState: NODEodeRenderState
//        public var renderedSeconds: CGFloat!
//        public var endTime: Date!
//        var callback: (FlowTime) -> ()
//        init(from fromNodeRenderState: NODEodeRenderState, to toNodeRenderState: NODEodeRenderState, callback: @escaping (FlowTime) -> ()) {
//            self.fromNodeRenderState = fromNodeRenderState
//            self.toNodeRenderState = toNodeRenderState
//            self.callback = callback
//        }
//        public static func == (lhs: PixelKit.FlowTime, rhs: PixelKit.FlowTime) -> Bool {
//            return lhs.id == rhs.id
//        }
//    }
//
//    var flowTimes: [FlowTime] = []
//
//    public func flowTime(from nodeIn: NODE & NODEOut, to nodeOut: NODE & NODEIn, callback: @escaping (FlowTime) -> ()) {
//        let fromNodeRenderState = NodeRenderState(nodeIn)
//        let toNodeRenderState = NodeRenderState(nodeOut)
//        let flowTime = FlowTime(from: fromNodeRenderState, to: toNodeRenderState) { flowTime in
//            callback(flowTime)
//        }
//        flowTimes.append(flowTime)
//    }
//
//    func unfollowTime(_ flowTime: FlowTime) {
//        for (i, iFlowTime) in flowTimes.enumerated() {
//            if iFlowTime == flowTime {
//                flowTimes.remove(at: i)
//                break
//            }
//        }
//    }
    
    // MARK: - NODE Linking
    
    public func add(node: NODE) {
        linkedNodes.append(node)
    }
    
    public func remove(node: NODE) {
        for (i, linkedNode) in linkedNodes.enumerated() {
            if linkedNode.isEqual(to: node) {
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
    
    func loadMetalShaderLibrary() throws -> MTLLibrary {
        do {
            return try metalDevice.makeLibrary(filepath: metalLibURL.path)
        } catch { throw error }
    }
    
    // MARK: Quad
    
    enum QuadError: Error {
        case runtimeERROR(String)
    }
    
    public func makeQuadVertecis() throws -> Vertices {
        return Vertices(buffer: try makeQuadVertexBuffer(), vertexCount: 6)
    }
    
    public func makeQuadVertexBuffer() throws -> MTLBuffer {
//        #if os(iOS) || os(tvOS)
        let vUp: CGFloat = 0.0
        let vDown: CGFloat = 1.0
//        #elseif os(macOS)
//        let vUp: CGFloat = 1.0
//        let vDown: CGFloat = 0.0
//        #endif
        let a = Vertex(x: -1.0, y: -1.0, z: 0.0, s: 0.0, t: LiveFloat(vDown))
        let b = Vertex(x: 1.0, y: -1.0, z: 0.0, s: 1.0, t: LiveFloat(vDown))
        let c = Vertex(x: -1.0, y: 1.0, z: 0.0, s: 0.0, t: LiveFloat(vUp))
        let d = Vertex(x: 1.0, y: 1.0, z: 0.0, s: 1.0, t: LiveFloat(vUp))
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
        guard let vtxShader = metalLibrary.makeFunction(name: "quadVTX") else {
            throw QuadError.runtimeERROR("Quad Vertex Shader failed to make.")
        }
        return vtxShader
    }
    
    // MARK: Vertex
    
    public func makeVertexShader(_ vertexShaderName: String, with customMetalLibrary: MTLLibrary? = nil) throws -> MTLFunction {
        let lib = (customMetalLibrary ?? metalLibrary)!
        guard let vtxShader = lib.makeFunction(name: vertexShaderName) else {
            throw QuadError.runtimeERROR("Custom Vertex Shader failed to make.")
        }
        return vtxShader
    }
    
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
        case metalErrorError
        case notFound(String)
    }
    
    // MARK: Frag
    
    public func makeFrag(_ shaderName: String, with customMetalLibrary: MTLLibrary? = nil, from node: NODE) throws -> MTLFunction {
        let frag: MTLFunction
        if let metalNode = node as? NODEMetal {
            return try makeMetalFrag(shaderName, from: metalNode)
        } else {
            let lib = (customMetalLibrary ?? metalLibrary)!
            guard let shaderFrag = lib.makeFunction(name: shaderName) else {
                throw ShaderError.notFound(shaderName)
            }
            frag = shaderFrag
        }
        return frag
    }
    
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
    
//    public func shader(url: URL, funcName: String) throws -> MTLFunction {
//        do {
//            #warning("might need to read url and pass in source...")
//            let codeLib = try metalDevice!.makeLibrary(URL: url)
//            guard let frag = codeLib.makeFunction(name: funcName) else {
//                throw ShaderError.metal("makeMetalFrag: Metal func \"\(funcName)\" not found.")
//            }
//            return frag
//        } catch {
//            throw error
//        }
//    }
    
    // MARK: Pipeline
    
    public func makeShaderPipeline(_ fragmentShader: MTLFunction, with customVertexShader: MTLFunction? = nil, addMode: Bool = false, overrideBits: LiveColor.Bits? = nil) throws -> MTLRenderPipelineState {
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
//        guard let bundle: Bundle = bundle else {
//            throw MetalError.fileNotFound("No bundle provided. Can't look for file \"\(fileName).txt\"")
//        }
//        guard let metalFile = bundle.url(forResource: fileName, withExtension: "txt") else {
//            throw MetalError.fileNotFound(fileName + ".txt")
//        }
        do {
            var metalCode = metalBaseCode //try String(contentsOf: metalFile)
            let uniformsCode = try dynamicUniforms(uniforms: uniforms)
            metalCode = try insert(uniformsCode, in: metalCode, at: "uniforms")
            let comment = "/// PixelKit Dynamic Shader Code"
            metalCode = try insert("\(comment)\n\n\n\(code)\n", in: metalCode, at: "code")
            #if DEBUG
            if logger.dynamicShaderCode {
                print("\nDYNAMIC SHADER CODE\n\n>>>>>>>>>>>>>>>>>\n\n\(metalCode)\n<<<<<<<<<<<<<<<<<\n")
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
        frame
    }
    
    public func loggerLinkIndex(of node: NODE) -> Int? {
        linkIndex(of: node)
    }
    
    // MARK: - Engine Internal Delegate
    
    func engineFrameIndex() -> Int {
        frame
    }
    
    func engineLinkIndex(of node: NODE) -> Int? {
        linkIndex(of: node)
    }
    
    func engineDelay(frames: Int, done: @escaping () -> ()) {
        delay(frames: frames, done: done)
    }
    
    func didSetup(node: NODE, success: Bool) {
        if !success {
            lastRenderTimes.removeValue(forKey: node.id)
        }
    }
    
    func willRender(node: NODE) {
        willRenderFPX()
        logger.log(node: node, .info, .render, "NODE Will Render", loop: true)
    }
    
    func didRender(node: NODE, renderTime: Double, success: Bool) {
        if success {
            logger.log(node: node, .info, .render, "NODE Did Render - Success", loop: true)
            lastRenderTimes[node.id] = renderTime
            didRenderFPX()
            frameCountSinceLastRender = 0
        } else {
            logger.log(node: node, .info, .render, "NODE Did Render - Failed", loop: true)
            lastRenderTimes.removeValue(forKey: node.id)
        }
    }
    
}
