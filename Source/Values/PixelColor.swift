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

}

extension PixelColor.Channel: Floatable {
    
    public var floats: [CGFloat] { [CGFloat(rawValue)] }

}
