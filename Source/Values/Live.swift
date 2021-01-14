import Foundation

public class LiveProp {
    public var node: NODE!
}

@propertyWrapper public class Live<F: Floatable>: LiveProp {
    
    public var wrappedValue: F {
        didSet {
            guard let node: NODE = node else {
                print("RenderKit Live property wrapper not linked to node.")
                return
            }
            node.setNeedsRender()
        }
    }
    
    public init(wrappedValue: F) {
        self.wrappedValue = wrappedValue
    }

}
