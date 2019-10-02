//
//  Types.swift
//  RenderKit
//
//  Created by Anton Heestand on 2019-10-02.
//  Copyright © 2019 Hexagons. All rights reserved.
//

import LiveValues

// MARK: - Vector

struct Vector {
    let x: CGFloat
    let y: CGFloat
    let z: CGFloat
}

// MARK: - #xel

struct Pixel {
    public let x: Int
    public let y: Int
    public let uv: CGVector
    public let color: LiveColor
}

struct Voxel {
    public let x: Int
    public let y: Int
    public let z: Int
    public let uvw: Vector
    public let color: LiveColor
}

// MARK: - Vertices

public struct Vertices {
    public let buffer: MTLBuffer
    public let vertexCount: Int
    public let type: MTLPrimitiveType
    public let wireframe: Bool
    public init(buffer: MTLBuffer, vertexCount: Int, type: MTLPrimitiveType = .triangle, wireframe: Bool = false) {
        self.buffer = buffer
        self.vertexCount = vertexCount
        self.type = type
        self.wireframe = wireframe
    }
}
