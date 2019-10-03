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

public struct NODEOutPath {
    var nodeIn: NODE & NODEIn
    let inIndex: Int
}

public protocol NODEIn {}
public protocol NODEOut {}

public protocol NODEInSingle: NODEIn {
    var inNode: (NODE & NODEOut)? { get set }
}
public protocol NODEInMerger: NODEIn {
    var inNodeA: (NODE & NODEOut)? { get set }
    var inNodeB: (NODE & NODEOut)? { get set }
}
public protocol NODEInMulti: NODEIn {
    var inNodes: [NODE & NODEOut] { get set }
}

public protocol NODEInIO: NODEIn {
    var nodeInList: [NODE & NODEOut] { get set }
    var connectedIn: Bool { get }
}
public protocol NODEOutIO: NODEOut {
//    var nodeOutPathList: NODE.WeakOutPaths { get set }
    var nodeOutPathList: [NODEOutPath] { get set }
    var connectedOut: Bool { get }
}

protocol NODEMetal {
    var metalFileName: String { get }
    var metalCode: String? { get }
    var metalUniforms: [MetalUniform] { get }
}

protocol NODEResolution {
    var resolution: Resolution { get set }
    init(resolution: Resolution)
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
    var inNode: NODE & NODEOut { get }
}
@available(iOS 13.0.0, *)
@available(OSX 10.15, *)
@available(tvOS 13.0.0, *)
public protocol NODEUIMergerEffect: NODEUI {
    var inNodeA: NODE & NODEOut { get }
    var inNodeB: NODE & NODEOut { get }
}
@available(iOS 13.0.0, *)
@available(OSX 10.15, *)
@available(tvOS 13.0.0, *)
public protocol NODEUIMultiEffect: NODEUI {
    var inNodes: [NODE & NODEOut] { get }
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
