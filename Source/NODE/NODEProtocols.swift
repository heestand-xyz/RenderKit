//
//  NODEProtocols.swift
//  NodeelKit
//
//  Created by Heestand XYZ on 2018-07-26.
//  Open Source - MIT License
//

import CoreGraphics
import Metal
import Combine

public protocol NODEDelegate: AnyObject {
    func nodeDidRender(_ node: NODE)
}

public protocol NODEIn {
    func didUpdateInputConnections()
}
public protocol NODEOut {
    var renderPromisePublisher: PassthroughSubject<RenderRequest, Never> { get }
    var renderPublisher: PassthroughSubject<RenderPack, Never> { get }
}

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
    var cancellableIns: [AnyCancellable] { get set }
}
public protocol NODEOutIO: NODEOut {
//    var outputPathList: NODE.WeakOutPaths { get set }
    var outputPathList: [NODEOutPath] { get set }
    var connectedOut: Bool { get }
}
