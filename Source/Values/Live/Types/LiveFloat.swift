//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-04-22.
//

import CoreGraphics

@propertyWrapper public class LiveFloat: LiveWrap {
    
    let updateResolution: Bool
    
    public var wrappedValue: CGFloat {
        didSet {
            guard wrappedValue != oldValue else { return }
            guard let node: NODE = node else {
                print("RenderKit Live property wrapper not linked to node.")
                return
            }
            if updateResolution {
                node.applyResolution {
                    node.render()
                }
            } else {
                node.render()
            }
        }
    }
    
    public init(wrappedValue: CGFloat, _ typeName: String, name: String? = nil, range: ClosedRange<CGFloat> = 0.0...1.0, increment: CGFloat = 0.25, updateResolution: Bool = false) {
        self.wrappedValue = wrappedValue
        self.updateResolution = updateResolution
        super.init(type: .float, typeName: typeName, name: name, value: wrappedValue, min: range.lowerBound, max: range.upperBound, inc: increment)
        get = { self.wrappedValue }
        set = { self.wrappedValue = $0 as! CGFloat }
        setFloats = { self.wrappedValue = CGFloat(floats: $0) }
    }

}
