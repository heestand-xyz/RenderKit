//
//  PixelColor.swift
//  
//
//  Created by Anton Heestand on 2021-01-02.
//

import CoreGraphics
import PixelColor

extension PixelColor: Floatable {
    
    public var floats: [CGFloat] { components }
    
    public init(floats: [CGFloat]) {
        guard floats.count == 4 else {
            self = .clear
            return
        }
        self = PixelColor(red: floats[0], green: floats[1], blue: floats[2], alpha: floats[3])
    }
    
}

extension PixelColor.Channel: Enumable {
    
    public static var allCases: [PixelColor.Channel] {
        [.red, .green, .blue, .alpha]
    }
    
    public var index: Int { rawValue }
    
    public var typeName: String {
        switch self {
        case .red:
            return "red"
        case .green:
            return "green"
        case .blue:
            return "blue"
        case .alpha:
            return "alpha"
        }
    }
    
    public var name: String {
        switch self {
        case .red:
            return "Red"
        case .green:
            return "Green"
        case .blue:
            return "Blue"
        case .alpha:
            return "Alpha"
        }
    }
    
}
