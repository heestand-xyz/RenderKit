//
//  Types.swift
//  RenderKit
//
//  Created by Anton Heestand on 2019-10-02.
//


import CoreGraphics
import Metal
#if !os(tvOS) && !targetEnvironment(simulator)
import MetalPerformanceShaders
#endif
import PixelColor

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
    public let color: PixelColor
    public init(x: Int, y: Int, uv: CGVector, color: PixelColor) {
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
    public let color: PixelColor
    public init(x: Int, y: Int, z: Int, uvw: Vector, color: PixelColor) {
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
        return [x,y,s,t].map({ Float($0) })
    }
    public var buffer3d: [Float] {
        return [x,y,z,s,t].map({ Float($0) })
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

public enum Placement: String, Enumable {
    case fit = "Fit"
    case fill = "Fill"
    case center = "Center"
    case stretch = "Stretch"
    public var index: Int {
        switch self {
        case .stretch: return 0
        case .fit: return 1
        case .fill: return 2
        case .center: return 3
        }
    }
    public var names: [String] {
        Self.allCases.map(\.rawValue)
    }
}

// MARK: - Blend

public enum BlendMode: String, Enumable {
    
    /// **over** blend mode operator: `&`
    case over = "Over"
    
    /// **under** blend mode operator: `!&`
    case under = "Under"
    
    /// **add** blend mode operator: `+`
    case add = "Add"
    
    /// **add with alpha** blend mode operator: `++`
    case addWithAlpha = "Add with Alpha"
    
    @available(*, deprecated, renamed: "multiply")
    public static var mult: BlendMode { .multiply }
    /// **multiply** blend mode operator: `*`
    case multiply = "Multiply"
    
    @available(*, deprecated, renamed: "difference")
    public static var diff: BlendMode { .difference }
    /// **difference** blend mode operator: `%`
    case difference = "Difference"
    
    @available(*, deprecated, renamed: "subtract")
    public static var sub: BlendMode { .subtract }
    /// **subtract** blend mode operator: `-`
    case subtract = "Subtract"
    
    @available(*, deprecated, renamed: "subtractWithAlpha")
    public static var subWithAlpha: BlendMode { .subtractWithAlpha }
    /// **subtract with alpha** blend mode operator: `--`
    case subtractWithAlpha = "Subtract with Alpha"
    
    @available(*, deprecated, renamed: "maximum")
    public static var max: BlendMode { .maximum }
    /// **maximum** blend mode operator: `><`
    case maximum = "Maximum"
    
    @available(*, deprecated, renamed: "minimum")
    public static var min: BlendMode { .minimum }
    /// **minimum** blend mode operator: `<>`
    case minimum = "Minimum"
    
    @available(*, deprecated, renamed: "gamma")
    public static var gam: BlendMode { .gamma }
    /// **gamma** blend mode operator: `!**`
    case gamma = "Gamma"
    
    @available(*, deprecated, renamed: "power")
    public static var pow: BlendMode { .power }
    /// **power** blend mode operator: `**`
    case power = "Power"
    
    @available(*, deprecated, renamed: "divide")
    public static var div: BlendMode { .divide }
    /// **divide** blend mode operator: `/`
    case divide = "Divide"
    
    @available(*, deprecated, renamed: "average")
    public static var avg: BlendMode { .average }
    /// **average** blend mode operator: `~`
    case average = "Average"
    
    @available(*, deprecated, renamed: "cosine")
    public static var cos: BlendMode { .cosine }
    /// **cosine** blend mode operator: `°`
    case cosine = "Cosine"
    
    @available(*, deprecated, renamed: "inside")
    public static var `in`: BlendMode { .inside }
    /// **inside** blend mode operator: `<->`
    case inside = "Inside"
    
    @available(*, deprecated, renamed: "outside")
    public static var out: BlendMode { .outside }
    /// **outside** blend mode operator: `>-<`
    case outside = "Outside"
    
    @available(*, deprecated, renamed: "exclusiveOr")
    public static var xor: BlendMode { .exclusiveOr }
    /// **exclusive or** blend mode operator: `+-+`
    case exclusiveOr = "Exclusive Or"
    
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
    
    public var names: [String] {
        Self.allCases.map(\.rawValue)
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

public enum ExtendMode: String, Enumable {
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
    public var names: [String] {
        Self.allCases.map(\.rawValue)
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
