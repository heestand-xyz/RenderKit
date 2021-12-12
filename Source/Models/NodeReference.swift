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
    let index: Int
}
