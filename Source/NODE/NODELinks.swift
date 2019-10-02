//
//  Links.swift
//  RenderKit
//
//  Created by Anton Heestand on 2019-10-02.
//  Copyright © 2019 Hexagons. All rights reserved.
//

import Foundation

public class NODELink<N: NODE> {
    /*weak*/ var node: N?
    init(node: N) {
        self.node = node
    }
}

public struct NODELinks<N: NODE>: Collection {
    private var links: [NODELink] = []
    init(_ nodes: [N]) {
        links = nodes.map { NODELink(node: $0) }
    }
    public var startIndex: Int { return links.startIndex }
    public var endIndex: Int { return links.endIndex }
    public subscript(_ index: Int) -> N? {
        return links[index].node
    }
    public func index(after idx: Int) -> Int {
        return links.index(after: idx)
    }
    public mutating func append(_ node: N) {
        links.append(NODELink(node: node))
    }
    public mutating func remove(_ node: N) {
        for (i, link) in links.enumerated() {
            if link.node != nil && link.node! == node {
                links.remove(at: i)
                break
            }
        }
    }
}
