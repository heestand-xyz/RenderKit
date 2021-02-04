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
    
    public static func == (lhs: PixelColor, rhs: PixelColor) -> Bool {
        lhs.red == rhs.red && lhs.green == rhs.green && lhs.blue == rhs.blue && lhs.alpha == rhs.alpha 
    }

}

extension PixelColor.Channel: Floatable {
    
    public var floats: [CGFloat] { [CGFloat(rawValue)] }

}
