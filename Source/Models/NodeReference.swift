//
//  NodeReference.swift
//  RenderKit
//
//  Created by Anton Heestand on 2021-12-12.
//

import Foundation

public struct NodeReference: Codable {
    
    public let id: UUID
    public let typeName: String
    public let name: String
    
    public enum Connection: Codable {
        case single
        public enum Merger: Codable {
            case leading
            case trailing
        }
        case merger(Merger)
        case multi(Int)
    }
    public let connection: Connection
    
    public init(nodeOutPath: NODEOutPath) {
        id = nodeOutPath.nodeIn.id
        typeName = nodeOutPath.nodeIn.typeName
        name = nodeOutPath.nodeIn.name
        switch nodeOutPath.nodeIn {
        case is NODESingleEffect:
            connection = .single
        case is NODEMergerEffect:
            connection = .merger(nodeOutPath.inIndex == 0 ? .leading : .trailing)
        case is NODEMultiEffect:
            connection = .multi(nodeOutPath.inIndex)
        case is NODEOutput:
            connection = .single
        default:
            fatalError("Unknown NODE Type")
        }
    }
    
    public init(node: NODE, connection: NodeReference.Connection) {
        self.id = node.id
        self.typeName = node.typeName
        self.name = node.name
        self.connection = connection
    }
    
    public init(id: UUID, typeName: String, name: String, connection: NodeReference.Connection) {
        self.id = id
        self.typeName = typeName
        self.name = name
        self.connection = connection
    }
    
}
