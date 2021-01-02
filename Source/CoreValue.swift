#if os(macOS)
import AppKit
#else
import UIKit
#endif
import CoreGraphics


public protocol CoreValue {}


extension Bool: CoreValue {}
extension Int: CoreValue {}

extension CGFloat: CoreValue {}
extension CGPoint: CoreValue {}
extension CGSize: CoreValue {}
extension CGRect: CoreValue {}

#if os(macOS)
typealias PXColor = NSColor
#else
typealias PXColor = UIColor
#endif
extension PXColor: CoreValue {}
