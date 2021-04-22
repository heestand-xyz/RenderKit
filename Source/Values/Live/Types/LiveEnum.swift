//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-04-22.
//

import Foundation

@propertyWrapper public class LiveEnum<E: Enumable>: LiveEnumWrap {
    
    let updateResolution: Bool
    
    public var wrappedValue: E {
        didSet {
            guard wrappedValue.index != oldValue.index else { return }
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
    
    public init(wrappedValue: E, _ typeName: String, name: String? = nil, updateResolution: Bool = false) {
        self.updateResolution = updateResolution
        self.wrappedValue = wrappedValue
        super.init(typeName, name: name, rawIndex: wrappedValue.rawIndex, rawIndices: E.allCases.map(\.rawIndex), names: E.names)
        get = { self.wrappedValue.rawIndex }
        set = { self.wrappedValue = E(rawIndex: $0 as! Int) }
        setFloats = { self.wrappedValue = E(rawIndex: Int(floats: $0)) }
    }

}
