import Foundation

public class LiveProp {
    public var node: NODE!
    var getFloatable: () -> Floatable
    public var floatable: Floatable { getFloatable() }
    internal init(get getFloatable: @escaping () -> Floatable) {
        self.getFloatable = getFloatable
    }
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
        super.init(get: { wrappedValue })
    }

}

//@propertyWrapper public class LiveArray<F: Floatable>: LiveProp {
//
//    public var wrappedValue: [F] {
//        didSet {
//            guard let node: NODE = node else {
//                print("RenderKit Live property wrapper not linked to node.")
//                return
//            }
//            node.setNeedsRender()
//        }
//    }
//
//    public init(wrappedValue: [F]) {
//        self.wrappedValue = wrappedValue
//        super.init(get: { wrappedValue })
//    }
//
//}
