//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-03-15.
//

import Foundation

public struct RenderRequest {
    
    public struct Source {
        public let id: UUID
        public let nodeID: UUID
        public let frameIndex: Int
    }
    let source: Source
    public let sourceChain: [Source]
    public var fullSourceChain: [Source] { sourceChain + [source] }
    
    public var id: UUID { source.id }
    public var nodeID: UUID { source.nodeID }
    public var frameIndex: Int { source.frameIndex }
    
    public let completion: ((Result<RenderResponse, Error>) -> ())?
    
    public init(frameIndex: Int, node: NODE, completion: ((Result<RenderResponse, Error>) -> ())?, via request: RenderRequest? = nil) {
        self.source = Source(id: UUID(), nodeID: node.id, frameIndex: frameIndex)
        self.sourceChain = request != nil ? (request!.sourceChain + [request!.source]) : []
        self.completion = completion
    }
    
}
