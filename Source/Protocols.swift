//
//  Protocols.swift
//  RenderKit
//
//  Created by Anton Heestand on 2019-10-02.
//

import Metal

//public protocol RenderDelegate: AnyObject {
//    func pixelFrameLoop()
//}

public protocol ManualRenderDelegate: AnyObject {
    func pixelNeedsManualRender()
}

public protocol CustomRenderDelegate: AnyObject {
    func customRender(_ texture: MTLTexture, with commandBuffer: MTLCommandBuffer) -> MTLTexture?
}

public protocol CustomMergerRenderDelegate: AnyObject {
    func customRender(a textureA: MTLTexture, b textureB: MTLTexture, with commandBuffer: MTLCommandBuffer) -> MTLTexture?
}

public protocol CustomGeometryDelegate: AnyObject {
    func customVertices() -> Vertices?
}
