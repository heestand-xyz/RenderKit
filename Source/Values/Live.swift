import Foundation

public class LiveProp {
    public var node: NODE!
    var getCoreValue: () -> CoreValue
    public var coreValue: CoreValue { getCoreValue() }
    internal init(_ getCoreValue: @escaping () -> CoreValue) {
        self.getCoreValue = getCoreValue
    }
}

@propertyWrapper public class Live<CV: CoreValue>: LiveProp {
    
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
        super.init({ wrappedValue })
    }

}

