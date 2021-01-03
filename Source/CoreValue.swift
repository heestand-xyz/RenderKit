import CoreGraphics


public protocol CoreValue {}


extension Bool: CoreValue {}
extension Int: CoreValue {}

extension CGFloat: CoreValue {}
extension CGPoint: CoreValue {}
extension CGSize: CoreValue {}
extension CGRect: CoreValue {}

extension PixelColor: CoreValue {}
