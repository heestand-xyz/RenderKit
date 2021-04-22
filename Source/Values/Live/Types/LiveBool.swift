//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-04-22.
//

import Foundation

@propertyWrapper public class LiveBool: LiveWrap {
    
    let updateResolution: Bool
    
    public var wrappedValue: Bool {
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
    
    public init(wrappedValue: Bool, _ typeName: String, name: String? = nil, updateResolution: Bool = false) {
        self.wrappedValue = wrappedValue
        self.updateResolution = updateResolution
        super.init(type: .bool, typeName: typeName, name: name, value: wrappedValue)
        get = { self.wrappedValue }
        set = { self.wrappedValue = $0 as! Bool }
        setFloats = { self.wrappedValue = Bool(floats: $0) }
    }

}
