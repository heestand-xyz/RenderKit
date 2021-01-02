//
//  Protocols.swift
//  RenderKit
//
//  Created by Anton Heestand on 2019-10-02.
//

import Metal

public protocol RenderDelegate: class {
    func pixelFrameLoop()
}

public protocol ManualRenderDelegate {
    func pixelNeedsManualRender()
}

public protocol CustomRenderDelegate {
    func customRender(_ texture: MTLTexture, with commandBuffer: MTLCommandBuffer) -> MTLTexture?
}

public protocol CustomMergerRenderDelegate {
    func customRender(a textureA: MTLTexture, b textureB: MTLTexture, with commandBuffer: MTLCommandBuffer) -> MTLTexture?
}

public protocol CustomGeometryDelegate {
    func customVertices() -> Vertices?
}
