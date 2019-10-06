//
//  Resolution3D.swift
//  RenderKit
//
//  Created by Anton Heestand on 2019-10-04.
//  Copyright © 2019 Hexagons. All rights reserved.
//

import LiveValues
import CoreGraphics

public enum Resolution3D: ResolutionStandard {
    
    case _8
    case _16
    case _32
    case _64
    case _128
    case _256
    case _512
    case _1024
    public static var cubeCases: [Resolution3D] {
        return [._8, ._16, ._32, ._64, ._128, ._256, ._512, ._1024]
    }
    
    case vec(_ vec: LiveVec)
    case custom(x: Int, y: Int, z: Int)
    case cube(_ val: Int)
    case raw(_ rax: Raw)
    
    // MARK: Name
    
    public var name: String {
        return "\(raw.x)x\(raw.y)x\(raw.z)"
    }
    
    // MARK: Raw
    
    public var rawWidth: Int { x }
    public var rawHeight: Int { y }
    public var rawDepth: Int { z }
    
    public struct Raw {
        public let x: Int
        public let y: Int
        public let z: Int
        public static func ==(lhs: Raw, rhs: Raw) -> Bool {
            return lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z
        }
    }
    
    public var raw: Raw {
        switch self {
        case ._8: return Raw(x: 8, y: 8, z: 8)
        case ._16: return Raw(x: 16, y: 16, z: 16)
        case ._32: return Raw(x: 32, y: 32, z: 32)
        case ._64: return Raw(x: 64, y: 64, z: 64)
        case ._128: return Raw(x: 128, y: 128, z: 128)
        case ._256: return Raw(x: 256, y: 256, z: 256)
        case ._512: return Raw(x: 512, y: 512, z: 512)
        case ._1024: return Raw(x: 1024, y: 1024, z: 1024)
        case .vec(let vec): return Raw(x: Int(vec.x.cg), y: Int(vec.y.cg), z: Int(vec.z.cg))
        case .custom(let x, let y, let z): return Raw(x: x, y: y, z: z)
        case .cube(let val): return Raw(x: val, y: val, z: val)
        case .raw(let raw): return raw
        }
    }
    
    public var x: Int {
        return raw.x
    }
    public var y: Int {
        return raw.y
    }
    public var z: Int {
        return raw.z
    }
    
    public var count: Int {
        return x * y * z
    }
    
    // MARK: Vector
    
    public var vector: Vector {
        Vector(x: CGFloat(x), y: CGFloat(y), z: CGFloat(z))
    }
    
    // MARK: - Life Cycle
    
    public init(_ vector: Vector) {
        switch vector {
        case Resolution3D._8.vector: self = ._8
        case Resolution3D._16.vector: self = ._16
        case Resolution3D._32.vector: self = ._32
        case Resolution3D._64.vector: self = ._64
        case Resolution3D._128.vector: self = ._128
        case Resolution3D._256.vector: self = ._256
        case Resolution3D._512.vector: self = ._512
        case Resolution3D._1024.vector: self = ._1024
        default: self = .custom(x: Int(vector.x), y: Int(vector.y), z: Int(vector.z))
        }
    }
    
    public init(_ raw: Raw) {
        self = .raw(raw)
    }
    
    public init(texture: MTLTexture) {
        // CHECK depth is more than 1
        self = .custom(x: texture.width, y: texture.height, z: texture.depth)
    }
    
    // MARK: - Operator Overloads
    
    public static func ==(lhs: Resolution3D, rhs: Resolution3D) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z
    }
    public static func !=(lhs: Resolution3D, rhs: Resolution3D) -> Bool {
        return !(lhs == rhs)
    }
    
    public static func >(lhs: Resolution3D, rhs: Resolution3D) -> Bool? {
        let x = lhs.x > rhs.x
        let y = lhs.y > rhs.y
        let z = lhs.z > rhs.z
        return (x && y && z) ? true : (!x && !y && !z) ? false : nil
    }
    public static func <(lhs: Resolution3D, rhs: Resolution3D) -> Bool? {
        let x = lhs.x < rhs.x
        let y = lhs.y < rhs.y
        let z = lhs.z < rhs.z
        return (x && y && z) ? true : (!x && !y && !z) ? false : nil
    }
    public static func >=(lhs: Resolution3D, rhs: Resolution3D) -> Bool? {
        let x = lhs.x >= rhs.x
        let y = lhs.y >= rhs.y
        let z = lhs.z >= rhs.z
        return (x && y && z) ? true : (!x && !y && !z) ? false : nil
    }
    public static func <=(lhs: Resolution3D, rhs: Resolution3D) -> Bool? {
        let x = lhs.x <= rhs.x
        let y = lhs.y <= rhs.y
        let z = lhs.z <= rhs.z
        return (x && y && z) ? true : (!x && !y && !z) ? false : nil
    }
    
    public static func +(lhs: Resolution3D, rhs: Resolution3D) -> Resolution3D {
        return Resolution3D(Raw(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z))
    }
    public static func -(lhs: Resolution3D, rhs: Resolution3D) -> Resolution3D {
        return Resolution3D(Raw(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z))
    }
    public static func *(lhs: Resolution3D, rhs: Resolution3D) -> Resolution3D {
        return Resolution3D(Raw(x: Int(lhs.vector.x * rhs.vector.x),
                                y: Int(lhs.vector.y * rhs.vector.y),
                                z: Int(lhs.vector.z * rhs.vector.z)))
    }
    
    public static func +(lhs: Resolution3D, rhs: CGFloat) -> Resolution3D {
        return Resolution3D(Raw(x: lhs.x + Int(rhs), y: lhs.y + Int(rhs), z: lhs.z + Int(rhs)))
    }
    public static func -(lhs: Resolution3D, rhs: CGFloat) -> Resolution3D {
        return Resolution3D(Raw(x: lhs.x - Int(rhs), y: lhs.y - Int(rhs), z: lhs.z - Int(rhs)))
    }
    public static func *(lhs: Resolution3D, rhs: CGFloat) -> Resolution3D {
        return Resolution3D(Raw(x: Int(round(lhs.vector.x * rhs)),
                                y: Int(round(lhs.vector.y * rhs)),
                                z: Int(round(lhs.vector.z * rhs))))
    }
    public static func /(lhs: Resolution3D, rhs: CGFloat) -> Resolution3D {
        return Resolution3D(Raw(x: Int(round(lhs.vector.x / rhs)),
                                y: Int(round(lhs.vector.y / rhs)),
                                z: Int(round(lhs.vector.z / rhs))))
    }
    public static func +(lhs: CGFloat, rhs: Resolution3D) -> Resolution3D {
        return rhs + lhs
    }
    public static func -(lhs: CGFloat, rhs: Resolution3D) -> Resolution3D {
        return (rhs - lhs) * CGFloat(-1.0)
    }
    public static func *(lhs: CGFloat, rhs: Resolution3D) -> Resolution3D {
        return rhs * lhs
    }
    
    public static func +(lhs: Resolution3D, rhs: Int) -> Resolution3D {
        return Resolution3D(Raw(x: lhs.x + Int(rhs), y: lhs.y + Int(rhs), z: lhs.z + Int(rhs)))
    }
    public static func -(lhs: Resolution3D, rhs: Int) -> Resolution3D {
        return Resolution3D(Raw(x: lhs.x - Int(rhs), y: lhs.y - Int(rhs), z: lhs.z - Int(rhs)))
    }
    public static func *(lhs: Resolution3D, rhs: Int) -> Resolution3D {
        return Resolution3D(Raw(x: Int(round(lhs.vector.x * CGFloat(rhs))),
                                y: Int(round(lhs.vector.y * CGFloat(rhs))),
                                z: Int(round(lhs.vector.z * CGFloat(rhs)))))
    }
    public static func /(lhs: Resolution3D, rhs: Int) -> Resolution3D {
        return Resolution3D(Raw(x: Int(round(lhs.vector.x / CGFloat(rhs))),
                                y: Int(round(lhs.vector.y / CGFloat(rhs))),
                                z: Int(round(lhs.vector.z / CGFloat(rhs)))))
    }
    public static func +(lhs: Int, rhs: Resolution3D) -> Resolution3D {
        return rhs + lhs
    }
    public static func -(lhs: Int, rhs: Resolution3D) -> Resolution3D {
        return (rhs - lhs) * Int(-1)
    }
    public static func *(lhs: Int, rhs: Resolution3D) -> Resolution3D {
        return rhs * lhs
    }
    
    public static func +(lhs: Resolution3D, rhs: Double) -> Resolution3D {
        return Resolution3D(Raw(x: lhs.x + Int(rhs), y: lhs.y + Int(rhs), z: lhs.z + Int(rhs)))
    }
    public static func -(lhs: Resolution3D, rhs: Double) -> Resolution3D {
        return Resolution3D(Raw(x: lhs.x - Int(rhs), y: lhs.y - Int(rhs), z: lhs.z - Int(rhs)))
    }
    public static func *(lhs: Resolution3D, rhs: Double) -> Resolution3D {
        return Resolution3D(Raw(x: Int(round(lhs.vector.x * CGFloat(rhs))),
                                y: Int(round(lhs.vector.y * CGFloat(rhs))),
                                z: Int(round(lhs.vector.z * CGFloat(rhs)))))
    }
    public static func /(lhs: Resolution3D, rhs: Double) -> Resolution3D {
        return Resolution3D(Raw(x: Int(round(lhs.vector.x / CGFloat(rhs))),
                                y: Int(round(lhs.vector.y / CGFloat(rhs))),
                                z: Int(round(lhs.vector.z / CGFloat(rhs)))))
    }
    public static func +(lhs: Double, rhs: Resolution3D) -> Resolution3D {
        return rhs + lhs
    }
    public static func -(lhs: Double, rhs: Resolution3D) -> Resolution3D {
        return (rhs - lhs) * Double(-1.0)
    }
    public static func *(lhs: Double, rhs: Resolution3D) -> Resolution3D {
        return rhs * lhs
    }
    
    public static func +(lhs: Resolution3D, rhs: LiveFloat) -> Resolution3D {
        return Resolution3D(Raw(x: lhs.x + Int(rhs.cg), y: lhs.y + Int(rhs.cg), z: lhs.z + Int(rhs.cg)))
    }
    public static func -(lhs: Resolution3D, rhs: LiveFloat) -> Resolution3D {
        return Resolution3D(Raw(x: lhs.x - Int(rhs.cg), y: lhs.y - Int(rhs.cg), z: lhs.z - Int(rhs.cg)))
    }
    public static func *(lhs: Resolution3D, rhs: LiveFloat) -> Resolution3D {
        return Resolution3D(Raw(x: Int(round(lhs.vector.x * rhs.cg)),
                                y: Int(round(lhs.vector.y * rhs.cg)),
                                z: Int(round(lhs.vector.z * rhs.cg))))
    }
    public static func /(lhs: Resolution3D, rhs: LiveFloat) -> Resolution3D {
        return Resolution3D(Raw(x: Int(round(lhs.vector.x / rhs.cg)),
                                y: Int(round(lhs.vector.y / rhs.cg)),
                                z: Int(round(lhs.vector.z / rhs.cg))))
    }
    public static func +(lhs: LiveFloat, rhs: Resolution3D) -> Resolution3D {
        return rhs + lhs
    }
    public static func -(lhs: LiveFloat, rhs: Resolution3D) -> Resolution3D {
        return (rhs - lhs) * LiveFloat(-1.0)
    }
    public static func *(lhs: LiveFloat, rhs: Resolution3D) -> Resolution3D {
        return rhs * lhs
    }
    
}
