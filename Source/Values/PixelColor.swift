//
//  PixelColor.swift
//  
//
//  Created by Anton Heestand on 2021-01-02.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif
import SwiftUI

public struct PixelColor: Floatable {
    
    public var red: CGFloat
    public var green: CGFloat
    public var blue: CGFloat
    public var alpha: CGFloat
    
    @available(*, deprecated, renamed: "red")
    public var r: CGFloat { red }
    @available(*, deprecated, renamed: "green")
    public var g: CGFloat { green }
    @available(*, deprecated, renamed: "blue")
    public var b: CGFloat { blue }
    @available(*, deprecated, renamed: "alpha")
    public var a: CGFloat { alpha }

    public static var clear: PixelColor       { return PixelColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0) }
    public static var clearWhite: PixelColor  { return PixelColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0) }

    public static var white: PixelColor       { return PixelColor(white: 1.0) }
    public static var lightGray: PixelColor   { return PixelColor(white: 0.75) }
    public static var gray: PixelColor        { return PixelColor(white: 0.5) }
    public static var darkGray: PixelColor    { return PixelColor(white: 0.25) }
    public static var black: PixelColor       { return PixelColor(white: 0.0) }
    
    public static var red: PixelColor         { return PixelColor(red: 1.0, green: 0.0, blue: 0.0) }
    public static var orange: PixelColor      { return PixelColor(red: 1.0, green: 0.5, blue: 0.0) }
    public static var yellow: PixelColor      { return PixelColor(red: 1.0, green: 1.0, blue: 0.0) }
    public static var green: PixelColor       { return PixelColor(red: 0.0, green: 1.0, blue: 0.0) }
    public static var cyan: PixelColor        { return PixelColor(red: 0.0, green: 1.0, blue: 1.0) }
    public static var blue: PixelColor        { return PixelColor(red: 0.0, green: 0.0, blue: 1.0) }
    public static var magenta: PixelColor     { return PixelColor(red: 1.0, green: 0.0, blue: 1.0) }
    
    #if os(macOS)
    public var nsColor: NSColor {
        NSColor(displayP3Red: red, green: green, blue: blue, alpha: alpha)
    }
    #else
    public var uiColor: UIColor {
        UIColor(displayP3Red: red, green: green, blue: blue, alpha: alpha)
    }
    #endif
    
    public var color: Color {
        #if os(macOS)
        return Color(nsColor)
        #else
        return Color(uiColor)
        #endif
    }
    
    public var components: [CGFloat] {
        return [red, green, blue, alpha]
    }
    public var floats: [CGFloat] { components }
    
    public var ciColor: CIColor {
        CIColor(red: red, green: green, blue: blue, alpha: alpha, colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!) ?? .clear
    }
    public var cgColor: CGColor {
        CGColor(colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!, components: components) ?? CGColor(gray: 0.0, alpha: 0.0)
    }
    
    public var brightness: CGFloat {
        (red + green + blue) / 3.0
    }
    
    public var monochrome: PixelColor {
        PixelColor(red: brightness, green: brightness, blue: brightness, alpha: alpha)
    }
    
    // MARK: Life Cycle
    
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    public init(white: CGFloat, alpha: CGFloat = 1.0) {
        red = white
        green = white
        blue = white
        self.alpha = alpha
    }
    
    public init(red255: Int, green255: Int, blue255: Int, alpha255: Int = 255) {
        red = CGFloat(red255) / 255
        green = CGFloat(green255) / 255
        blue = CGFloat(blue255) / 255
        alpha = CGFloat(alpha255) / 255
    }
    
    #if os(iOS) || os(tvOS)
    public init(_ uiColor: UIColor) {
        let ciColor = CIColor(color: uiColor)
        red = ciColor.red
        green = ciColor.green
        blue = ciColor.blue
        alpha = ciColor.alpha
    }
    #endif

    #if os(macOS)
    public init(_ nsColor: NSColor) {
        let ciColor = CIColor(color: nsColor)
        red = ciColor?.red ?? 0.0
        green = ciColor?.green ?? 0.0
        blue = ciColor?.blue ?? 0.0
        alpha = ciColor?.alpha ?? 0.0
    }
    #endif
    
    @available(*, deprecated, renamed: "init(red:green:blue:alpha:)")
    public init(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1.0) {
        self.init(red: r, green: g, blue: b, alpha: a)
    }
    
    // MARK: - Hue Saturaton Brightness
    
    typealias HSV = (h: CGFloat, s: CGFloat, v: CGFloat)
    typealias RGB = (r: CGFloat, g: CGFloat, b: CGFloat)
    
    public var hue: CGFloat {
        hsv().h
    }
    public var saturation: CGFloat {
        hsv().s
    }
    func hsv() -> (h: CGFloat, s: CGFloat, v: CGFloat) {
        let r: CGFloat = red
        let g: CGFloat = green
        let b: CGFloat = blue
        var h, s, v: CGFloat
        var mn, mx, d: CGFloat
        mn = r < g ? r : g
        mn = mn < b ? mn : b
        mx = r > g ? r : g
        mx = mx > b ? mx : b
        v = mx
        d = mx - mn
        if (d < 0.00001) {
            s = 0
            h = 0
            return (h: h, s: s, v: v)
        }
        if mx > 0.0 {
            s = d / mx
        } else {
            s = 0.0
            h = 0.0
            return (h: h, s: s, v: v)
        }
        if r >= mx {
            h = (g - b) / d
        } else if g >= mx {
            h = 2.0 + (b - r) / d
        } else {
            h = 4.0 + (r - g) / d
        }
        h *= 60.0
        if h < 0.0 {
            h += 360.0
        }
        h /= 360.0
        return (h: h, s: s, v: v)
    }
    
    public init(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat = 1.0) {
        let color = PixelColor.rgb(h: hue, s: saturation, v: brightness)
        red = color.r
        green = color.g
        blue = color.b
        self.alpha = alpha
    }
    
    static func rgb(hsv: HSV) -> RGB {
        rgb(h: hsv.h, s: hsv.s, v: hsv.v)
    }
    static func rgb(h: CGFloat, s: CGFloat, v: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        var hh, p, q, t, ff: CGFloat
        var i: Int
        if (s <= 0.0) {
            r = v
            g = v
            b = v
            return  (r: r, g: g, b: b)
        }
        hh = (h - floor(h)) * 360
        hh = hh / 60.0
        i = Int(hh)
        ff = hh - CGFloat(i)
        p = v * (1.0 - s)
        q = v * (1.0 - (s * ff))
        t = v * (1.0 - (s * (1.0 - ff)))
        switch(i) {
        case 0:
            r = v
            g = t
            b = p
        case 1:
            r = q
            g = v
            b = p
        case 2:
            r = p
            g = v
            b = t
        case 3:
            r = p
            g = q
            b = v
        case 4:
            r = t
            g = p
            b = v
        case 5:
            r = v
            g = p
            b = q
        default:
            r = v
            g = p
            b = q
        }
        return (r: r, g: g, b: b)
    }
    
    // MARK: - Hex
    
    public var hex: String {
        let hexInt: Int = (Int)(CGFloat(red)*255)<<16 | (Int)(CGFloat(green)*255)<<8 | (Int)(CGFloat(blue)*255)<<0
        return String(format:"#%06x", hexInt)
    }
    
    public init(hex: String, a: CGFloat = 1) {
        var hex = hex
        if hex[0..<1] == "#" {
            if hex.count == 4 {
                hex = hex[1..<4]
            } else {
                hex = hex[1..<7]
            }
        }
        if hex.count == 3 {
            let r = hex[0..<1]
            let g = hex[1..<2]
            let b = hex[2..<3]
            hex = r + r + g + g + b + b
        }
        var hexInt: UInt64 = 0
        let scanner: Scanner = Scanner(string: hex)
        scanner.scanHexInt64(&hexInt)
        red = CGFloat((hexInt & 0xff0000) >> 16) / 255.0
        green = CGFloat((hexInt & 0xff00) >> 8) / 255.0
        blue = CGFloat((hexInt & 0xff) >> 0) / 255.0
        alpha = a
    }
    
    // MARK: - Channel
    /// Used by ChannelMixPIX
    
    public enum Channel {
        case red
        case green
        case blue
        case alpha
        var color: PixelColor {
            switch self {
            case .red:   return .init(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.0)
            case .green: return .init(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.0)
            case .blue:  return .init(red: 0.0, green: 0.0, blue: 1.0, alpha: 0.0)
            case .alpha: return .init(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
            }
        }
    }
    
    public var isPureChannel: Bool {
        let oneCount: Int = (red == 1.0 ? 1 : 0) + (green == 1.0 ? 1 : 0) + (blue == 1.0 ? 1 : 0) + (alpha == 1.0 ? 1 : 0)
        let zeroCount: Int = (red == 0.0 ? 1 : 0) + (green == 0.0 ? 1 : 0) + (blue == 0.0 ? 1 : 0) + (alpha == 0.0 ? 1 : 0)
        return oneCount == 1 && zeroCount == 3
    }
    
    public var pureChannel: Channel? {
        guard Bool(isPureChannel) else { return nil }
        if CGFloat(red) == 1.0 {
            return .red
        } else if CGFloat(green) == 1.0 {
            return .green
        } else if CGFloat(blue) == 1.0 {
            return .blue
        } else if CGFloat(alpha) == 1.0 {
            return .alpha
        } else { return nil }
    }
    
    public init(channel: Channel) {
        red = 0
        green = 0
        blue = 0
        alpha = 0
        switch channel {
        case .red:
            red = 1
        case .green:
            green = 1
        case .blue:
            blue = 1
        case .alpha:
            alpha = 1
        }
    }
    
    // MARK: - Functions
    
    public func withAlpha(of alpha: CGFloat) -> PixelColor {
        return PixelColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    public func withHue(of hue: CGFloat) -> PixelColor {
        return PixelColor(hue: hue, saturation: saturation, brightness: brightness)
    }
    public func withSaturation(of saturation: CGFloat) -> PixelColor {
        return PixelColor(hue: hue, saturation: saturation, brightness: brightness)
    }
    public func withBrightness(of brightness: CGFloat) -> PixelColor {
        return PixelColor(hue: hue, saturation: saturation, brightness: brightness)
    }
    
    public func withShiftedHue(by hueShift: CGFloat) -> PixelColor {
        return PixelColor(hue: (hue + hueShift).remainder(dividingBy: 1.0), saturation: saturation, brightness: brightness)
    }
    
}
