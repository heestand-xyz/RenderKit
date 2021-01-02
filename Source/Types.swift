//
//  Types.swift
//  RenderKit
//
//  Created by Anton Heestand on 2019-10-02.
//  Copyright © 2019 Hexagons. All rights reserved.
//


import CoreGraphics
import Metal
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

// MARK: - Pixel

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
    public var x,y,z: CGFloat
    public var s,t: CGFloat
    public var buffer: [Float] {
        return [x,y,s,t].map({ Float($0.cg) })
    }
    public var buffer3d: [Float] {
        return [x,y,z,s,t].map({ Float($0.cg) })
    }
    public init(x: CGFloat, y: CGFloat, z: CGFloat = 0.0, s: CGFloat, t: CGFloat) {
        self.x = x; self.y = y; self.z = z; self.s = s; self.t = t
    }
}

// MARK: - Metal Uniform

public class MetalUniform {
    public var name: String
    public var value: CGFloat
    public init(name: String, value: CGFloat = 0.0) {
        self.name = name
        self.value = value
    }
}

// MARK: - Placement

public enum Placement: String, Codable, CaseIterable {
    case fit
    case fill
    case center
    case stretch
    public var index: Int {
        switch self {
        case .stretch: return 0
        case .fit: return 1
        case .fill: return 2
        case .center: return 3
        }
    }
}

// MARK: - Blend

public enum BlendMode: String, Codable, CaseIterable {
    
    /// **over** blend mode operator: `&`
    case over
    
    /// **under** blend mode operator: `!&`
    case under
    
    /// **add** blend mode operator: `+`
    case add
    
    /// **add with alpha** blend mode operator: `++`
    case addWithAlpha
    
    @available(*, deprecated, renamed: "mult")
    public static var multiply: BlendMode { .mult }
    /// **mult** or *multiply* blend mode operator: `*`
    case mult
    
    @available(*, deprecated, renamed: "diff")
    public static var difference: BlendMode { .diff }
    /// **diff** or *difference* blend mode operator: `%`
    case diff
    
    @available(*, deprecated, renamed: "sub")
    public static var subtract: BlendMode { .sub }
    /// **sub** or *subtract* blend mode operator: `-`
    case sub
    
    @available(*, deprecated, renamed: "subWithAlpha")
    public static var subtractWithAlpha: BlendMode { .subWithAlpha }
    /// **sub with alpha** or *subtract with alpha* blend mode operator: `--`
    case subWithAlpha
    
    @available(*, deprecated, renamed: "max")
    public static var maximum: BlendMode { .max }
    /// **max** or *maximum* blend mode operator: `><`
    case max
    
    @available(*, deprecated, renamed: "min")
    public static var minimum: BlendMode { .min }
    /// **min** or *minimum* blend mode operator: `<>`
    case min
    
    @available(*, deprecated, renamed: "gam")
    public static var gamma: BlendMode { .gam }
    /// **gam** or *gamma* blend mode operator: `!**`
    case gam
    
    @available(*, deprecated, renamed: "pow")
    public static var power: BlendMode { .pow }
    /// **pow** or *power* blend mode operator: `**`
    case pow
    
    @available(*, deprecated, renamed: "div")
    public static var divide: BlendMode { .div }
    /// **div** or *divide* blend mode operator: `/`
    case div
    
    @available(*, deprecated, renamed: "avg")
    public static var average: BlendMode { .avg }
    /// **avg** or *average* blend mode operator: `~`
    case avg
    
    @available(*, deprecated, renamed: "cos")
    public static var cosine: BlendMode { .cos }
    /// **cos** or *cosine* blend mode operator: `°`
    case cos
    
    @available(*, deprecated, renamed: "in")
    public static var inside: BlendMode { .in }
    /// **in** or *inside* blend mode operator: `<->`
    case `in`
    
    @available(*, deprecated, renamed: "out")
    public static var outside: BlendMode { .out }
    /// **out** or *outside* blend mode operator: `>-<`
    case out
    
    @available(*, deprecated, renamed: "xor")
    public static var exclusiveOr: BlendMode { .xor }
    /// **xor** or *exclusive or* blend mode operator: `+-+`
    case xor
    
    public var index: Int {
        switch self {
        case .over: return 0
        case .under: return 1
        case .add: return 2
        case .addWithAlpha: return 3
        case .mult: return 4
        case .diff: return 5
        case .sub: return 6
        case .subWithAlpha: return 7
        case .max: return 8
        case .min: return 9
        case .gam: return 10
        case .pow: return 11
        case .div: return 12
        case .avg: return 13
        case .cos: return 14
        case .in: return 15
        case .out: return 16
        case .xor: return 17
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
