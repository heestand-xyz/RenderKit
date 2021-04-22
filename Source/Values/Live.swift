import Foundation
import PixelColor
import CoreGraphics

public class LiveWrap: Identifiable {
    
    public var name: String
    public var typeName: String
    
    public var defaultValue: Floatable
    public var minimumValue: Floatable?
    public var maximumValue: Floatable?
    public var incrementValue: Floatable?

    public var node: NODE!
    
    public enum LiveType {
        case bool
        case int
        case float
        case point
        case size
        case color
        case resolution
        case enumable
    }
    public let type: LiveType?
    
    public var get: (() -> (Floatable))!
    public var set: ((Floatable) -> ())!
    public var setFloats: (([CGFloat]) -> ())!

    public init(type: LiveType? = nil,
                typeName: String,
                name: String? = nil,
                value: Floatable,
                min: Floatable? = nil,
                max: Floatable? = nil,
                inc: Floatable? = nil) {
        
        precondition(!typeName.contains(" "))
        precondition(typeName.first!.isUppercase)
        
        func camelToTitleCased(_ string: String) -> String {
            if string.count <= 1 {
                return string.uppercased()
            }
            let regex = try! NSRegularExpression(pattern: "(?=\\S)[A-Z]", options: [])
            let range = NSMakeRange(1, string.count - 1)
            var titlecased = regex.stringByReplacingMatches(in: string, range: range, withTemplate: " $0")
            for i in titlecased.indices {
                if i == titlecased.startIndex || titlecased[titlecased.index(before: i)] == " " {
                    titlecased.replaceSubrange(i...i, with: String(titlecased[i]).uppercased())
                }
            }
            return titlecased
        }
        
        self.type = type
        self.typeName = typeName
        self.name = name ?? camelToTitleCased(typeName)
        
        defaultValue = value
        
        minimumValue = min
        maximumValue = max
        incrementValue = inc
        
    }
        
}

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

@propertyWrapper public class LiveFloat: LiveWrap {
    
    let updateResolution: Bool
    
    public var wrappedValue: CGFloat {
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
    
    public init(wrappedValue: CGFloat, _ typeName: String, name: String? = nil, range: ClosedRange<CGFloat> = 0.0...1.0, increment: CGFloat = 0.25, updateResolution: Bool = false) {
        self.wrappedValue = wrappedValue
        self.updateResolution = updateResolution
        super.init(type: .float, typeName: typeName, name: name, value: wrappedValue, min: range.lowerBound, max: range.upperBound, inc: increment)
        get = { self.wrappedValue }
        set = { self.wrappedValue = $0 as! CGFloat }
        setFloats = { self.wrappedValue = CGFloat(floats: $0) }
    }

}

@propertyWrapper public class LivePoint: LiveWrap {
    
    public var wrappedValue: CGPoint {
        didSet {
            guard wrappedValue != oldValue else { return }
            guard let node: NODE = node else {
                print("RenderKit Live property wrapper not linked to node.")
                return
            }
            node.render()
        }
    }
    
    public init(wrappedValue: CGPoint, _ typeName: String, name: String? = nil) {
        self.wrappedValue = wrappedValue
        super.init(type: .point, typeName: typeName, name: name, value: wrappedValue, min: CGPoint(x: -1.0, y: -1.0), max: CGPoint(x: 1.0, y: 1.0))
        get = { self.wrappedValue }
        set = { self.wrappedValue = $0 as! CGPoint }
        setFloats = { self.wrappedValue = CGPoint(floats: $0) }
    }

}

@propertyWrapper public class LiveSize: LiveWrap {
    
    public var wrappedValue: CGSize {
        didSet {
            guard wrappedValue != oldValue else { return }
            guard let node: NODE = node else {
                print("RenderKit Live property wrapper not linked to node.")
                return
            }
            node.render()
        }
    }
    
    public init(wrappedValue: CGSize, _ typeName: String, name: String? = nil) {
        self.wrappedValue = wrappedValue
        super.init(type: .size, typeName: typeName, name: name, value: wrappedValue, min: CGSize(width: 0.0, height: 0.0), max: CGSize(width: 2.0, height: 2.0))
        get = { self.wrappedValue }
        set = { self.wrappedValue = $0 as! CGSize }
        setFloats = { self.wrappedValue = CGSize(floats: $0) }
    }

}

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

@propertyWrapper public class LiveResolution: LiveWrap {
    
    public var wrappedValue: Resolution {
        didSet {
            guard wrappedValue != oldValue else { return }
            guard let node: NODE = node else {
                print("RenderKit Live property wrapper not linked to node.")
                return
            }
            node.applyResolution {
                node.render()
            }
        }
    }
    
    public init(wrappedValue: Resolution, _ typeName: String, name: String? = nil) {
        self.wrappedValue = wrappedValue
        super.init(type: .resolution, typeName: typeName, name: name, value: wrappedValue, min: 1, max: 3_840)
        get = { self.wrappedValue }
        set = { self.wrappedValue = $0 as! Resolution }
        setFloats = { self.wrappedValue = Resolution(floats: $0) }
    }

}

public class LiveEnumWrap: LiveWrap {
    public let rawIndices: [Int]
    public let names: [String]
    public var dynamicTypeNames: [String] {
        names.map { $0.lowercased().replacingOccurrences(of: " ", with: "-") }
    }
    public var defaultCaseDynamicTypeName: String {
        let rawIndex: Int = defaultValue as! Int
        guard let index: Int = rawIndices.firstIndex(of: rawIndex) else { return "" }
        guard index < dynamicTypeNames.count else { return "" }
        return dynamicTypeNames[index]
    }
    public init(_ typeName: String, name: String? = nil, rawIndex: Int, rawIndices: [Int], names: [String]) {
        self.rawIndices = rawIndices
        self.names = names
        super.init(type: .enumable, typeName: typeName, name: name, value: rawIndex)
    }
    public func setCase(typeName: String) {
        guard let index: Int = dynamicTypeNames.firstIndex(where: { $0 == typeName }) else { return }
        guard index < rawIndices.count else { return }
        let rawIndex: Int = rawIndices[index]
        set(rawIndex)
    }
}

public protocol Enumable: CaseIterable, Floatable {
    var index: Int { get }
    var name: String { get }
}

public extension Enumable {
    var rawIndex: Int { index }
    init(rawIndex: Int) {
        self = Self.allCases.first(where: { $0.index == rawIndex }) ?? Self.allCases.first!
    }
}

public extension Enumable {
    var orderIndex: Int {
        Self.allCases.firstIndex(where: { $0.rawIndex == rawIndex }) as! Int
    }
    init(orderIndex: Int) {
        guard orderIndex >= 0 && orderIndex < Self.allCases.count else {
            self = Self.allCases.first!
            return
        }
        self = Self.allCases[orderIndex as! Self.AllCases.Index]
    }
}

public extension Enumable {
    static var names: [String] {
        Self.allCases.map(\.name)
    }
    init(name: String) {
        self = Self.allCases.first(where: { $0.name == name }) ?? Self.allCases.first!
    }
}

extension Enumable {
    public var floats: [CGFloat] {
        [CGFloat(index)]
    }
    public init(floats: [CGFloat]) {
        guard let float: CGFloat = floats.first else {
            self = Self.allCases.first!
            return
        }
        self.init(rawIndex: Int(float))
    }
}

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
