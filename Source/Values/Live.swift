import Foundation
import PixelColor

public class LiveWrap: Identifiable {
    
    public var name: String
    public var dynamicTypeName: String {
        name.lowercased().replacingOccurrences(of: " ", with: "-")
    }
    
    public var defaultValue: Floatable
    public var minimumValue: Floatable?
    public var maximumValue: Floatable?
    
    public var node: NODE!
    
    public init(name: String, value: Floatable, min: Floatable? = nil, max: Floatable? = nil) {
        self.name = name
        defaultValue = value
        minimumValue = min
        maximumValue = max
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
                    node.setNeedsRender()
                }
            } else {
                node.setNeedsRender()
            }
        }
    }
    
    public init(wrappedValue: F, name: String, min: F? = nil, max: F? = nil, updateResolution: Bool = false) {
        self.wrappedValue = wrappedValue
        self.updateResolution = updateResolution
        super.init(name: name, value: wrappedValue, min: min, max: max)
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
                    node.setNeedsRender()
                }
            } else {
                node.setNeedsRender()
            }
        }
    }
    
    public init(wrappedValue: CGFloat, name: String, range: ClosedRange<CGFloat> = 0.0...1.0, updateResolution: Bool = false) {
        self.wrappedValue = wrappedValue
        self.updateResolution = updateResolution
        super.init(name: name, value: wrappedValue, min: range.lowerBound, max: range.upperBound)
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
                    node.setNeedsRender()
                }
            } else {
                node.setNeedsRender()
            }
        }
    }
    
    public init(wrappedValue: Int, name: String, range: ClosedRange<Int>, updateResolution: Bool = false) {
        self.wrappedValue = wrappedValue
        self.updateResolution = updateResolution
        super.init(name: name, value: wrappedValue, min: range.lowerBound, max: range.upperBound)
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
                    node.setNeedsRender()
                }
            } else {
                node.setNeedsRender()
            }
        }
    }
    
    public init(wrappedValue: Bool, name: String, updateResolution: Bool = false) {
        self.wrappedValue = wrappedValue
        self.updateResolution = updateResolution
        super.init(name: name, value: wrappedValue)
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
            node.setNeedsRender()
        }
    }
    
    public init(wrappedValue: CGPoint, name: String) {
        self.wrappedValue = wrappedValue
        super.init(name: name, value: wrappedValue,
                   min: CGPoint(x: -1.0, y: -1.0),
                   max: CGPoint(x: 1.0, y: 1.0))
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
            node.setNeedsRender()
        }
    }
    
    public init(wrappedValue: CGSize, name: String) {
        self.wrappedValue = wrappedValue
        super.init(name: name, value: wrappedValue,
                   min: CGSize(width: 0.0, height: 0.0),
                   max: CGSize(width: 2.0, height: 2.0))
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
            node.setNeedsRender()
        }
    }
    
    public init(wrappedValue: PixelColor, name: String) {
        self.wrappedValue = wrappedValue
        super.init(name: name, value: wrappedValue)
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
                node.setNeedsRender()
            }
        }
    }
    
    public init(wrappedValue: Resolution, name: String) {
        self.wrappedValue = wrappedValue
        super.init(name: name, value: wrappedValue)
    }

}

public class LiveEnumWrap: LiveWrap {
    let caseNames: [String]
    var dynamicCaseTypeNames: [String] {
        caseNames.map { $0.lowercased().replacingOccurrences(of: " ", with: "-") }
    }
    public init(name: String, index: Int, caseNames: [String]) {
        self.caseNames = caseNames
        super.init(name: name, value: index)
    }
}

public protocol Enumable: CaseIterable, Floatable {
    var index: Int { get }
    var names: [String] { get }
    init(index: Int)
}

extension Enumable {
    public init(index: Int) {
        self = Self.allCases.first(where: { $0.index == index }) ?? Self.allCases.first!
    }
}

extension Enumable {
    public var floats: [CGFloat] {
        [CGFloat(index)]
    }
    public init(floats: [CGFloat]) {
        guard let float: CGFloat = floats.first else {
            self.init(index: 0)
            return
        }
        self.init(index: Int(float))
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
                    node.setNeedsRender()
                }
            } else {
                node.setNeedsRender()
            }
        }
    }
    
    public init(wrappedValue: E, name: String, updateResolution: Bool = false) {
        self.updateResolution = updateResolution
        self.wrappedValue = wrappedValue
        super.init(name: name, index: wrappedValue.index, caseNames: wrappedValue.names)
    }

}
