//
//  NODEProtocols.swift
//  NodeelKit
//
//  Created by Hexagons on 2018-07-26.
//  Open Source - MIT License
//

import CoreGraphics
import Metal

public protocol NODEDelegate: class {
    func nodeDidRender(_ node: NODE)
}

public protocol NODEIn {}
public protocol NODEOut {}

public protocol NODEInSingle: NODEIn {
    var input: (NODE & NODEOut)? { get set }
}
public protocol NODEInMerger: NODEIn {
    var inputA: (NODE & NODEOut)? { get set }
    var inputB: (NODE & NODEOut)? { get set }
}
public protocol NODEInMulti: NODEIn {
    var inputs: [NODE & NODEOut] { get set }
}

public protocol NODEInIO: NODEIn {
    var inputList: [NODE & NODEOut] { get set }
    var connectedIn: Bool { get }
}
public protocol NODEOutIO: NODEOut {
//    var outputPathList: NODE.WeakOutPaths { get set }
    var outputPathList: [NODEOutPath] { get set }
    var connectedOut: Bool { get }
}


#if canImport(SwiftUI)

@available(iOS 13.0.0, *)
@available(OSX 10.15, *)
@available(tvOS 13.0.0, *)
public protocol NODEUI {
    var node: NODE { get }
}
@available(iOS 13.0.0, *)
@available(OSX 10.15, *)
@available(tvOS 13.0.0, *)
public protocol NODEUISingleEffect: NODEUI {
    var input: NODE & NODEOut { get }
}
@available(iOS 13.0.0, *)
@available(OSX 10.15, *)
@available(tvOS 13.0.0, *)
public protocol NODEUIMergerEffect: NODEUI {
    var inputA: NODE & NODEOut { get }
    var inputB: NODE & NODEOut { get }
}
@available(iOS 13.0.0, *)
@available(OSX 10.15, *)
@available(tvOS 13.0.0, *)
public protocol NODEUIMultiEffect: NODEUI {
    var inputs: [NODE & NODEOut] { get }
}

@available(iOS 13.0.0, *)
@available(OSX 10.15, *)
@available(tvOS 13.0.0, *)
@_functionBuilder
public struct NODEUIMultiEffectBuilder {
    public static func buildBlock(_ children: NODEUI...) -> [NODE & NODEOut] {
        return children.compactMap { $0.node as? NODE & NODEOut }
    }
}

#endif
