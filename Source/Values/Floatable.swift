import CoreGraphics


public protocol Floatable {
    var floats: [CGFloat] { get }
}


extension Bool: Floatable {
    public var floats: [CGFloat] { [self ? 1.0 : 0.0] }
}
extension Int: Floatable {
    public var floats: [CGFloat] { [CGFloat(self)] }
}

extension CGFloat: Floatable {
    public var floats: [CGFloat] { [self] }
}
extension CGPoint: Floatable {
    public var floats: [CGFloat] { [x, y] }
}
extension CGSize: Floatable {
    public var floats: [CGFloat] { [width, height] }
}
extension CGRect: Floatable {
    public var floats: [CGFloat] { [minX, minY, width, height] }
}
