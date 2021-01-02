//
//  UINSColor.swift
//  
//
//  Created by Anton Heestand on 2021-01-02.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

#if os(macOS)
/// PXColor is just UIColor & NSColor
public typealias UINSColor = NSColor
#else
/// PXColor is just UIColor & NSColor
public typealias UINSColor = UIColor
#endif

extension UINSColor {
    
//    static let r: CGFloat = { () -> CGFloat in
//        CIColor(color: self)
//    }()
//    static let g: CGFloat
//    static let b: CGFloat
//    static let a: CGFloat
    
}
