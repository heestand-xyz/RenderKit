//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-04-22.
//

import PixelColor

@propertyWrapper public class LiveColor: LiveWrap {
    
    public var wrappedValue: PixelColor {
        didSet {
            guard wrappedValue.components != oldValue.components else { return }
            guard let node: NODE = node else {
                print("RenderKit Live property wrapper not linked to node.")
                return
            }
            node.render()
        }
    }
    
    public init(wrappedValue: PixelColor, _ typeName: String, name: String? = nil) {
        self.wrappedValue = wrappedValue
        super.init(type: .color, typeName: typeName, name: name, value: wrappedValue)
        get = { self.wrappedValue }
        set = { self.wrappedValue = $0 as! PixelColor }
        setFloats = { self.wrappedValue = PixelColor(floats: $0) }
    }

}
