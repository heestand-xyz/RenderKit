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

public protocol NODE: Codable {
    
    var id: UUID { get }
    var typeName: String { get }
    var name: String { get }

    var delegate: NODEDelegate? { get set }
    
    var shaderName: String { get }
    
    var view: NODEView { get }
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
    var renderIndex: Int { get set }
    var bypass: Bool { get set }
    var contentLoaded: Bool? { get set }
    
    var finalResolution: Resolution { get }

    var vertexUniforms: [CGFloat] { get }
    var shaderNeedsAspect: Bool { get }
    
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
//    func render()
    func render()
//    func didRender(texture: MTLTexture, force: Bool)
    func destroy()
    
    func isEqual(to node: NODE) -> Bool
    
    func addView() -> NODEView
    func removeView(_ view: NODEView)
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

// MARK: - 3D

public protocol NODE3D: NODE {
    var renderedResolution3d: Resolution3D { get }
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

public protocol NODEEffect: NODE {}

public protocol NODESingleEffect: NODEEffect {}
public protocol NODEMergerEffect: NODEEffect {
    var placement: Placement { get set }
}
public protocol NODEMultiEffect: NODEEffect {}

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

public protocol NODEMetal {
//    var metalFileName: String { get }
    var metalBaseCode: String { get }
    var metalCode: String? { get }
    var metalUniforms: [MetalUniform] { get }
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
