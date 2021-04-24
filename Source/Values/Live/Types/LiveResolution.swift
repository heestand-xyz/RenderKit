//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-04-22.
//

import Foundation
import Resolution

@propertyWrapper public class LiveResolution: LiveWrap {
    
    public var wrappedValue: Resolution {
        didSet {
            guard wrappedValue != oldValue else { return }
            guard let node: NODE = node else {
                print("RenderKit Live property wrapper not linked to node.")
                return
            }
            node.applyResolution {
                node.render()
            }
        }
    }
    
    public init(wrappedValue: Resolution, _ typeName: String, name: String? = nil) {
        self.wrappedValue = wrappedValue
        super.init(type: .resolution, typeName: typeName, name: name, value: wrappedValue, min: 1, max: 3_840)
        get = { self.wrappedValue }
        set = { self.wrappedValue = $0 as! Resolution }
        setFloats = { self.wrappedValue = Resolution(floats: $0) }
    }

}
