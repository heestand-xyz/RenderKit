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

public protocol NodeGeneratorContentModel: NodeContentModel {
    var premultiply: Bool { get set }
    var resolution: Resolution { get set }
    var backgroundColor: PixelColor { get set }
    var color: PixelColor { get set }
}

public protocol Node3DGeneratorContentModel: NodeContentModel {
    var premultiply: Bool { get set }
    var resolution3d: Resolution3D { get set }
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

//// MARK: - Resolution
//
//public protocol NodeResolutionModel {
//    var resolution: Resolution { get set }
//}
//
//public protocol Node3DResolutionModel {
//    var resolution3d: Resolution3D { get set }
//}
//
//// MARK: - Metal
//
//public protocol NodeMetalModel {
//    var metalUniforms: [MetalUniform] { get set }
//}
//
//public protocol NodeMetalCodeModel: NodeMetalModel {
//    var code: String { get set }
//}
//
//public protocol NodeMetalScriptModel: NodeMetalModel {
//    var whiteScript: String { get set }
//    var redScript: String { get set }
//    var greenScript: String { get set }
//    var blueScript: String { get set }
//    var alphaScript: String { get set }
//}