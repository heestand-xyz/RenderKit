import Foundation
import PixelColor
import CoreGraphics

@propertyWrapper public class Live<F: Floatable>: LiveWrap {
    
    let updateResolution: Bool
    
    public var wrappedValue: F {
        didSet {
            guard wrappedValue.floats != oldValue.floats else { return }
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
    
    public init(wrappedValue: F, _ typeName: String, name: String? = nil, updateResolution: Bool = false) {
        self.wrappedValue = wrappedValue
        self.updateResolution = updateResolution
        super.init(typeName: typeName, name: name, value: wrappedValue)
        get = { self.wrappedValue }
        set = { self.wrappedValue = $0 as! F }
        setFloats = { self.wrappedValue = F(floats: $0) }
    }

}
