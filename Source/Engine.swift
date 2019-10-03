//
//  PixelKitRender.swift
//  PixelKit
//
//  Created by Hexagons on 2018-08-22.
//  Open Source - MIT License
//

import LiveValues
import CoreGraphics
import Metal

public protocol EngineDelegate {
    func textures(from node: NODE, with commandBuffer: MTLCommandBuffer) throws -> (a: MTLTexture?, b: MTLTexture?, custom: MTLTexture?)
}

protocol EngineInternalDelegate {
    var linkedNodes: [NODE] { get set }
    var commandQueue: MTLCommandQueue! { get set }
    var metalDevice: MTLDevice! { get set }
    var bits: LiveColor.Bits { get set }
    var quadVertecis: Vertices! { get set }
    func makeSampler(interpolate: MTLSamplerMinMagFilter, extend: MTLSamplerAddressMode, mipFilter: MTLSamplerMipFilter, compare: MTLCompareFunction) throws -> MTLSamplerState
}

public class Engine {
    
    var deleagte: EngineDelegate?
    var internalDelegate: EngineInternalDelegate!
    
    public enum RenderMode {
        case manual
        case frameTree
        case frameLoop
        case frameLoopQueue
        case instantQueue
        case instantQueueSemaphore
        case direct
    }
    public var renderMode: Engine.RenderMode = .frameLoop
    
    var frameTreeRendering: Bool = false
    
    let logger: Logger

    public enum MetalErrorCode {
        case IOAF(Int)
        public var info: String {
            switch self {
            case .IOAF(let code):
                return "IOAF code \(code)"
            }
        }
    }
    
    var instantQueueActivated: Bool = false
    
    public var metalErrorCodeCallback: ((Engine.MetalErrorCode) -> ())?
    
    // MARK: Manual Render
    
    public var manualRenderDelegate: ManualRenderDelegate?
    
    var manualRenderInProgress: Bool = false
    var manualRenderCallback: (() -> ())?
    
    // MARK: - Life Cycle
    
    init() {
        self.logger = Logger(name: "RenderKit Engine")
    }
    
    // MARK: - Frame Loop
    
    func frameLoop() {
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
    
    // MARK: - Maual Render
    
    enum ManualRenderError: Error {
        case renderInProgress
    }
    
    public func manuallyRender(_ done: @escaping () -> ()) throws {
        guard !manualRenderInProgress else {
            throw ManualRenderError.renderInProgress
        }
        logger.log(.info, .render, "Manual Render Started.")
        manualRenderInProgress = true
        manualRenderCallback = done
    }
    
    func checkManualRender() {
        
        var someNodesNeedsRender: Bool = false
        for node in internalDelegate.linkedNodes {
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
            for node in internalDelegate.linkedNodes {
                if node.inRender {
                    someNodesAreInRender = true
                    break
                }
            }
            
            if !someNodesAreInRender {

                logger.log(.info, .render, "Manual Render Done.")
                manualRenderCallback!()
                manualRenderCallback = nil
                manualRenderInProgress = false
                
            }
            
        }
        
    }
    
    // MARK: - Render
    
    func renderNODEsTree() {
        let nodesNeedsRender: [NODE] = internalDelegate.linkedNodes.filter { node -> Bool in
            return node.needsRender
        }
        guard !nodesNeedsRender.isEmpty else { return }
        frameTreeRendering = true
        DispatchQueue.global(qos: .background).async {
            self.logger.log(.debug, .render, "-=-=-=-> Tree Started <-=-=-=-")
            var renderedNodes: [NODE] = []
            func render(_ node: NODE) {
                self.logger.log(.debug, .render, "-=-=-=-> Tree Render NODE: \"\(node.name ?? "#")\"")
                let semaphore = DispatchSemaphore(value: 0)
                DispatchQueue.main.async {                
                    if node.view.superview != nil {
                        #if os(iOS) || os(tvOS)
                        node.view.metalView.setNeedsDisplay()
                        #elseif os(macOS)
                        let size = node.resolution.size
//                            logger.log(node: node, .warning, .render, "NODE Resolutuon unknown. Can't render in view.", loop: true)
//                            return
//                        }
                        node.view.metalView.setNeedsDisplay(CGRect(x: 0, y: 0, width: size.width.cg, height: size.height.cg))
                        #endif
                        self.logger.log(node: node, .detail, .render, "View Render requested.", loop: true)
                        guard let currentDrawable: CAMetalDrawable = node.view.metalView.currentDrawable else {
                            self.logger.log(node: node, .error, .render, "Current Drawable not found.")
                            return
                        }
                        node.view.metalView.readyToRender = {
                            node.view.metalView.readyToRender = nil
                            self.renderNODE(node, with: currentDrawable, done: { success in
                                self.logger.log(.debug, .render, "-=-=-=-> View Tree Did Render NODE: \"\(node.name ?? "#")\"")
                                semaphore.signal()
                            })
                        }
                    } else {
                        self.renderNODE(node, done: { success in
                            self.logger.log(.debug, .render, "-=-=-=-> Tree Did Render NODE: \"\(node.name ?? "#")\"")
                            semaphore.signal()
                        })
                    }
                }
                _ = semaphore.wait(timeout: .distantFuture)
                renderedNodes.append(node)
            }
            func reverse(_ inNode: NODE & NODEInIO) {
                self.logger.log(.debug, .render, "-=-=-=-> Tree Reverse NODE: \"\(inNode.name ?? "#")\"")
                for subNode in inNode.nodeInList {
                    if !subNode.contained(in: renderedNodes) {
                        if let subInNode = subNode as? NODE & NODEInIO {
                            reverse(subInNode)
                        }
                        render(subNode)
                    }
                }
            }
            func traverse(_ node: NODE) {
                self.logger.log(.debug, .render, "-=-=-=-> Tree Traverse NODE: \"\(node.name ?? "#")\"")
                if let outNode = node as? NODEOutIO {
                    for inNodePath in outNode.nodeOutPathList {
                        let inNode = inNodePath.nodeIn as! NODE & NODEInIO
                        self.logger.log(.debug, .render, "-=-=-=-> Tree Traverse Sub NODE: \"\(inNode.name ?? "#")\"")
                        var allInsRendered = true
                        for subNode in inNode.nodeInList {
                            if !subNode.contained(in: renderedNodes) {
                                allInsRendered = false
                                break
                            }
                        }
                        if !allInsRendered {
                            reverse(inNode)
                        }
                        if !inNode.contained(in: renderedNodes) {
                            render(inNode)
                            traverse(inNode)
                        }
                    }
                }
            }
            for node in nodesNeedsRender {
                if !node.contained(in: renderedNodes) {
                    render(node)
                    traverse(node)
                }
            }
            self.logger.log(.debug, .render, "-=-=-=-> Tree Ended <-=-=-=-")
            self.frameTreeRendering = false
        }
    }
    
    func renderNODEs() {
        loop: for node in internalDelegate.linkedNodes {
            if node.needsRender {
                
                if [.frameLoopQueue, .instantQueue, .instantQueueSemaphore].contains(renderMode) {
                    guard !node.rendering else {
                        logger.log(node: node, .warning, .render, "Render in progress.", loop: true)
                        continue
                    }
                    if let nodeIn = node as? NODEInIO {
                        for nodeOut in nodeIn.nodeInList {
                            guard node.renderIndex + 1 == nodeOut.renderIndex else {
                                logger.log(node: node, .detail, .render, "Queue In: \(node.renderIndex) + 1 != \(nodeOut.renderIndex)")
                                continue
                            }
//                            log(node: node, .warning, .render, ">>> Queue In: \(node.renderIndex) + 1 == \(nodeOut.renderIndex)")
                        }
                    }
                    if let nodeOut = node as? NODEOutIO {
                        for nodeOutPath in nodeOut.nodeOutPathList {
                            guard node.renderIndex == nodeOutPath.nodeIn.renderIndex else {
                                logger.log(node: node, .detail, .render, "Queue Out: \(node.renderIndex) != \(nodeOutPath.nodeIn.renderIndex)")
                                continue
                            }
//                            log(node: node, .warning, .render, ">>> Queue Out: \(node.renderIndex) == \(nodeOutPath.nodeIn.renderIndex)")
                        }
                    }
                }
                
//                if let nodeIn = node as? NODE & NODEInIO {
//                    let nodeOuts = nodeIn.nodeInList
//                    for (i, nodeOut) in nodeOuts.enumerated() {
//                        if nodeOut.texture == nil {
//                            log(node: node, .warning, .render, "NODE Ins \(i) not rendered.", loop: true)
//                            node.needsRender = false // CHECK
//                            continue loop
//                        }
//                    }
//                }
                
                var semaphore: DispatchSemaphore?
                if renderMode == .instantQueueSemaphore {
                    semaphore = DispatchSemaphore(value: 0)
                }
                
                DispatchQueue.main.async {
//                    #if targetEnvironment(simulator)
//                    let isSimulator = true
//                    #else
//                    let isSimulator = false
//                    #endif
                    if node.view.superview != nil/* && !isSimulator*/ {
                        #if os(iOS) || os(tvOS)
                        node.view.metalView.setNeedsDisplay()
                        #elseif os(macOS)
                        let size = node.resolution.size
//                            logger.log(node: node, .warning, .render, "NODE Resolutuon unknown. Can't render in view.", loop: true)
//                            return
//                        }
                        node.view.metalView.setNeedsDisplay(CGRect(x: 0, y: 0, width: size.width.cg, height: size.height.cg))
                        #endif
                        self.logger.log(node: node, .detail, .render, "View Render requested.", loop: true)
                        let currentDrawable: CAMetalDrawable? = node.view.metalView.currentDrawable
                        if currentDrawable == nil {
                            self.logger.log(node: node, .error, .render, "Current Drawable not found.")
                        }
                        node.view.metalView.readyToRender = {
                            node.view.metalView.readyToRender = nil
                            self.renderNODE(node, with: currentDrawable, done: { success in
                                if self.renderMode == .instantQueueSemaphore {
                                    semaphore!.signal()
                                }
                            })
                        }
                    } else {
                        self.renderNODE(node, done: { success in
                            if self.renderMode == .instantQueueSemaphore {
                                semaphore!.signal()
                            }
                        })
                    }
                }
                
                if self.renderMode == .instantQueueSemaphore {
                    _ = semaphore!.wait(timeout: .distantFuture)
                }
                
            }
        }
    }
    
    func renderNODE(_ node: NODE, with currentDrawable: CAMetalDrawable? = nil, force: Bool = false, done: @escaping (Bool?) -> ()) {
        
        var node = node
        guard !node.bypass || node is NODEGenerator else {
            logger.log(node: node, .info, .render, "Render bypassed.", loop: true)
            done(nil)
            return
        }
        guard !node.rendering else {
            logger.log(node: node, .debug, .render, "Render in progress...", loop: true)
            done(nil)
            return
        }
        node.needsRender = false
        node.inRender = true
//        let queue = DispatchQueue(label: "pixelKit-render", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .never, target: nil)
//        queue.async {
//            DispatchQueue.main.async {
//            }
            let renderStartTime = CFAbsoluteTimeGetCurrent()
//        let renderStartFrame = frame
            logger.log(node: node, .detail, .render, "Starting render.\(force ? " Forced." : "")", loop: true)
//        for flowTime in flowTimes {
//            if flowTime.fromNodeRenderState.ref.id == node.id {
//                if !flowTime.fromNodeRenderState.requested {
//                    flowTime.fromNodeRenderState.requested = true
//                } else {
//
//                }
//            } else {
//
//            }
//        }
            do {
                try self.render(node, with: currentDrawable, force: force, completed: { texture in
                    let renderTime = CFAbsoluteTimeGetCurrent() - renderStartTime
                    let renderTimeMs = CGFloat(Int(round(renderTime * 10_000))) / 10
//                let renderFrames = self.frame - renderStartFrame
                    self.logger.log(node: node, .info, .render, "Rendered! \(force ? "Forced. " : "")[\(renderTimeMs)ms]", loop: true)
//                for flowTime in self.flowTimes {
//                    if flowTime.fromNodeRenderState.requested {
//                        if !flowTime.fromNodeRenderState.rendered {
//                            flowTime.fromNodeRenderState.rendered = true
//                        }
//                    }
//                }
//                    DispatchQueue.main.async {
                        node.inRender = false
                        node.didRender(texture: texture, force: force)
                        done(true)
//                    }
                }, failed: { error in
                    var ioafMsg: String? = nil
                    let err = error.localizedDescription
                    if err.contains("IOAF code") {
                        if let iofaCode = Int(err[err.count - 2..<err.count - 1]) {
                            DispatchQueue.main.async {
                                self.metalErrorCodeCallback?(.IOAF(iofaCode))
                            }
                            ioafMsg = "IOAF code \(iofaCode). Sorry, this is an Metal GPU error, usually seen on older devices."
                        }
                    }
                    self.logger.log(node: node, .error, .render, "Render of shader failed... \(force ? "Forced." : "") \(ioafMsg ?? "")", loop: true, e: error)
//                    DispatchQueue.main.async {
                        node.inRender = false
                        done(false)
//                    }
                })
            } catch {
                logger.log(node: node, .error, .render, "Render setup failed.\(force ? " Forced." : "")", loop: true, e: error)
            }
//        }
    }
    
    enum RenderError: Error {
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
    }
    
    // MARK: - Main Render
    
    func render(_ node: NODE, with currentDrawable: CAMetalDrawable?, force: Bool, completed: @escaping (MTLTexture) -> (), failed: @escaping (Error) -> ()) throws {
        
        var node = node
        
        guard deleagte != nil else {
            logger.log(node: node, .error, .render, "Engine deleagte is not set.")
            throw RenderError.delegateMissing
        }

        // Render Time
        let globalRenderTime = CFAbsoluteTimeGetCurrent()
        var localRenderTime = CFAbsoluteTimeGetCurrent()
        var renderTime: Double = -1
        var renderTimeMs: Double = -1
        logger.log(node: node, .debug, .metal, "Render Timer: Started")

        
        // MARK: Command Buffer
        
        guard let commandBuffer = internalDelegate.commandQueue.makeCommandBuffer() else {
            throw RenderError.commandBuffer
        }
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Timer: [\(renderTimeMs)ms] Command Buffer ")
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }
        
        // MARK: Template
        
        let needsInTexture = node is NODEInIO
        let hasInTexture = needsInTexture && (node as! NODEInIO).nodeInList.first?.texture != nil
        let needsContent = node.contentLoaded != nil
        let hasContent = node.contentLoaded == true
        let needsGenerated = node is NODEGenerator
        let hasGenerated = !node.bypass
        let template = (needsInTexture && !hasInTexture) || (needsContent && !hasContent) || (needsGenerated && !hasGenerated)
        
        
        // MARK: Input Texture
        
        let generator: Bool = node is NODEGenerator
        var (inputTexture, secondInputTexture, customTexture): (MTLTexture?, MTLTexture?, MTLTexture?)
        if !template {
            (inputTexture, secondInputTexture, customTexture) = try deleagte!.textures(from: node, with: commandBuffer)
        }
        
        // MARK: Drawable
        
        let resolution = node.renderResolution
        
        var viewDrawable: CAMetalDrawable? = nil
        let drawableTexture: MTLTexture
        if currentDrawable != nil {
            viewDrawable = currentDrawable!
            drawableTexture = currentDrawable!.texture
        } else if node.texture != nil && resolution == Resolution.custom(w: node.texture!.width, h: node.texture!.height) {
            drawableTexture = node.texture!
        } else {
            drawableTexture = try Texture.emptyTexture(size: resolution.size.cg, bits: internalDelegate.bits, on: internalDelegate.metalDevice)
        }
        
        if logger.highResWarnings {
            let drawRes = Resolution(texture: drawableTexture)
            if (drawRes >= ._16384) != false {
                logger.log(node: node, .detail, .render, "Epic resolution: \(drawRes)")
            } else if (drawRes >= ._8192) != false {
                logger.log(node: node, .detail, .render, "Extreme resolution: \(drawRes)")
            } else if (drawRes >= ._4096) != false {
                logger.log(node: node, .detail, .render, "High resolution: \(drawRes)")
            }
        }
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Timer: [\(renderTimeMs)ms] Drawable ")
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }
        
        // Custom
        
        if let nodeCustom = node as? NODECustom, node.customRenderActive {
            guard let customRenderedTexture = nodeCustom.customRender(drawableTexture, with: commandBuffer) else {
                throw RenderError.nilCustomTexture
            }
            customTexture = customRenderedTexture
        }
        
        let customRenderActive = node.customRenderActive || node.customMergerRenderActive
        if customRenderActive, let customTexture = customTexture {
            inputTexture = customTexture
        }
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Timer: [\(renderTimeMs)ms] Custom ")
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }

        
        // MARK: Command Encoder
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawableTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            throw RenderError.commandEncoder
        }
        commandEncoder.setRenderPipelineState(node.pipeline)
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Timer: [\(renderTimeMs)ms] Command Encoder ")
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }
        
        
        // MARK: Uniforms
        
        var unifroms: [Float] = []
        if !template {
            unifroms = node.uniforms.map { uniform -> Float in return Float(uniform) }
        }
        if let genNode = node as? NODEGenerator, !template {
            unifroms.append(genNode.premultiply ? 1 : 0)
        }
        if let mergerEffectNode = node as? NODEMergerEffect {
            unifroms.append(Float(mergerEffectNode.placement.index))
        }
        if template {
            unifroms.append(Float(resolution.width.cg))
            unifroms.append(Float(resolution.height.cg))
        }
        if node.shaderNeedsAspect || template {
            unifroms.append(Float(resolution.aspect.cg))
        }
        if !unifroms.isEmpty {
            let size = MemoryLayout<Float>.size * unifroms.count
            guard let uniformsBuffer = internalDelegate.metalDevice.makeBuffer(length: size, options: []) else {
                commandEncoder.endEncoding()
                throw RenderError.uniformsBuffer
            }
            let bufferPointer = uniformsBuffer.contents()
            memcpy(bufferPointer, &unifroms, size)
            commandEncoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 0)
        }
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Timer: [\(renderTimeMs)ms] Uniforms ")
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }
        
        
        // MARK: Uniform Arrays
        
        // Hardcoded at 128
        // Defined as ARRMAX in shaders
        let uniformArrayMaxLimit = 128
        
        var uniformArray: [[Float]] = node.uniformArray.map { uniformValues -> [Float] in
            return uniformValues.map({ uniform -> Float in return Float(uniform) })
        }
        
        if !uniformArray.isEmpty && !template {
            
            var uniformArrayActive: [Bool] = uniformArray.map { _ -> Bool in return true }
            
            if uniformArray.count < uniformArrayMaxLimit {
                let arrayCount = uniformArray.first!.count
                for _ in uniformArray.count..<uniformArrayMaxLimit {
                    var emptyArray: [Float] = []
                    for _ in 0..<arrayCount {
                        emptyArray.append(0.0)
                    }
                    uniformArray.append(emptyArray)
                    uniformArrayActive.append(false)
                }
            } else if uniformArray.count > uniformArrayMaxLimit {
                let origialCount = uniformArray.count
                let overflow = origialCount - uniformArrayMaxLimit
                for _ in 0..<overflow {
                    uniformArray.removeLast()
                    uniformArrayActive.removeLast()
                }
                logger.log(node: node, .warning, .render, "Max limit of uniform arrays exceeded. Last values will be truncated. \(origialCount) / \(uniformArrayMaxLimit)")
            }
            
            var uniformFlatMap = uniformArray.flatMap { uniformValues -> [Float] in return uniformValues }
            
            let size: Int = MemoryLayout<Float>.size * uniformFlatMap.count
            guard let uniformsArraysBuffer = internalDelegate.metalDevice.makeBuffer(length: size, options: []) else {
                commandEncoder.endEncoding()
                throw RenderError.uniformsBuffer
            }
            let bufferPointer = uniformsArraysBuffer.contents()
            memcpy(bufferPointer, &uniformFlatMap, size)
            commandEncoder.setFragmentBuffer(uniformsArraysBuffer, offset: 0, index: 1)
            
            let activeSize: Int = MemoryLayout<Bool>.size * uniformArrayActive.count
            guard let uniformsArraysActiveBuffer = internalDelegate.metalDevice.makeBuffer(length: activeSize, options: []) else {
                commandEncoder.endEncoding()
                throw RenderError.uniformsBuffer
            }
            let activeBufferPointer = uniformsArraysActiveBuffer.contents()
            memcpy(activeBufferPointer, &uniformArrayActive, activeSize)
            commandEncoder.setFragmentBuffer(uniformsArraysActiveBuffer, offset: 0, index: 2)
            
        }
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Timer: [\(renderTimeMs)ms] Uniform Arrays ")
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }
        
        
        // MARK: Fragment Texture
        
        if !generator && !template {
            commandEncoder.setFragmentTexture(inputTexture!, index: 0)
        }
        
        if secondInputTexture != nil {
            commandEncoder.setFragmentTexture(secondInputTexture!, index: 1)
        }
        
        commandEncoder.setFragmentSamplerState(node.sampler, index: 0)
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Timer: [\(renderTimeMs)ms] Fragment Texture ")
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
            commandEncoder.setTriangleFillMode(.lines)
        }

        commandEncoder.setVertexBuffer(vertices.buffer, offset: 0, index: 0)
        
        // MARK: Matrix
        
        if !node.customMatrices.isEmpty {
            var matrices = node.customMatrices
            guard let uniformBuffer = internalDelegate.metalDevice.makeBuffer(length: MemoryLayout<Float>.size * 16 * matrices.count, options: []) else {
                commandEncoder.endEncoding()
                throw RenderError.uniformsBuffer
            }
            let bufferPointer = uniformBuffer.contents()
            memcpy(bufferPointer, &matrices, MemoryLayout<Float>.size * 16 * matrices.count)
            commandEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        }

        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Timer: [\(renderTimeMs)ms] Vertices ")
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }
        
        
        // MARK: Vertex Uniforms
        
        var vertexUnifroms: [Float] = node.vertexUniforms.map { uniform -> Float in return Float(uniform) }
        if !vertexUnifroms.isEmpty {
            let size = MemoryLayout<Float>.size * vertexUnifroms.count
            guard let uniformsBuffer = internalDelegate.metalDevice.makeBuffer(length: size, options: []) else {
                commandEncoder.endEncoding()
                throw RenderError.uniformsBuffer
            }
            let bufferPointer = uniformsBuffer.contents()
            memcpy(bufferPointer, &vertexUnifroms, size)
            commandEncoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
        }
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Timer: [\(renderTimeMs)ms] Vertex Uniforms ")
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }
        
        
        // MARK: Custom Vertex Texture
        
        if node.customVertexTextureActive {
            
            guard let vtxNodeInTexture = node.customVertexNodeIn?.texture else {
                commandEncoder.endEncoding()
                throw RenderError.vertexTexture
            }
            
            commandEncoder.setVertexTexture(vtxNodeInTexture, index: 0)
            
            let sampler = try internalDelegate.makeSampler(interpolate: .linear, extend: .clampToEdge, mipFilter: .linear, compare: .never)
            commandEncoder.setVertexSamplerState(sampler, index: 0)
            
        }
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Timer: [\(renderTimeMs)ms] Custom Vertex Texture ")
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }
        
        
        // MARK: Draw
        
        commandEncoder.drawPrimitives(type: vertices.type, vertexStart: 0, vertexCount: vertices.vertexCount, instanceCount: 1)
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Timer: [\(renderTimeMs)ms] Draw ")
            localRenderTime = CFAbsoluteTimeGetCurrent()
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
            logger.log(node: node, .debug, .metal, "Render Timer: [\(renderTimeMs)ms] Encode ")
            localRenderTime = CFAbsoluteTimeGetCurrent()
        }
        
        // Render Time
        if logger.time {
            renderTime = CFAbsoluteTimeGetCurrent() - globalRenderTime
            renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
            logger.log(node: node, .debug, .metal, "Render Timer: [\(renderTimeMs)ms] CPU ")
        }
        
        
        // MARK: Render
        
        node.rendering = true
        
//        if #available(iOS 11.0, *) {
//            let sharedCaptureManager = MTLCaptureManager.shared()
//            let myCaptureScope = sharedCaptureManager.makeCaptureScope(device: metalDevice)
//            myCaptureScope.label = "PixelKit GPU Capture Scope"
//            sharedCaptureManager.defaultCaptureScope = myCaptureScope
//            myCaptureScope.begin()
//        }
        
        commandBuffer.addCompletedHandler({ _ in
            node.rendering = false
            if let error = commandBuffer.error {
                failed(error)
                return
            }
            
            // Render Time
            if self.logger.time {
                
                renderTime = CFAbsoluteTimeGetCurrent() - localRenderTime
                renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
                self.logger.log(node: node, .debug, .metal, "Render Timer: [\(renderTimeMs)ms] GPU ")
                
                renderTime = CFAbsoluteTimeGetCurrent() - globalRenderTime
                renderTimeMs = Double(Int(round(renderTime * 1_000_000))) / 1_000
                self.logger.log(node: node, .debug, .metal, "Render Timer: [\(renderTimeMs)ms] CPU + GPU ")
                
                self.logger.log(node: node, .debug, .metal, "Render Timer: Ended")
                
            }

            DispatchQueue.main.async {
                completed(drawableTexture)
            }
        })
        
        commandBuffer.commit()
    
//        if #available(iOS 11.0, *) {
//            let sharedCaptureManager = MTLCaptureManager.shared()
//            guard !sharedCaptureManager.isCapturing else { fatalError() }
//            sharedCaptureManager.defaultCaptureScope?.end()
//        }
        
    }
    
}
