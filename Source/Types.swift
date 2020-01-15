//
//  Types.swift
//  RenderKit
//
//  Created by Anton Heestand on 2019-10-02.
//  Copyright © 2019 Hexagons. All rights reserved.
//

import LiveValues
#if !os(tvOS) && !targetEnvironment(simulator)
import MetalPerformanceShaders
#endif

// MARK: - Vector

public struct Vector: Equatable {
    public let x: CGFloat
    public let y: CGFloat
    public let z: CGFloat
    public init(x: CGFloat, y: CGFloat, z: CGFloat) {
        self.x = x
        self.y = y
        self.z = z
    }
}

// MARK: - #xel

public struct Pixel {
    public let x: Int
    public let y: Int
    public let uv: CGVector
    public let color: LiveColor
    public init(x: Int, y: Int, uv: CGVector, color: LiveColor) {
        self.x = x
        self.y = y
        self.uv = uv
        self.color = color
    }
}

public struct Voxel {
    public let x: Int
    public let y: Int
    public let z: Int
    public let uvw: Vector
    public let color: LiveColor
    public init(x: Int, y: Int, z: Int, uvw: Vector, color: LiveColor) {
        self.x = x
        self.y = y
        self.z = z
        self.uvw = uvw
        self.color = color
    }
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

public struct Vertex {
    public var x,y,z: LiveFloat
    public var s,t: LiveFloat
    public var buffer: [Float] {
        return [x,y,s,t].map({ Float($0.cg) })
    }
    public var buffer3d: [Float] {
        return [x,y,z,s,t].map({ Float($0.cg) })
    }
    public init(x: LiveFloat, y: LiveFloat, z: LiveFloat = 0.0, s: LiveFloat, t: LiveFloat) {
        self.x = x; self.y = y; self.z = z; self.s = s; self.t = t
    }
}

// MARK: - Metal Uniform

public class MetalUniform {
    public var name: String
    public var value: LiveFloat
    public init(name: String, value: LiveFloat = 0.0) {
        self.name = name
        self.value = value
    }
}

// MARK: - Placement

public enum Placement: String, Codable, CaseIterable {
    case fill
    case aspectFit
    case aspectFill
    case custom
    public var index: Int {
        switch self {
        case .fill: return 0
        case .aspectFit: return 1
        case .aspectFill: return 2
        case .custom: return 3
        }
    }
}

// MARK: - Blend

public enum BlendMode: String, Codable, CaseIterable {
    case over
    case under
    case add
    case addWithAlpha
    case multiply
    case difference
    case subtract
    case subtractWithAlpha
    case maximum
    case minimum
    case gamma
    case power
    case divide
    case average
    case cosine
    case inside
    case outside
    case exclusiveOr
    public var index: Int {
        switch self {
        case .over: return 0
        case .under: return 1
        case .add: return 2
        case .addWithAlpha: return 3
        case .multiply: return 4
        case .difference: return 5
        case .subtract: return 6
        case .subtractWithAlpha: return 7
        case .maximum: return 8
        case .minimum: return 9
        case .gamma: return 10
        case .power: return 11
        case .divide: return 12
        case .average: return 13
        case .cosine: return 14
        case .inside: return 15
        case .outside: return 16
        case .exclusiveOr: return 17
        }
    }
}

// MARK: - Interpolation

public enum InterpolateMode: String, Codable, CaseIterable {
    case nearest
    case linear
//    #if !os(tvOS) && !targetEnvironment(simulator)
    public var mtl: MTLSamplerMinMagFilter {
        switch self {
        case .nearest: return .nearest
        case .linear: return .linear
        }
    }
//    #endif
}

// MARK: - Extend

public enum ExtendMode: String, Codable, CaseIterable {
    case hold
    case zero
    case loop
    case mirror
    public var mtl: MTLSamplerAddressMode {
        switch self {
        case .hold: return .clampToEdge
        case .zero: return .clampToZero
        case .loop: return .repeat
        case .mirror: return .mirrorRepeat
        }
    }
    #if !os(tvOS) && !targetEnvironment(simulator)
    public var mps: MPSImageEdgeMode? {
        switch self {
        case .zero:
            if #available(OSX 10.13, *) {
                return .zero
            } else {
                return nil
            }
        default:
            if #available(OSX 10.13, *) {
                return .clamp
            } else {
                return nil
            }
        }
    }
    #endif
    public var index: Int {
        switch self {
        case .hold: return 0
        case .zero: return 1
        case .loop: return 2
        case .mirror: return 3
        }
    }
}

// MARK: - Tile Index

public struct TileIndex {
    public let x: Int
    public let y: Int
    public let z: Int
    public init(x: Int, y: Int, z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }
    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
        self.z = 0
    }
}
