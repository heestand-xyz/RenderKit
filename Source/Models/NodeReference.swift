//
//  NodeReference.swift
//  RenderKit
//
//  Created by Anton Heestand on 2021-12-12.
//

import Foundation

public struct NodeReference: Codable {
    
    let id: UUID
    
    let typeName: String
    let name: String
    
    enum Connection: Codable {
        case inputSingle
        enum Merger: Codable {
            case leading
            case trailing
        }
        case inputMerger(Merger)
        case inputMulti(Int)
        case output
    }
    let connection: Connection
    
}
