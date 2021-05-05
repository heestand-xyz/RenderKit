//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-04-22.
//

import Foundation

@propertyWrapper public class LiveInt: LiveWrap {
    
    let updateResolution: Bool
    
    public var wrappedValue: Int {
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
    
    public init(wrappedValue: Int, _ typeName: String, name: String? = nil, range: ClosedRange<Int>, updateResolution: Bool = false) {
        self.wrappedValue = wrappedValue
        self.updateResolution = updateResolution
        super.init(type: .int, typeName: typeName, name: name, value: wrappedValue, min: range.lowerBound, max: range.upperBound)
        get = { self.wrappedValue }
        set = { self.wrappedValue = $0 as! Int }
        setFloats = { self.wrappedValue = Int(floats: $0) }
    }

}