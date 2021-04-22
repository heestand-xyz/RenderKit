//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-04-22.
//

import CoreGraphics

@propertyWrapper public class LiveSize: LiveWrap {
    
    public var wrappedValue: CGSize {
        didSet {
            guard wrappedValue != oldValue else { return }
            guard let node: NODE = node else {
                print("RenderKit Live property wrapper not linked to node.")
                return
            }
            node.render()
        }
    }
    
    public init(wrappedValue: CGSize, _ typeName: String, name: String? = nil) {
        self.wrappedValue = wrappedValue
        super.init(type: .size, typeName: typeName, name: name, value: wrappedValue, min: CGSize(width: 0.0, height: 0.0), max: CGSize(width: 2.0, height: 2.0))
        get = { self.wrappedValue }
        set = { self.wrappedValue = $0 as! CGSize }
        setFloats = { self.wrappedValue = CGSize(floats: $0) }
    }

}
