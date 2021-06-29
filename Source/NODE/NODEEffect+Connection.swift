//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-06-28.
//

import Foundation
import Combine

extension NODEEffect {
    
    public func didUpdateInputConnections() {
        
        cancellableIns = []
        
        var promisedRenderRequests: [RenderRequest] = []
        
        let manyRenderPromisePublisher = Publishers.MergeMany(inputList.map(\.renderPromisePublisher))
        manyRenderPromisePublisher
            .sink { [weak self] renderRequest in
                guard let self = self else { return }
//                print("Combine \"\(self.name)\" Promise +++", renderRequest.frameIndex)
                promisedRenderRequests.append(renderRequest)
                self.promisedRender(renderRequest)
            }
            .store(in: &cancellableIns)
        
        let manyRenderPublisher = Publishers.MergeMany(inputList.map(\.renderPublisher))
        var willRenderFromFrameIndex: Int?
        var willRenderTimer: Timer?
        manyRenderPublisher
            .sink {  [weak self] renderPack in
                guard let self = self else { return }
                defer {
                    promisedRenderRequests.removeAll(where: { promisedRenderRequest in
                        renderPack.request.fullSourceChain.map(\.id).contains(promisedRenderRequest.id)
                    })
                }
                let matchingPromisedFrameIndexCount: Int = promisedRenderRequests.filter({ promisedRenderRequest in
                    renderPack.request.fullSourceChain.map(\.frameIndex).contains(promisedRenderRequest.frameIndex)
                }).count
//                print("Combine \"\(self.name)\" Sink )))))", matchingPromisedFrameIndexCount, "(((", renderPack.request.fullSourceChain.map(\.frameIndex))
//                guard matchingPromisedFrameIndexCount <= 1 else { return }
                if let frameIndex: Int = willRenderFromFrameIndex {
                    if frameIndex == renderPack.request.frameIndex {
                        return
                    } else {
//                        print("Combine \"\(self.name)\" Render Now <=<=<")
                        self.render(via: renderPack.request)
                    }
                }
                willRenderFromFrameIndex = renderPack.request.frameIndex
                willRenderTimer?.invalidate()
                willRenderTimer = Timer(timeInterval: self.renderObject.maxSecondsPerFrame, repeats: false, block: { _ in
                    willRenderFromFrameIndex = nil
                    willRenderTimer = nil
//                    print("Combine \"\(self.name)\" Render Frame <-<-<")
                    self.render(via: renderPack.request)
                })
                RunLoop.current.add(willRenderTimer!, forMode: .common)
            }
            .store(in: &cancellableIns)
    }
    
}
