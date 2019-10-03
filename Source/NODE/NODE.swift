//
//  NODE.swift
//  RenderKit
//
//  Created by Anton Heestand on 2019-10-03.
//  Copyright © 2019 Hexagons. All rights reserved.
//

import LiveValues
import Metal
import simd

public protocol NODE {
    
    var id: UUID { get }
    var name: String? { get }
    
    var delegate: NODEDelegate? { get set }
    
    var shaderName: String { get }
    
    var view: NODEView { get }

    var liveValues: [LiveValue] { get }
    var liveArray: [[LiveFloat]] { get }
    var preUniforms: [CGFloat] { get }
    var uniforms: [CGFloat] { get }
    var postUniforms: [CGFloat] { get }
    var uniformArray: [[CGFloat]] { get }
    
    var needsRender: Bool { get set }
    var rendering: Bool { get set }
    var inRender: Bool { get set }
    var renderIndex: Int { get set }
    var bypass: Bool { get set }
    var contentLoaded: Bool? { get set }
    var renderResolution: Resolution { get }

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
    var customLinkedNodes: [NODE] { get set }
    
    var destroyed: Bool { get set }
    
    var texture: MTLTexture? { get set }
    
    func applyResolution(applied: @escaping () -> ())
    func setNeedsRender()
    func didRender(texture: MTLTexture, force: Bool)
    func checkLive()
    func destroy()
    
    func isEqual(to node: NODE) -> Bool
    
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

// MARK: - Content

public protocol NODEContent: NODE {}

public protocol NODEGenerator: NODEContent {
    var premultiply: Bool { get set }
}

public protocol NODECustom: NODEContent {
    
    func customRender(_ texture: MTLTexture, with commandBuffer: MTLCommandBuffer) -> MTLTexture?
}

// MARK: - Effects

public protocol NODEEffect: NODE {}

public protocol NODESingleEffect: NODEEffect {
    
}
public protocol NODEMergerEffect: NODEEffect {
    
    var placement: Placement { get set }
    
}
public protocol NODEMultiEffect: NODEEffect {
    
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
