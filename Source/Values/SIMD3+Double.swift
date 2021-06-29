//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-06-28.
//

import CoreGraphics
import simd

extension SIMD3: Floatable where Scalar == Double {
    
    public var floats: [CGFloat] {
        [CGFloat(x), CGFloat(y), CGFloat(z)]
    }
    
    public init(floats: [CGFloat]) {
        guard floats.count == 3 else {
            self = SIMD3<Double>(x: 0.0, y: 0.0, z: 0.0)
            return
        }
        self = SIMD3<Double>(x: floats[0], y: floats[1], z: floats[2])
    }
    
}
