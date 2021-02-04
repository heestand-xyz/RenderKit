import Foundation

public class LiveWrap {
    public var node: NODE!
}

@propertyWrapper public class Live<F: Floatable>: LiveWrap {
    
    public var wrappedValue: F {
        didSet {
            guard wrappedValue.floats != oldValue.floats else { return }
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

@propertyWrapper public class LiveResolution<F: Floatable>: LiveWrap {
    
    public var wrappedValue: F {
        didSet {
            guard let node: NODE = node else {
                print("RenderKit LiveResolution property wrapper not linked to node.")
                return
            }
            node.applyResolution {
                node.setNeedsRender()
            }
        }
    }
    
    public init(wrappedValue: F) {
        self.wrappedValue = wrappedValue
    }

}

