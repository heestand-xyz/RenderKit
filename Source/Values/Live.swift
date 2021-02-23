import Foundation
import PixelColor

public class LiveWrap {
    
    var name: String
    var dynamicTypeName: String {
        name.lowercased().replacingOccurrences(of: " ", with: "-")
    }
    
    var defaultValue: Floatable
    var minimumValue: Floatable?
    var maximumValue: Floatable?
    
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
