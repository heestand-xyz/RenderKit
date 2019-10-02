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

public class Render<N: NODE> {
    
    public weak var delegate: RenderDelegate?
    
    // MARK: Metal Lib
    
    let metalLibName: String
    
    // MARK: Render
    
    public var renderMode: Engine.RenderMode = .frameLoop
    
    // MARK: Manual Render
    
    public var manualRenderDelegate: ManualRenderDelegate?
    
    var manualRenderInProgress: Bool = false
    var manualRenderCallback: (() -> ())?
    
    // MARK: Checker
    
    public var backgroundAlphaCheckerActive: Bool = true
    
    // MARK: Log

    public var metalErrorCodeCallback: ((Engine.MetalErrorCode) -> ())?
    
    // MARK: Color
    
    public var bits: LiveColor.Bits = ._8
    public var colorSpace: LiveColor.Space = .sRGB
    
    // MARK: Linked NODEs
    
    public var finalNode: N?
    
    public var nodeLinks: NODELinks<N> = NODELinks<N>([])
    public var linkedNodes: [N] {
        return nodeLinks.reduce([], { arr, node -> [N] in
            var arr = arr
            if node != nil {
                arr.append(node!)
            }
            return arr
        })
    }
    
    var frameTreeRendering: Bool = false

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

    func linkIndex(of node: N) -> Int? {
        for (i, linkedNode) in nodeLinks.enumerated() {
            guard linkedNode != nil else { continue }
            if linkedNode! == node {
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
    
    var instantQueueActivated: Bool = false
    
    // MARK: Metal
    
    public var metalDevice: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var textureCache: CVMetalTextureCache!
    var metalLibrary: MTLLibrary!
    var quadVertecis: Vertices!
    var quadVertexShader: MTLFunction!
    
    
    // MARK: - Life Cycle
    
    init(with metalLibName: String) {
        
        self.metalLibName = metalLibName
        
        metalDevice = MTLCreateSystemDefaultDevice()
        guard metalDevice != nil else {
            Logger.log(.fatal, .pixelKit, "Metal Device not found.")
            return
        }
        
        commandQueue = metalDevice.makeCommandQueue()
        guard commandQueue != nil else {
            Logger.log(.fatal, .pixelKit, "Command Queue failed to make.")
            return
        }
        
        do {
            textureCache = try makeTextureCache()
            metalLibrary = try loadMetalShaderLibrary()
            quadVertecis = try makeQuadVertecis()
            quadVertexShader = try loadQuadVertexShader()
        } catch {
            Logger.log(.fatal, .pixelKit, "Initialization failed.", e: error)
        }
        
        #if os(iOS) || os(tvOS)
        displayLink = CADisplayLink(target: self, selector: #selector(self.frameLoop))
        displayLink!.add(to: RunLoop.main, forMode: .common)
        #elseif os(macOS)
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        let displayLinkOutputCallback: CVDisplayLinkOutputCallback = { (displayLink: CVDisplayLink,
                                                                        inNow: UnsafePointer<CVTimeStamp>,
                                                                        inOutputTime: UnsafePointer<CVTimeStamp>,
                                                                        flagsIn: CVOptionFlags,
                                                                        flagsOut: UnsafeMutablePointer<CVOptionFlags>,
                                                                        displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn in
            PixelKit.main.frameLoop()
            return kCVReturnSuccess
        }
        CVDisplayLinkSetOutputCallback(displayLink!, displayLinkOutputCallback, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        CVDisplayLinkStart(displayLink!)
        #endif
        
        Logger.log(.info, .pixelKit, "ready to render.", clean: true)
        
    }

    
    // MARK: - Frame Loop
    
    @objc func frameLoop() {
        DispatchQueue.main.async {
            self.delegate?.pixelFrameLoop()
            for frameCallback in self.frameCallbacks {
                frameCallback.callback()
            }
            self.checkAutoRes()
            self.checkAllLive()
            if self.renderMode == .frameTree {
                if !self.frameTreeRendering {
                    self.renderNODEsTree()
                }
            } else if [.frameLoop, .frameLoopQueue].contains(self.renderMode) {
                self.renderNODEs()
            } else if [.instantQueue, .instantQueueSemaphore].contains(self.renderMode) {
                if !self.instantQueueActivated {
                    DispatchQueue.global(qos: .background).async {
                        while true {
                            self.renderNODEs()
                        }
                    }
                    self.instantQueueActivated = true
                }
            } else if self.renderMode == .manual {
                self.checkManualRender()
            }
        }
//        DispatchQueue(label: "pixelKit-frame-loop").async {}
        calcFPS()
    }
    
    // MARK: - Check Auto Res
    
    func checkAutoRes() {
        for node in linkedNodes {
//            Logger.log(node: node, .info, .render, "Res Check: \(node.resolution.size.cg) - \(node.view.resSize)")
            if node.resolution.size.cg != node.view.resSize {
                Logger.log(node: node, .info, .render, "Res Change Detected.")
                node.applyRes {
                    node.setNeedsRender()
                }
            }
        }
    }
    
    // MARK: - Maual Render
    
    enum ManualRenderError: Error {
        case renderInProgress
    }
    
    public func manuallyRender(_ done: @escaping () -> ()) throws {
        guard !manualRenderInProgress else {
            throw ManualRenderError.renderInProgress
        }
        Logger.log(.info, .render, "Manual Render Started.")
        manualRenderInProgress = true
        manualRenderCallback = done
    }
    
    func checkManualRender() {
        
        var someNodesNeedsRender: Bool = false
        for node in linkedNodes {
            if node.needsRender {
                someNodesNeedsRender = true
                break
            }
        }
        
        guard manualRenderInProgress else {
            if someNodesNeedsRender {
                manualRenderDelegate?.pixelNeedsManualRender()
            }
            return
        }
        
        if someNodesNeedsRender {
            
            self.renderNODEs()
            
        } else {
        
            var someNodesAreInRender: Bool = false
            for node in linkedNodes {
                if node.inRender {
                    someNodesAreInRender = true
                    break
                }
            }
            
            if !someNodesAreInRender {

                Logger.log(.info, .render, "Manual Render Done.")
                manualRenderCallback!()
                manualRenderCallback = nil
                manualRenderInProgress = false
                
            }
            
        }
        
    }
    
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
//        public var fromNodeRenderState: NodeRenderState
//        public var thoughNodeRenderStates: [NodeRenderState] = []
//        public var toNodeRenderState: NodeRenderState
//        public var renderedSeconds: CGFloat!
//        public var endTime: Date!
//        var callback: (FlowTime) -> ()
//        init(from fromNodeRenderState: NodeRenderState, to toNodeRenderState: NodeRenderState, callback: @escaping (FlowTime) -> ()) {
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
    
    func add(node: NODE) {
        nodeLinks.append(node)
    }
    
    func remove(node: NODE) {
        nodeLinks.remove(node)
    }
    
    
    // MARK: - Setup
    
    // MARK: Shaders
    
    enum MetalLibraryError: Error {
        case runtimeERROR(String)
    }
    
    func loadMetalShaderLibrary() throws -> MTLLibrary {
        guard let libraryFile = Bundle(for: type(of: self)).path(forResource: metalLibName, ofType: "metallib") else {
            throw MetalLibraryError.runtimeERROR("PixelKit Shaders: Metal Library not found.")
        }
        do {
            return try metalDevice.makeLibrary(filepath: libraryFile)
        } catch { throw error }
    }
    
    // MARK: Quad
    
    enum QuadError: Error {
        case runtimeERROR(String)
    }
    
    public struct Vertex {
        public var x,y,z: LiveFloat
        public var s,t: LiveFloat
        public var buffer: [Float] {
            return [x,y,s,t].map({ v -> Float in return Float(v.uniform) })
        }
        public var buffer3d: [Float] {
            return [x,y,z,s,t].map({ v -> Float in return Float(v.uniform) })
        }
        public init(x: LiveFloat, y: LiveFloat, z: LiveFloat = 0.0, s: LiveFloat, t: LiveFloat) {
            self.x = x; self.y = y; self.z = z; self.s = s; self.t = t
        }
    }
    
    func makeQuadVertecis() throws -> Vertices {
        return Vertices(buffer: try makeQuadVertexBuffer(), vertexCount: 6)
    }
    
    func makeQuadVertexBuffer() throws -> MTLBuffer {
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
    
    func makeVertexShader(_ vertexShaderName: String, with customMetalLibrary: MTLLibrary? = nil) throws -> MTLFunction {
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
    
    func makeTextureCache() throws -> CVMetalTextureCache {
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
    
    enum ShaderError: Error {
        case metal(String)
        case sampler(String)
        case metalCode
        case metalError(Error, MTLFunction)
        case metalErrorError
        case notFound(String)
    }
    
    // MARK: Frag
    
    func makeFrag(_ shaderName: String, with customMetalLibrary: MTLLibrary? = nil, from node: NODE) throws -> MTLFunction {
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
    
    func makeMetalFrag(_ shaderName: String, from metalNode: NODEMetal) throws -> MTLFunction {
        let frag: MTLFunction
        do {
            guard let metalCode = metalNode.metalCode else {
                throw ShaderError.metalCode
            }
            let metalFrag = try makeMetalFrag(code: metalCode, name: shaderName)
            frag = metalFrag
        } catch {
            Logger.log(.error, nil, "Metal code in \"\(shaderName)\".", e: error)
            guard let errorFrag = metalLibrary.makeFunction(name: "error") else {
                throw ShaderError.metalErrorError
            }
            throw ShaderError.metalError(error, errorFrag)
        }
        return frag
    }
    
    // MARK: Metal
    
    func makeMetalFrag(code: String, name: String) throws -> MTLFunction {
        do {
            let codeLib = try metalDevice!.makeLibrary(source: code, options: nil)
            guard let frag = codeLib.makeFunction(name: name) else {
                throw ShaderError.metal("Metal func \"\(name)\" not found.")
            }
            return frag
        } catch {
            throw error
        }
    }
    
    // MARK: Pipeline
    
    func makeShaderPipeline(_ fragmentShader: MTLFunction, with customVertexShader: MTLFunction? = nil, addMode: Bool = false) throws -> MTLRenderPipelineState {
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = customVertexShader ?? quadVertexShader
        pipelineStateDescriptor.fragmentFunction = fragmentShader
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = bits.mtl
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
    
    // MARK: Sampler
    
    func makeSampler(interpolate: MTLSamplerMinMagFilter, extend: MTLSamplerAddressMode, mipFilter: MTLSamplerMipFilter, compare: MTLCompareFunction = .never) throws -> MTLSamplerState {
        let samplerInfo = MTLSamplerDescriptor()
        samplerInfo.minFilter = interpolate
        samplerInfo.magFilter = interpolate
        samplerInfo.sAddressMode = extend
        samplerInfo.tAddressMode = extend
        samplerInfo.compareFunction = compare
        samplerInfo.mipFilter = mipFilter
        guard let sampler = metalDevice.makeSamplerState(descriptor: samplerInfo) else {
            throw ShaderError.sampler("Shader Sampler failed to make.")
        }
        return sampler
    }
    
    
    // MARK: - Raw
    
    func raw8(texture: MTLTexture) -> [UInt8]? {
        guard bits == ._8 else { Logger.log(.error, .pixelKit, "Raw 8 - To access this data, change: \"pixelKit.bits = ._8\"."); return nil }
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        var raw = Array<UInt8>(repeating: 0, count: texture.width * texture.height * 4)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<UInt8>.size * texture.width * 4
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }
        return raw
    }
    
    // CHECK needs testing
    func raw16(texture: MTLTexture) -> [Float]? {
        guard bits == ._16 else { Logger.log(.error, .pixelKit, "Raw 16 - To access this data, change: \"pixelKit.bits = ._16\"."); return nil }
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        var raw = Array<Float>(repeating: 0, count: texture.width * texture.height * 4)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<Float>.size * texture.width * 4
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }
        return raw
    }
    
    // CHECK needs testing
    func raw32(texture: MTLTexture) -> [float4]? {
        guard bits != ._32 else { Logger.log(.error, .pixelKit, "Raw 32 - To access this data, change: \"pixelKit.bits = ._32\"."); return nil }
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        var raw = Array<float4>(repeating: float4(0), count: texture.width * texture.height)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<float4>.size * texture.width
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }
        return raw
    }
    
    func rawNormalized(texture: MTLTexture) -> [CGFloat]? {
        let raw: [CGFloat]
        switch bits {
        case ._8, ._10:
            raw = raw8(texture: texture)!.map({ chan -> CGFloat in return CGFloat(chan) / (pow(2, 8) - 1) })
        case ._16:
            raw = raw16(texture: texture)!.map({ chan -> CGFloat in return CGFloat(chan) }) // CHECK normalize
        case ._32:
            let rawArr = raw32(texture: texture)!
            var rawFlatArr: [CGFloat] = []
            for pixel in rawArr {
                // CHECK normalize
                rawFlatArr.append(CGFloat(pixel.x))
                rawFlatArr.append(CGFloat(pixel.y))
                rawFlatArr.append(CGFloat(pixel.z))
                rawFlatArr.append(CGFloat(pixel.w))
            }
            raw = rawFlatArr
        }
        return raw
    }
    
    
    // MARK: - Metal
    
    enum MetalError: Error {
        case fileNotFound(String)
        case uniform(String)
        case placeholder(String)
    }
    
    func embedMetalCode(uniforms: [MetalUniform], code: String, fileName: String) throws -> String {
        guard let metalFile = Bundle(for: type(of: self)).url(forResource: fileName, withExtension: "txt") else {
            throw MetalError.fileNotFound(fileName)
        }
        do {
            var metalCode = try String(contentsOf: metalFile)
            let uniformsCode = try dynamicUniforms(uniforms: uniforms)
            metalCode = try insert(uniformsCode, in: metalCode, at: "uniforms")
            let comment = "/// PixelKit Dynamic Shader Code"
            metalCode = try insert("\(comment)\n\n\n\(code)\n", in: metalCode, at: "code")
            #if DEBUG
            if logDynamicShaderCode {
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
    
}
