//
//  NODEProtocols.swift
//  NodeelKit
//
//  Created by Heestand XYZ on 2018-07-26.
//  Open Source - MIT License
//

import CoreGraphics
import Metal

public protocol NODEDelegate: AnyObject {
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
