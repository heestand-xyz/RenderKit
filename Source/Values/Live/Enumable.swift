//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-04-22.
//

import CoreGraphics

public protocol Enumable: CaseIterable, Floatable {
    var index: Int { get }
    var name: String { get }
}

public extension Enumable {
    var rawIndex: Int { index }
    init(rawIndex: Int) {
        self = Self.allCases.first(where: { $0.index == rawIndex }) ?? Self.allCases.first!
    }
}

public extension Enumable {
    var orderIndex: Int {
        Self.allCases.firstIndex(where: { $0.rawIndex == rawIndex }) as! Int
    }
    init(orderIndex: Int) {
        guard orderIndex >= 0 && orderIndex < Self.allCases.count else {
            self = Self.allCases.first!
            return
        }
        self = Self.allCases[orderIndex as! Self.AllCases.Index]
    }
}

public extension Enumable {
    static var names: [String] {
        Self.allCases.map(\.name)
    }
    init(name: String) {
        self = Self.allCases.first(where: { $0.name == name }) ?? Self.allCases.first!
    }
}

extension Enumable {
    public var floats: [CGFloat] {
        [CGFloat(index)]
    }
    public init(floats: [CGFloat]) {
        guard let float: CGFloat = floats.first else {
            self = Self.allCases.first!
            return
        }
        self.init(rawIndex: Int(float))
    }
}
