//
//  NodeModel.swift
//  RenderKit
//
//  Created by Anton Heestand on 2019-10-03.
//

import Foundation
import Resolution
import PixelColor

public protocol NodeModel: Codable {
    
    var id: UUID { get set }
    var typeName: String { get set }
    var name: String { get set }

    var bypass: Bool { get set }
    
    func isEqual(to nodeModel: NodeModel) -> Bool
}

// MARK: - IO

public protocol NodeInputModel: NodeModel {
    var inputNodeReferences: [NodeReference] { get set }
}
public protocol NodeOutputModel: NodeModel {
    var outputNodeReferences: [NodeReference] { get set }
}

// MARK: - Content

public protocol NodeContentModel: NodeOutputModel {}

public protocol NodeResourceContentModel: NodeContentModel {}

public protocol Node3DResourceContentModel: NodeContentModel {
    var resolution: Resolution3D { get set }
}

public protocol NodeGeneratorContentModel: NodeContentModel {
    var premultiply: Bool { get set }
    var resolution: Resolution { get set }
    var backgroundColor: PixelColor { get set }
    var color: PixelColor { get set }
}

public protocol Node3DGeneratorContentModel: NodeContentModel {
    var premultiply: Bool { get set }
    var resolution: Resolution3D { get set }
    var backgroundColor: PixelColor { get set }
    var color: PixelColor { get set }
}

public protocol NodeCustomContentModel: NodeContentModel {
    var resolution: Resolution { get set }
    var backgroundColor: PixelColor { get set }
}

public protocol NodeSpriteContentModel: NodeContentModel {
    var resolution: Resolution { get set }
    var backgroundColor: PixelColor { get set }
}

// MARK: - Effects

public protocol NodeEffectModel: NodeInputModel, NodeOutputModel {}

public protocol NodeSingleEffectModel: NodeEffectModel {}
public protocol NodeMergerEffectModel: NodeEffectModel {
    var placement: Placement { get set }
}
public protocol NodeMultiEffectModel: NodeEffectModel {}

// MARK: - Closing

public protocol NodeClosingModel: NodeInputModel {}

// MARK: - Equal

extension NodeModel {
    
    public func isSuperEqual(to nodeModel: NodeModel) -> Bool {
        guard id == nodeModel.id else { return false }
        guard typeName == nodeModel.typeName else { return false }
        guard name == nodeModel.name else { return false }
        guard bypass == nodeModel.bypass else { return false }
        return true
    }
}
