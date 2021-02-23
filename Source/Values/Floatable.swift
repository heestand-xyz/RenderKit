import CoreGraphics


public protocol Floatable {
    var floats: [CGFloat] { get }
    init(floats: [CGFloat])
}

//extension Floatable { // : Comparable
//    public static func < (lhs: Self, rhs: Self) -> Bool {
//        #warning("Fix Comparable Implementation")
//        guard let lhs: CGFloat = lhs.floats.first else { return false }
//        guard let rhs: CGFloat = rhs.floats.first else { return false }
//        return lhs < rhs
//    }
//}

extension Bool: Floatable {
    public var floats: [CGFloat] { [self ? 1.0 : 0.0] }
    public init(floats: [CGFloat]) {
        guard let float: CGFloat = floats.first else { self = false; return }
        self = float > 0.0
    }
}
extension Int: Floatable {
    public var floats: [CGFloat] { [CGFloat(self)] }
    public init(floats: [CGFloat]) {
        guard let float: CGFloat = floats.first else { self = 0; return }
        self = Int(float)
    }
}

extension CGFloat: Floatable {
    public var floats: [CGFloat] { [self] }
    public init(floats: [CGFloat]) {
        guard let float: CGFloat = floats.first else { self = 0.0; return }
        self = float
    }
}
extension CGPoint: Floatable {
    public var floats: [CGFloat] { [x, y] }
    public init(floats: [CGFloat]) {
        guard floats.count == 2 else { self = .zero; return }
        self = CGPoint(x: floats[0], y: floats[1])
    }
}
extension CGSize: Floatable {
    public var floats: [CGFloat] { [width, height] }
    public init(floats: [CGFloat]) {
        guard floats.count == 2 else { self = .zero; return }
        self = CGSize(width: floats[0], height: floats[1])
    }
}
extension CGRect: Floatable {
    public var floats: [CGFloat] { [minX, minY, width, height] }
    public init(floats: [CGFloat]) {
        guard floats.count == 4 else { self = .zero; return }
        self = CGRect(x: floats[0], y: floats[1], width: floats[2], height: floats[3])
    }
}
