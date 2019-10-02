//
//  Node.swift
//  RenderKit
//
//  Created by Anton Heestand on 2019-10-02.
//  Copyright © 2019 Hexagons. All rights reserved.
//

import Metal

public protocol NODE: Equatable {
    
    var id: UUID { get }
    var name: String? { get }
    
    var texture: MTLTexture? { get set }
    
}

