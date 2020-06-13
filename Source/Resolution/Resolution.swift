//
//  PIXResolution.swift
//  RenderKit
//
//  Created by Hexagons on 2018-08-07.
//  Open Source - MIT License
//

import LiveValues
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public enum Resolution: ResolutionStandard, CustomDebugStringConvertible, Codable, Hashable {
    
    case auto(render: Render)
    
    case _540p
    case _720p
    case _1080p
    case _4K
    case _8K
    public static var standardCases: [Resolution] {
        return [._540p, ._720p, ._1080p, ._4K, ._8K]
    }

    case fullHD(Orientation)
    case ultraHD(Orientation)
    public static var hdCases: [Resolution] {
        return [
            .fullHD(.portrait), .fullHD(.landscape),
            .ultraHD(.portrait), .ultraHD(.landscape)
        ]
    }
    
    case _128
    case _256
    case _512
    case _1024
    case _2048
    case _4096
    case _8192
    case _16384
    public static var squareCases: [Resolution] {
        return [._128, ._256, ._512, ._1024, ._2048, ._4096, ._8192, ._16384]
    }
    
    case iPhone(Orientation)
    case iPhonePlus(Orientation)
    case iPhoneX(Orientation)
    case iPhoneXSMax(Orientation)
    case iPhoneXR(Orientation)
    case iPhone11(Orientation)
    case iPhone11Pro(Orientation)
    case iPhone11ProMax(Orientation)
    public static var iPhones: [Resolution] {
        return [
            .iPhone(.portrait), .iPhone(.landscape),
            .iPhonePlus(.portrait), .iPhonePlus(.landscape),
            .iPhoneX(.portrait), .iPhoneX(.landscape),
            .iPhoneXSMax(.portrait), .iPhoneXSMax(.landscape),
            .iPhoneXR(.portrait), .iPhoneXR(.landscape),
            .iPhone11(.portrait), .iPhone11(.landscape),
            .iPhone11Pro(.portrait), .iPhone11Pro(.landscape),
            .iPhone11ProMax(.portrait), .iPhone11ProMax(.landscape)
        ]
    }
    
    case iPad(Orientation)
    case iPad_10_2(Orientation)
    case iPadPro_10_5(Orientation)
    case iPadPro_11(Orientation)
    case iPadPro_12_9(Orientation)
    public static var iPads: [Resolution] {
        return [
            .iPad(.portrait), .iPad(.landscape),
            .iPad_10_2(.portrait), .iPad_10_2(.landscape),
            .iPadPro_10_5(.portrait), .iPadPro_10_5(.landscape),
            .iPadPro_11(.portrait), .iPadPro_11(.landscape),
            .iPadPro_12_9(.portrait), .iPadPro_12_9(.landscape)
        ]
    }
    
    case fullscreen
    
    case cgSize(_ size: CGSize)
    case size(_ size: LiveSize)
    case custom(w: Int, h: Int)
    case square(_ val: Int)
    case raw(_ raw: Raw)
    
    public enum Orientation {
        case portrait
        case landscape
        var postfix: String {
            switch self {
            case .portrait:
                return " in Portrait"
            case .landscape:
                return " in Landscape"
            }
        }
    }
    
    // MARK: Description
    
    public var debugDescription: String { "\(w)x\(h)" }
    
    public var description: String { "\(w)x\(h)" }

    public var name: String {
        switch self {
        case .auto: return "Auto"
        case ._540p: return "540p"
        case ._720p: return "720p"
        case ._1080p: return "1080p"
        case ._4K: return "4K"
        case ._8K: return "8K"
        case .fullHD(let ori): return "Full HD" + ori.postfix
        case .ultraHD(let ori): return "Ultra HD" + ori.postfix
        case .iPhone(let ori): return "iPhone" + ori.postfix
        case .iPhonePlus(let ori): return "iPhone Plus" + ori.postfix
        case .iPhoneX(let ori): return "iPhone X" + ori.postfix
        case .iPhoneXSMax(let ori): return "iPhone XS Max" + ori.postfix
        case .iPhoneXR(let ori): return "iPhone XR" + ori.postfix
        case .iPhone11(let ori): return "iPhone 11" + ori.postfix
        case .iPhone11Pro(let ori): return "iPhone 11 Pro" + ori.postfix
        case .iPhone11ProMax(let ori): return "iPhone 11 Pro Max" + ori.postfix
        case .iPad(let ori): return "iPad" + ori.postfix
        case .iPad_10_2(let ori): return "iPad 10.2‑inch" + ori.postfix
        case .iPadPro_10_5(let ori): return "iPad Pro 10.5‑inch" + ori.postfix
        case .iPadPro_11(let ori): return "iPad Pro 11‑inch" + ori.postfix
        case .iPadPro_12_9(let ori): return "iPad Pro 12.9‑inch" + ori.postfix
        case .fullscreen: return "Full Screen"
        default: return "\(raw.w)x\(raw.h)"
        }
    }
    
    // MARK: Display Size in Inches
    
    public var inches: CGFloat? {
        switch self {
        case .iPhone: return 4.7
        case .iPhonePlus: return 5.5
        case .iPhoneX, .iPhone11: return 6.1
        case .iPhoneXR, .iPhone11Pro: return 5.8
        case .iPhoneXSMax, .iPhone11ProMax: return 6.5
        case .iPad: return 9.7
        case .iPad_10_2: return 10.2
        case .iPadPro_10_5: return 10.5
        case .iPadPro_11: return 11.0
        case .iPadPro_12_9: return 12.9
        default: return nil
        }
    }
    
    // MARK: Pro
    
    public var isPro: Bool {
        let resolution: Resolution = .init(size: size.cg)
        switch resolution {
        case .iPhone11Pro, .iPhone11ProMax:
            return true
        case .iPadPro_10_5, .iPadPro_12_9, .iPadPro_11:
            return true
        default:
            return false
        }
    }
    
    // MARK: Raw
    
    public var rawWidth: Int { w }
    public var rawHeight: Int { h }
    public var rawDepth: Int { 1 }
    
    public struct Raw {
        public let w: Int
        public let h: Int
        public var flopped: Raw { return Raw(w: h, h: w) }
        public static func ==(lhs: Raw, rhs: Raw) -> Bool {
            return lhs.w == rhs.w && lhs.h == rhs.h
        }
    }
    
    public var raw: Raw {
        switch self {
        case .auto(let render):
            let scale = Resolution.scale.cg
            for node in render.linkedNodes {
                guard let superview = node.view.superview else { continue }
                let size = superview.frame.size
                return Raw(w: Int(size.width * scale), h: Int(size.height * scale))
            }
            return Resolution._128.raw
        case ._540p: return Raw(w: 960, h: 540)
        case ._720p: return Raw(w: 1280, h: 720)
        case ._1080p: return Raw(w: 1920, h: 1080)
        case ._4K: return Raw(w: 3840, h: 2160)
        case ._8K: return Raw(w: 7680, h: 4320)
        case .fullHD(let ori):
            let raw = Raw(w: 1920, h: 1080)
            if ori == .landscape { return raw }
            else { return raw.flopped }
        case .ultraHD(let ori):
            let raw = Raw(w: 3840, h: 2160)
            if ori == .landscape { return raw }
            else { return raw.flopped }
        case ._128: return Raw(w: 128, h: 128)
        case ._256: return Raw(w: 256, h: 256)
        case ._512: return Raw(w: 512, h: 512)
        case ._1024: return Raw(w: 1024, h: 1024)
        case ._2048: return Raw(w: 2048, h: 2048)
        case ._4096: return Raw(w: 4096, h: 4096)
        case ._8192: return Raw(w: 8192, h: 8192)
        case ._16384: return Raw(w: 16384, h: 16384)
        case .iPhone(let ori):
            let raw = Raw(w: 750, h: 1334)
            if ori == .portrait { return raw }
            else { return raw.flopped }
        case .iPhonePlus(let ori):
            let raw = Raw(w: 1080, h: 1920)
            if ori == .portrait { return raw }
            else { return raw.flopped }
        case .iPhoneX(let ori):
            let raw = Raw(w: 1125, h: 2436)
            if ori == .portrait { return raw }
            else { return raw.flopped }
        case .iPhoneXSMax(let ori):
            let raw = Raw(w: 1242, h: 2688)
            if ori == .portrait { return raw }
            else { return raw.flopped }
        case .iPhoneXR(let ori):
            let raw = Raw(w: 828, h: 1792)
            if ori == .portrait { return raw }
            else { return raw.flopped }
        case .iPhone11(let ori):
            let raw = Raw(w: 828, h: 1792)
            if ori == .portrait { return raw }
            else { return raw.flopped }
        case .iPhone11Pro(let ori):
            let raw = Raw(w: 1125, h: 2436)
            if ori == .portrait { return raw }
            else { return raw.flopped }
        case .iPhone11ProMax(let ori):
            let raw = Raw(w: 1242, h: 2688)
            if ori == .portrait { return raw }
            else { return raw.flopped }
        case .iPad(let ori):
            let raw = Raw(w: 1536, h: 2048)
            if ori == .portrait { return raw }
            else { return raw.flopped }
        case .iPad_10_2(let ori):
            let raw = Raw(w: 1620, h: 2160)
            if ori == .portrait { return raw }
            else { return raw.flopped }
        case .iPadPro_10_5(let ori):
            let raw = Raw(w: 1668, h: 2224)
            if ori == .portrait { return raw }
            else { return raw.flopped }
        case .iPadPro_11(let ori):
            let raw = Raw(w: 1668, h: 2388)
            if ori == .portrait { return raw }
            else { return raw.flopped }
        case .iPadPro_12_9(let ori):
            let raw = Raw(w: 2048, h: 2732)
            if ori == .portrait { return raw }
            else { return raw.flopped }
        case .fullscreen:
            #if os(iOS) || os(tvOS)
            let size: CGSize = UIScreen.main.bounds.size
            let scale: CGFloat = UIScreen.main.scale
            return Raw(w: Int(size.width * scale), h: Int(size.height * scale))
            #elseif os(macOS)
            let size = NSScreen.main?.frame.size ?? Resolution._128.size.cg
            let scale = NSScreen.main?.backingScaleFactor ?? 1.0
            return Raw(w: Int(size.width * scale), h: Int(size.height * scale))
            #endif
        case .cgSize(let size): return Raw(w: Int(size.width), h: Int(size.height))
        case .size(let size): return Raw(w: Int(size.w.cg), h: Int(size.h.cg))
        case .custom(let w, let h): return Raw(w: w, h: h)
        case .square(let val): return Raw(w: val, h: val)
        case .raw(let raw): return raw
        }
    }
    
    public var w: Int {
        return raw.w
    }
    public var h: Int {
        return raw.h
    }
    
    public var count: Int {
        return raw.w * raw.h
    }

    // MARK: Size

    public var size: LiveSize {
        let raw = self.raw
        return LiveSize(w: LiveFloat(raw.w), h: LiveFloat(raw.h))
    }
    
    public static var scale: LiveFloat {
        #if os(iOS)
        return LiveFloat(UIScreen.main.nativeScale)
        #elseif os(tvOS)
        return 1.0
        #elseif os(macOS)
        return LiveFloat(NSScreen.main?.backingScaleFactor ?? 1.0)
        #endif
    }
    
    public var ppi: Int? {
        switch self {
        case .iPad, .iPad_10_2, .iPadPro_10_5, .iPadPro_11, .iPadPro_12_9: return 264
        case .iPhone, .iPhoneXR, .iPhone11: return 326
        case .iPhonePlus: return 401
        case .iPhoneX, .iPhoneXSMax, .iPhone11Pro, .iPhone11ProMax: return 458
        default: return nil
        }
    }
    
    public var width: LiveFloat {
        return size.width
    }
    public var height: LiveFloat {
        return size.height
    }
    
    public var flopped: Resolution {
        return .raw(raw.flopped)
    }
    
    // MARK: Checks
    
    public static var isiPhone: Bool {
        #if os(macOS) || targetEnvironment(macCatalyst)
        return false
        #else
        return Resolution.fullscreen == .iPhone(.landscape) || Resolution.fullscreen == .iPhone(.portrait) ||
            Resolution.fullscreen == .iPhonePlus(.landscape) || Resolution.fullscreen == .iPhonePlus(.portrait) ||
            Resolution.fullscreen == .iPhoneX(.landscape) || Resolution.fullscreen == .iPhoneX(.portrait) ||
            Resolution.fullscreen == .iPhoneXR(.landscape) || Resolution.fullscreen == .iPhoneXR(.portrait) ||
            Resolution.fullscreen == .iPhoneXSMax(.landscape) || Resolution.fullscreen == .iPhoneXSMax(.portrait) ||
            Resolution.fullscreen == .iPhone11(.landscape) || Resolution.fullscreen == .iPhone11(.portrait) ||
            Resolution.fullscreen == .iPhone11Pro(.landscape) || Resolution.fullscreen == .iPhone11Pro(.portrait) ||
            Resolution.fullscreen == .iPhone11ProMax(.landscape) || Resolution.fullscreen == .iPhone11ProMax(.portrait)
        #endif
    }
    
    public static var isiPad: Bool {
        #if os(macOS) || targetEnvironment(macCatalyst)
        return false
        #else
        return Resolution.fullscreen == .iPad(.landscape) || Resolution.fullscreen == .iPad(.portrait) ||
           Resolution.fullscreen == .iPad_10_2(.landscape) || Resolution.fullscreen == .iPad_10_2(.portrait) ||
           Resolution.fullscreen == .iPadPro_11(.landscape) || Resolution.fullscreen == .iPadPro_11(.portrait) ||
           Resolution.fullscreen == .iPadPro_10_5(.landscape) || Resolution.fullscreen == .iPadPro_10_5(.portrait) ||
           Resolution.fullscreen == .iPadPro_12_9(.landscape) || Resolution.fullscreen == .iPadPro_12_9(.portrait)
        #endif
    }
    
    public static var hasTeleCamera: Bool {
        return Resolution.fullscreen == .iPhonePlus(.landscape) || Resolution.fullscreen == .iPhonePlus(.portrait) ||
            Resolution.fullscreen == .iPhoneX(.landscape) || Resolution.fullscreen == .iPhoneX(.portrait) ||
            Resolution.fullscreen == .iPhoneXSMax(.landscape) || Resolution.fullscreen == .iPhoneXSMax(.portrait) ||
            Resolution.fullscreen == .iPhone11Pro(.landscape) || Resolution.fullscreen == .iPhone11Pro(.portrait) ||
            Resolution.fullscreen == .iPhone11ProMax(.landscape) || Resolution.fullscreen == .iPhone11ProMax(.portrait)
    }
    
    public static var hasSuperWideCamera: Bool {
        return Resolution.fullscreen == .iPhone11(.landscape) || Resolution.fullscreen == .iPhone11(.portrait) ||
            Resolution.fullscreen == .iPhone11Pro(.landscape) || Resolution.fullscreen == .iPhone11Pro(.portrait) ||
            Resolution.fullscreen == .iPhone11ProMax(.landscape) || Resolution.fullscreen == .iPhone11ProMax(.portrait)
    }
    
    // MARK: - Aspect
    
    public var aspect: LiveFloat {
        return size.width / size.height
    }
    
    public enum AspectPlacement {
        case fit
        case fill
    }
    
    public func aspectResolution(to aspectPlacement: AspectPlacement, in res: Resolution) -> Resolution {
        var comboAspect = aspect.cg / res.aspect.cg
        if aspect.cg < res.aspect.cg {
            comboAspect = 1 / comboAspect
        }
        let width: CGFloat
        let height: CGFloat
        switch aspectPlacement {
        case .fit:
            width = aspect.cg >= res.aspect.cg ? res.width.cg : res.width.cg / comboAspect
            height = aspect.cg <= res.aspect.cg ? res.height.cg : res.height.cg / comboAspect
        case .fill:
            width = aspect.cg <= res.aspect.cg ? res.width.cg : res.width.cg * comboAspect
            height = aspect.cg >= res.aspect.cg ? res.height.cg : res.height.cg * comboAspect
        }
        return .cgSize(CGSize(width: width, height: height))
    }
    public func aspectBounds(to aspectPlacement: AspectPlacement, in res: Resolution) -> CGRect {
        let aRes = aspectResolution(to: aspectPlacement, in: res)
        return CGRect(x: 0, y: 0, width: aRes.width.cg / Resolution.scale.cg, height: aRes.height.cg / Resolution.scale.cg)
    }
    
    // MARK: - Life Cycle
    
    public init(size: CGSize) {
        switch size {
        case Resolution._540p.size.cg: self = ._540p
        case Resolution._720p.size.cg: self = ._720p
        case Resolution._1080p.size.cg: self = ._1080p
        case Resolution._4K.size.cg: self = ._4K
        case Resolution._8K.size.cg: self = ._8K
        case Resolution.fullHD(.portrait).size.cg: self = .fullHD(.portrait)
        case Resolution.fullHD(.landscape).size.cg: self = .fullHD(.landscape)
        case Resolution.ultraHD(.portrait).size.cg: self = .ultraHD(.portrait)
        case Resolution.ultraHD(.landscape).size.cg: self = .ultraHD(.landscape)
        case Resolution._128.size.cg: self = ._128
        case Resolution._256.size.cg: self = ._256
        case Resolution._512.size.cg: self = ._512
        case Resolution._1024.size.cg: self = ._1024
        case Resolution._2048.size.cg: self = ._2048
        case Resolution._4096.size.cg: self = ._4096
        case Resolution._8192.size.cg: self = ._8192
        case Resolution._16384.size.cg: self = ._16384
        case Resolution.iPhone(.portrait).size.cg: self = .iPhone(.portrait)
        case Resolution.iPhone(.landscape).size.cg: self = .iPhone(.landscape)
        case Resolution.iPhonePlus(.portrait).size.cg: self = .iPhonePlus(.portrait)
        case Resolution.iPhonePlus(.landscape).size.cg: self = .iPhonePlus(.landscape)
        case Resolution.iPhoneX(.portrait).size.cg: self = .iPhoneX(.portrait)
        case Resolution.iPhoneX(.landscape).size.cg: self = .iPhoneX(.landscape)
        case Resolution.iPhoneXR(.portrait).size.cg: self = .iPhoneXR(.portrait)
        case Resolution.iPhoneXR(.landscape).size.cg: self = .iPhoneXR(.landscape)
        case Resolution.iPhone11(.portrait).size.cg: self = .iPhone11(.portrait)
        case Resolution.iPhone11(.landscape).size.cg: self = .iPhone11(.landscape)
        case Resolution.iPhone11Pro(.portrait).size.cg: self = .iPhone11Pro(.portrait)
        case Resolution.iPhone11Pro(.landscape).size.cg: self = .iPhone11Pro(.landscape)
        case Resolution.iPhone11ProMax(.portrait).size.cg: self = .iPhone11ProMax(.portrait)
        case Resolution.iPhone11ProMax(.landscape).size.cg: self = .iPhone11ProMax(.landscape)
        case Resolution.iPad(.portrait).size.cg: self = .iPad(.portrait)
        case Resolution.iPad(.landscape).size.cg: self = .iPad(.landscape)
        case Resolution.iPad_10_2(.portrait).size.cg: self = .iPad_10_2(.portrait)
        case Resolution.iPad_10_2(.landscape).size.cg: self = .iPad_10_2(.landscape)
        case Resolution.iPadPro_10_5(.portrait).size.cg: self = .iPadPro_10_5(.portrait)
        case Resolution.iPadPro_10_5(.landscape).size.cg: self = .iPadPro_10_5(.landscape)
        case Resolution.iPadPro_11(.portrait).size.cg: self = .iPadPro_11(.portrait)
        case Resolution.iPadPro_11(.landscape).size.cg: self = .iPadPro_11(.landscape)
        case Resolution.iPadPro_12_9(.portrait).size.cg: self = .iPadPro_12_9(.portrait)
        case Resolution.iPadPro_12_9(.landscape).size.cg: self = .iPadPro_12_9(.landscape)
        case Resolution.fullscreen.size.cg: self = .fullscreen
        default: self = .custom(w: Int(size.width), h: Int(size.height))
        }
    }
    
    public init(autoScaleSize: CGSize) {
        self.init(size: CGSize(width: autoScaleSize.width * Resolution.scale.cg, height: autoScaleSize.height * Resolution.scale.cg))
    }
    
    public init(_ raw: Raw) {
        let rawSize = CGSize(width: raw.w, height: raw.h)
        self.init(size: rawSize)
    }
    
    #if os(iOS) || os(tvOS)
    public init(image: UIImage) {
        let nativeSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        self.init(size: nativeSize)
    }
    #elseif os(macOS)
    public init(image: NSImage) {
        let size = CGSize(width: image.size.width, height: image.size.height)
        self.init(size: size)
    }
    #endif
    
    public init(pixelBuffer: CVPixelBuffer) {
        let imageSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        self.init(size: imageSize)
    }
    
    public init(texture: MTLTexture) {
        let textureSize = CGSize(width: CGFloat(texture.width), height: CGFloat(texture.height))
        self.init(size: textureSize)
    }
    
    // MARK: - Codable
    
    enum ResolutionCodingKey: CodingKey {
        case width
        case height
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ResolutionCodingKey.self)
        let w: Int = try container.decode(Int.self, forKey: .width)
        let h: Int = try container.decode(Int.self, forKey: .height)
        let size: CGSize = CGSize(width: w, height: h)
        self = Resolution(size: size)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ResolutionCodingKey.self)
        try container.encode(w, forKey: .width)
        try container.encode(h, forKey: .height)
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(w)
        hasher.combine(h)
    }
    
    // MARK: - Re Res
    
    public enum ImagePlacement {
        case fill
        case fit
    }
    
    public func reRes(in inRes: Resolution, _ placement: ImagePlacement = .fit) -> Resolution {
        switch placement {
        case .fit:
            return Resolution.raw(Raw(
                w: Int((width / inRes.width > height / inRes.height <?>
                    inRes.width <=> width * (inRes.height / height)).cg),
                h: Int((width / inRes.width < height / inRes.height <?>
                    inRes.height <=> height * (inRes.width / width)).cg)
            ))
        case .fill:
            return Resolution.raw(Raw(
                w: Int((width / inRes.width < height / inRes.height <?>
                    inRes.width <=> width * (inRes.height / height)).cg),
                h: Int((width / inRes.width > height / inRes.height <?>
                    inRes.height <=> height * (inRes.width / width)).cg)
            ))
        }
    }
    
    // MARK: - Operator Overloads
    
    public static func ==(lhs: Resolution, rhs: Resolution) -> Bool {
        return lhs.w == rhs.w && lhs.h == rhs.h
    }
    public static func !=(lhs: Resolution, rhs: Resolution) -> Bool {
        return !(lhs == rhs)
    }
    
    public static func >(lhs: Resolution, rhs: Resolution) -> Bool? {
        let w = lhs.w > rhs.w
        let h = lhs.h > rhs.h
        return w == h ? w : nil
    }
    public static func <(lhs: Resolution, rhs: Resolution) -> Bool? {
        let w = lhs.w < rhs.w
        let h = lhs.h < rhs.h
        return w == h ? w : nil
    }
    public static func >=(lhs: Resolution, rhs: Resolution) -> Bool? {
        let w = lhs.w >= rhs.w
        let h = lhs.h >= rhs.h
        return w == h ? w : nil
    }
    public static func <=(lhs: Resolution, rhs: Resolution) -> Bool? {
        let w = lhs.w <= rhs.w
        let h = lhs.h <= rhs.h
        return w == h ? w : nil
    }
    
    public static func +(lhs: Resolution, rhs: Resolution) -> Resolution {
        return Resolution(Raw(w: lhs.w + rhs.w, h: lhs.h + rhs.h))
    }
    public static func -(lhs: Resolution, rhs: Resolution) -> Resolution {
        return Resolution(Raw(w: lhs.w - rhs.w, h: lhs.h - rhs.h))
    }
    public static func *(lhs: Resolution, rhs: Resolution) -> Resolution {
        return Resolution(Raw(w: Int(lhs.width.cg * rhs.width.cg), h: Int(lhs.height.cg * rhs.height.cg)))
    }
    public static func /(lhs: Resolution, rhs: Resolution) -> Resolution {
        return Resolution(Raw(w: Int(lhs.width.cg / rhs.width.cg), h: Int(lhs.height.cg / rhs.height.cg)))
    }
    
    public static func +(lhs: Resolution, rhs: CGFloat) -> Resolution {
        return Resolution(Raw(w: lhs.w + Int(rhs), h: lhs.h + Int(rhs)))
    }
    public static func -(lhs: Resolution, rhs: CGFloat) -> Resolution {
        return Resolution(Raw(w: lhs.w - Int(rhs), h: lhs.h - Int(rhs)))
    }
    public static func *(lhs: Resolution, rhs: CGFloat) -> Resolution {
        return Resolution(Raw(w: Int(round(lhs.width.cg * rhs)), h: Int(round(lhs.height.cg * rhs))))
    }
    public static func /(lhs: Resolution, rhs: CGFloat) -> Resolution {
        return Resolution(Raw(w: Int(round(lhs.width.cg / rhs)), h: Int(round(lhs.height.cg / rhs))))
    }
    public static func +(lhs: CGFloat, rhs: Resolution) -> Resolution {
        return rhs + lhs
    }
    public static func -(lhs: CGFloat, rhs: Resolution) -> Resolution {
        return (rhs - lhs) * CGFloat(-1.0)
    }
    public static func *(lhs: CGFloat, rhs: Resolution) -> Resolution {
        return rhs * lhs
    }
    
    public static func +(lhs: Resolution, rhs: Int) -> Resolution {
        return Resolution(Raw(w: lhs.w + Int(rhs), h: lhs.h + Int(rhs)))
    }
    public static func -(lhs: Resolution, rhs: Int) -> Resolution {
        return Resolution(Raw(w: lhs.w - Int(rhs), h: lhs.h - Int(rhs)))
    }
    public static func *(lhs: Resolution, rhs: Int) -> Resolution {
        return Resolution(Raw(w: Int(round(lhs.width.cg * CGFloat(rhs))), h: Int(round(lhs.height.cg * CGFloat(rhs)))))
    }
    public static func /(lhs: Resolution, rhs: Int) -> Resolution {
        return Resolution(Raw(w: Int(round(lhs.width.cg / CGFloat(rhs))), h: Int(round(lhs.height.cg / CGFloat(rhs)))))
    }
    public static func +(lhs: Int, rhs: Resolution) -> Resolution {
        return rhs + lhs
    }
    public static func -(lhs: Int, rhs: Resolution) -> Resolution {
        return (rhs - lhs) * Int(-1)
    }
    public static func *(lhs: Int, rhs: Resolution) -> Resolution {
        return rhs * lhs
    }
    
    public static func +(lhs: Resolution, rhs: Double) -> Resolution {
        return Resolution(Raw(w: lhs.w + Int(rhs), h: lhs.h + Int(rhs)))
    }
    public static func -(lhs: Resolution, rhs: Double) -> Resolution {
        return Resolution(Raw(w: lhs.w - Int(rhs), h: lhs.h - Int(rhs)))
    }
    public static func *(lhs: Resolution, rhs: Double) -> Resolution {
        return Resolution(Raw(w: Int(round(lhs.width.cg * CGFloat(rhs))), h: Int(round(lhs.height.cg * CGFloat(rhs)))))
    }
    public static func /(lhs: Resolution, rhs: Double) -> Resolution {
        return Resolution(Raw(w: Int(round(lhs.width.cg / CGFloat(rhs))), h: Int(round(lhs.height.cg / CGFloat(rhs)))))
    }
    public static func +(lhs: Double, rhs: Resolution) -> Resolution {
        return rhs + lhs
    }
    public static func -(lhs: Double, rhs: Resolution) -> Resolution {
        return (rhs - lhs) * Double(-1.0)
    }
    public static func *(lhs: Double, rhs: Resolution) -> Resolution {
        return rhs * lhs
    }
    
    public static func +(lhs: Resolution, rhs: LiveFloat) -> Resolution {
        return Resolution(Raw(w: lhs.w + Int(rhs.cg), h: lhs.h + Int(rhs.cg)))
    }
    public static func -(lhs: Resolution, rhs: LiveFloat) -> Resolution {
        return Resolution(Raw(w: lhs.w - Int(rhs.cg), h: lhs.h - Int(rhs.cg)))
    }
    public static func *(lhs: Resolution, rhs: LiveFloat) -> Resolution {
        return Resolution(Raw(w: Int(round(lhs.width.cg * rhs.cg)), h: Int(round(lhs.height.cg * rhs.cg))))
    }
    public static func /(lhs: Resolution, rhs: LiveFloat) -> Resolution {
        return Resolution(Raw(w: Int(round(lhs.width.cg / rhs.cg)), h: Int(round(lhs.height.cg / rhs.cg))))
    }
    public static func +(lhs: LiveFloat, rhs: Resolution) -> Resolution {
        return rhs + lhs
    }
    public static func -(lhs: LiveFloat, rhs: Resolution) -> Resolution {
        return (rhs - lhs) * LiveFloat(-1.0)
    }
    public static func *(lhs: LiveFloat, rhs: Resolution) -> Resolution {
        return rhs * lhs
    }
    
}

#if os(iOS) || os(tvOS)
public typealias _Image = UIImage
#elseif os(macOS)
public typealias _Image = NSImage
#endif

public extension _Image {
    var resolution: Resolution { .cgSize(size) * LiveFloat(scale) }
}
