//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-06-28.
//

import MetalKit
import Foundation

extension NODE {
    
//    #if swift(>=5.5)
//    
//    @available(iOS 15.0, *)
//    @available(tvOS 15.0, *)
//    @available(macOS 12.0, *)
//    public func renderDirect() async throws {
//        if let nodeInIO = self as? NODEInIO {
//            for node in nodeInIO.inputList {
//                try await node.renderDirect()
//            }
//        }
//        try await renderCurrentDirect()
//    }
//    
//    @available(iOS 15.0, *)
//    @available(tvOS 15.0, *)
//    @available(macOS 12.0, *)
//    public func renderCurrentDirect() async throws {
//        return try await withCheckedThrowingContinuation { continuation in
//            renderCurrentDirect { result in
//                switch result {
//                case .success:
//                    continuation.resume()
//                case .failure(let error):
//                    continuation.resume(throwing: error)
//                }
//            }
//        }
//    }
//    
//    #endif
    
    public func renderCurrentDirect(completion: @escaping (Result<MTLTexture, Error>) -> ()) {
        let frameIndex = renderObject.frameIndex
        let renderRequest = RenderRequest(frameIndex: frameIndex, node: self, completion: nil)
        renderObject.engine.renderNODE(self, renderRequest: renderRequest) { [weak self] result in
            switch result {
            case .success(let renderPack):
                self?.didRender(renderPack: renderPack)
                completion(.success(renderPack.response.texture))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    public func render(completion: ((Result<RenderResponse, Error>) -> ())? = nil,
                       via upstreamRenderRequest: RenderRequest) {
        renderObject.logger.log(node: self, .detail, .render, "Render Requested with Completion Handler", loop: true)
        let frameIndex = renderObject.frameIndex
        let renderRequest = RenderRequest(frameIndex: frameIndex, node: self, completion: completion, via: upstreamRenderRequest)
        queueRender(renderRequest)
    }
    
    private func promiseRender(_ renderRequest: RenderRequest) {
        if let nodeOut: NODEOut = self as? NODEOut {
            nodeOut.renderPromisePublisher.send(renderRequest)
        }
    }
    
    public func promisedRender(_ renderRequest: RenderRequest) {
        promiseRender(renderRequest)
    }
    
    public func queueRender(_ renderRequest: RenderRequest) {
        
        guard !bypass else {
            renderObject.logger.log(node: self, .detail, .render, "Queue Render Bypassed", loop: true)
            if let nodeOut: NODEOutIO = self as? NODEOutIO {
                for nodePath in nodeOut.outputPathList {
                    nodePath.nodeIn.render()
                }
            }
            return
        }

        guard !renderInProgress else {
            renderQueue.append(renderRequest)
            renderObject.logger.log(node: self, .detail, .render, "Queue Render in Progress", loop: true)
            return
        }
                
        renderObject.queuer.add(request: renderRequest) { [weak self] queueResult in
            guard let self = self else { return }
            switch queueResult {
            case .success:
    
                self.renderObject.logger.log(node: self, .detail, .render, "Queue Will Render", loop: true)
                
                self.renderObject.engine.renderNODE(self, renderRequest: renderRequest) { [weak self] result in
                    guard let self = self else { return }
                    
                    switch result {
                    case .success(let renderPack):
                        self.didRender(renderPack: renderPack)
                    case .failure(let error):
                        self.renderObject.logger.log(node: self, .error, .render, "Render Failed", loop: true, e: error)
                    }
                    
                    renderRequest.completion?(result.map(\.response))
                    
                    if !self.renderQueue.isEmpty {
                        let firstRequestFrameIndex: Int = self.renderQueue.map(\.frameIndex).sorted().first!
                        let completions = self.renderQueue.compactMap(\.completion)
                        self.renderQueue = []
                        #warning("Merge of Many Render Requests")
                        let renderRequest = RenderRequest(frameIndex: firstRequestFrameIndex, node: self, completion: { result in
                            completions.forEach { completion in
                                completion(result)
                            }
                        })
                        self.queueRender(renderRequest)
                    }
                }
                
            case .failure(let error):
                if error as? Queuer.QueuerError != Queuer.QueuerError.duplicate {
                    self.renderObject.logger.log(node: self, .warning, .render, "Queue Can't Render", loop: true, e: error)
                }
                renderRequest.completion?(.failure(error))
            }
        }
        
    }
    
    public func renderOuts(renderPack: RenderPack) {
        
        if let nodeOut: NODEOut = self as? NODEOut {
            nodeOut.renderPublisher.send(renderPack)
        }
    }
    
    public func renderCustomVertexTexture() {
        for pix in renderObject.linkedNodes.compactMap(\.node) {
            if pix.customVertexTextureActive {
                if let input = pix.customVertexNodeIn {
                    if input.id == self.id {
                        pix.render()
                    }
                }
            }
        }
    }
    
}
