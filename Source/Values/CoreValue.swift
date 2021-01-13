import CoreGraphics


public protocol CoreValue {
    var valueList: [CGFloat] { get }
}

public struct AnyCoreValue: CoreValue {
    public var valueList: [CGFloat] { [] }
}


extension Bool: CoreValue {
    public var valueList: [CGFloat] { [self ? 1.0 : 0.0] }
}
extension Int: CoreValue {
    public var valueList: [CGFloat] { [CGFloat(self)] }
}

extension CGFloat: CoreValue {
    public var valueList: [CGFloat] { [self] }
}
extension CGPoint: CoreValue {
    public var valueList: [CGFloat] { [x, y] }
}
extension CGSize: CoreValue {
    public var valueList: [CGFloat] { [width, height] }
}
extension CGRect: CoreValue {
    public var valueList: [CGFloat] { [minX, minY, width, height] }
}

extension PixelColor: CoreValue {
    public var valueList: [CGFloat] { components }
}
