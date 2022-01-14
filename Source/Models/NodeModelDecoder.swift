//
//  File.swift
//  
//
//  Created by Anton Heestand on 2022-01-11.
//

import Foundation

public struct NodeModelDecoder {
    
    enum CodingKeys: CodingKey {
        case id
        case typeName
        case name
        case bypass
    }
    
    public static func decode(from decoder: Decoder, model: NodeModel) throws -> NodeModel {
        
        var model: NodeModel = model
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        model.id = try container.decode(UUID.self, forKey: .id)
        model.typeName = try container.decode(String.self, forKey: .typeName)
        model.name = try container.decode(String.self, forKey: .name)
        model.bypass = try container.decode(Bool.self, forKey: .bypass)
        
        return model
    }
}
