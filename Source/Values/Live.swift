import Foundation

@propertyWrapper public struct Live<CV: CoreValue> {
    
    public var node: NODE?
    
    public var wrappedValue: CV {
        didSet {
            guard let node: NODE = node else {
                print("RenderKit Live property wrapper not linked to node.")
                return
            }
            node.setNeedsRender()
        }
    }
    
    public init(wrappedValue: CV) {
        self.wrappedValue = wrappedValue
    }

}

