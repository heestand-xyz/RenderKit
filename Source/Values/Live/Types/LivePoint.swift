//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-04-22.
//

import CoreGraphics

@propertyWrapper public class LivePoint: LiveWrap {
    
    public var wrappedValue: CGPoint {
        didSet {
            guard wrappedValue != oldValue else { return }
            guard let node: NODE = node else {
                print("RenderKit Live property wrapper not linked to node.")
                return
            }
            node.render()
        }
    }
    
    public init(wrappedValue: CGPoint, _ typeName: String, name: String? = nil) {
        self.wrappedValue = wrappedValue
        super.init(type: .point, typeName: typeName, name: name, value: wrappedValue, min: CGPoint(x: -1.0, y: -1.0), max: CGPoint(x: 1.0, y: 1.0))
        get = { self.wrappedValue }
        set = { self.wrappedValue = $0 as! CGPoint }
        setFloats = { self.wrappedValue = CGPoint(floats: $0) }
    }

}
