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

extension PixelColor.Channel: Floatable {
    
    public var floats: [CGFloat] { [CGFloat(rawValue)] }

    public init(floats: [CGFloat]) {
        guard let float: CGFloat = floats.first else {
            self = .red
            return
        }
        let int: Int = Int(float)
        self = PixelColor.Channel(rawValue: int) ?? .red
    }
    
}
