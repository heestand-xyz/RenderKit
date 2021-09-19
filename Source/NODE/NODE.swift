//
//  NODE.swift
//  RenderKit
//
//  Created by Anton Heestand on 2019-10-03.
//

import Metal
import simd
import CoreVideo
import Resolution
import Combine

public protocol NODE: AnyObject, Codable {
    
    var renderObject: Render { get }
    
    var id: UUID { get }
    var typeName: String { get }
    var name: String { get }

    var delegate: NODEDelegate? { get set }
    
    var shaderName: String { get }
    
    var view: NODEView! { get }
    var additionalViews: [NODEView] { get set }
    
    var overrideBits: Bits? { get }
    
    var liveList: [LiveWrap] { get }
    var values: [Floatable] { get }
    var uniforms: [CGFloat] { get }
    var extraUniforms: [CGFloat] { get }
    var uniformArray: [[CGFloat]] { get }
    var uniformArrayMaxLimit: Int? { get }
    var uniformIndexArray: [[Int]] { get }
    var uniformIndexArrayMaxLimit: Int? { get }
    
    var renderInProgress: Bool { get set }
    var renderQueue: [RenderRequest] { get set }
    var renderIndex: Int { get set }
    var bypass: Bool { get set }
    var contentLoaded: Bool? { get set }
    
    var finalResolution: Resolution { get }

    var vertexUniforms: [CGFloat] { get }
    var shaderNeedsResolution: Bool { get }
    
    var pipeline: MTLRenderPipelineState! { get set }
    var sampler: MTLSamplerState! { get set }
    
    var customRenderActive: Bool { get set }
    var customRenderDelegate: CustomRenderDelegate? { get set }
    var customMergerRenderActive: Bool { get set }
    var customMergerRenderDelegate: CustomMergerRenderDelegate? { get set }
    var customGeometryActive: Bool { get set }
    var customGeometryDelegate: CustomGeometryDelegate? { get set }
    var customMetalLibrary: MTLLibrary? { get }
    var customVertexShaderName: String? { get }
    var customVertexTextureActive: Bool { get }
    var customVertexNodeIn: (NODE & NODEOut)? { get }
    var customMatrices: [matrix_float4x4] { get }
//    var customLinkedNodes: [NODE] { get set }
    
    var destroyed: Bool { get set }
    
    var texture: MTLTexture? { get set }
    
    func applyResolution(applied: @escaping () -> ())
    func destroy()
    
    func isEqual(to node: NODE) -> Bool
    
    func addView() -> NODEView
    func removeView(_ view: NODEView)
    
    func render()
    func didRender(renderPack: RenderPack)
    
    func didConnect()
    func didDisconnect()
}

extension NODE {
    
    func contained(in nodes: [NODE]) -> Bool {
        for node in nodes {
            if node.id == self.id {
                return true
            }
        }
        return false
    }
    
}

public struct WeakNODE {
    public weak var node: NODE?
    public init(_ node: NODE) {
        self.node = node
    }
}

// MARK: - 3D

public protocol NODE3D: NODE {
    var renderedResolution3d: Resolution3D { get }
    var finalResolution3d: Resolution3D { get set }
    var pipeline3d: MTLComputePipelineState! { get set }
}

// MARK: - Content

public protocol NODEContent: NODE {}

public protocol NODEResource: NODEContent {
    var resourceTexture: MTLTexture? { get set }
    var resourcePixelBuffer: CVPixelBuffer? { get set }
    func getResourceTexture(commandBuffer: MTLCommandBuffer) throws -> MTLTexture
}

public protocol NODEResourceCustom: NODEContent, NODEResolution3D {}

public protocol NODEGenerator: NODEContent {
    var premultiply: Bool { get set }
}

public protocol NODECustom: NODEContent {
    func customRender(_ texture: MTLTexture, with commandBuffer: MTLCommandBuffer) -> MTLTexture?
}

// MARK: - Effects

public protocol NODEEffect: NODE, NODEInIO, NODEOutIO {
    var renderPromisePublisher: PassthroughSubject<RenderRequest, Never> { get }
    var renderPublisher: PassthroughSubject<RenderPack, Never> { get }
    var cancellableIns: [AnyCancellable] { get set }
}

public protocol NODESingleEffect: NODEEffect {}
public protocol NODEMergerEffect: NODEEffect {
    var placement: Placement { get set }
}
public protocol NODEMultiEffect: NODEEffect {}

// MARK: - Output

public protocol NODEOutput: NODE, NODEInIO {
    var renderPromisePublisher: PassthroughSubject<RenderRequest, Never> { get }
    var renderPublisher: PassthroughSubject<RenderPack, Never> { get }
    var cancellableIns: [AnyCancellable] { get set }
}

// MARK: - Resolution

public protocol NODEResolution {
    var resolution: Resolution { get set }
//    init(at resolution: Resolution)
}

public protocol NODEResolution3D {
    var resolution: Resolution3D { get set }
//    init(at resolution: Resolution3D)
}

// MARK: - Metal

public protocol NODEMetal: AnyObject {
    var metalUniforms: [MetalUniform] { get set }
    var code: String { get set }
    var metalBaseCode: String { get }
    var metalCode: String? { get }
    var metalConsole: String? { get set }
    var metalConsolePublisher: Published<String?>.Publisher { get }
}

// MARK: - Out Path

public struct NODEOutPath {
    public var nodeIn: NODE & NODEIn
    public let inIndex: Int
    public init(nodeIn: NODE & NODEIn, inIndex: Int) {
        self.nodeIn = nodeIn
        self.inIndex = inIndex
    }
}

// MARK: - Tile

public protocol NODETileable {
    func didRenderTiles(force: Bool)
}
public protocol NODETileable2D: NODETileable {
    var tileResolution: Resolution { get }
    var tileTextures: [[MTLTexture]]? { get set }
}
public protocol NODETileable3D: NODETileable {
    var tileResolution: Resolution3D { get }
    var tileTextures: [[[MTLTexture]]]? { get set }
}
