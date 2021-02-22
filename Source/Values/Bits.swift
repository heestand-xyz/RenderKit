//
//  Bits.swift
//  
//
//  Created by Anton Heestand on 2021-01-01.
//

import Foundation
import MetalKit

public enum Bits: Int, Codable, CaseIterable {
    case _8 = 8
    case _10 = 10
    case _16 = 16
    case _32 = 32
    public var pixelFormat: MTLPixelFormat {
        switch self {
        case ._8: return .bgra8Unorm // .rgba8Unorm
        case ._10:
            #if os(iOS) && !targetEnvironment(macCatalyst)
            return .bgra10_xr_srgb
            #else
            return .bgra8Unorm
            #endif
        case ._16: return .rgba16Float
        case ._32: return .rgba32Float // invalid pixel format 125
        }
    }
    public var monochromePixelFormat: MTLPixelFormat {
        switch self {
        case ._8: return .r8Unorm
        case ._16: return .r16Float
        case ._32: return .r32Float
        default: return .r8Unorm
        }
    }
    public var monochromeWithAlphaPixelFormat: MTLPixelFormat {
        switch self {
        case ._8: return .rg8Unorm
        case ._16: return .rg16Float
        case ._32: return .rg32Float
        default: return .rg8Unorm
        }
    }
    public var ci: CIFormat {
        switch self {
        case ._8, ._10: return .RGBA8
        case ._16: return .RGBAh
        case ._32: return .RGBAf
        }
    }
    public var os: OSType {
        switch self {
        case ._8, ._10, ._16:
            return kCVPixelFormatType_32BGRA
//        case ._16:
//            return kCVPixelFormatType_64ARGB
        default:
            return kCVPixelFormatType_128RGBAFloat
        }
    }
    public var osARGB: OSType {
        return kCVPixelFormatType_32ARGB
    }
    public var max: Int {
        return NSDecimalNumber(decimal: pow(2, self.rawValue)).intValue - 1
    }
    public static func bits(for pixelFormat: MTLPixelFormat) -> Bits? {
        for bits in self.allCases {
            if bits.pixelFormat == pixelFormat {
                return bits
            }
        }
        return nil
    }
}
