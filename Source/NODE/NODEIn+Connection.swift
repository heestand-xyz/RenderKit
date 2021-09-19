//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-06-28.
//

import Foundation
import Combine

func postUpdateInputConnectionsPublishers(inputList: [NODE & NODEOut],
                                          promisedRender: @escaping (RenderRequest) -> (),
                                          render: @escaping (RenderRequest) -> ()) -> [AnyCancellable] {
    
    var cancelBag: [AnyCancellable] = []
    
    var promisedRenderRequests: [RenderRequest] = []
    
    let manyRenderPromisePublisher = Publishers.MergeMany(inputList.map(\.renderPromisePublisher))
    manyRenderPromisePublisher
        .sink { renderRequest in
            promisedRenderRequests.append(renderRequest)
            promisedRender(renderRequest)
        }
        .store(in: &cancelBag)
    
    let manyRenderPublisher = Publishers.MergeMany(inputList.map(\.renderPublisher))
    var willRenderFromFrameIndex: Int?
    var willRenderTimer: Timer?
    manyRenderPublisher
        .sink { renderPack in
            defer {
                promisedRenderRequests.removeAll(where: { promisedRenderRequest in
                    renderPack.request.fullSourceChain.map(\.id).contains(promisedRenderRequest.id)
                })
            }
//            let matchingPromisedFrameIndexCount: Int = promisedRenderRequests.filter({ promisedRenderRequest in
//                renderPack.request.fullSourceChain.map(\.frameIndex).contains(promisedRenderRequest.frameIndex)
//            }).count
            if let frameIndex: Int = willRenderFromFrameIndex {
                if frameIndex == renderPack.request.frameIndex {
                    return
                } else {
                    render(renderPack.request)
                }
            }
            willRenderFromFrameIndex = renderPack.request.frameIndex
            willRenderTimer?.invalidate()
            #warning("Max FPS is Hard Coded")
            willRenderTimer = Timer(timeInterval: 120, repeats: false, block: { _ in
                willRenderFromFrameIndex = nil
                willRenderTimer = nil
                render(renderPack.request)
            })
            RunLoop.current.add(willRenderTimer!, forMode: .common)
        }
        .store(in: &cancelBag)
    
    return cancelBag
}

extension NODEEffect {
    
    public func didUpdateInputConnections() {
        cancellableIns = postUpdateInputConnectionsPublishers(inputList: inputList, promisedRender: { [weak self] renderRequest in
            self?.promisedRender(renderRequest)
        }, render: { [weak self] renderRequest in
            self?.render(via: renderRequest)
        })
    }
}

extension NODEOutput {
    
    public func didUpdateInputConnections() {
        cancellableIns = postUpdateInputConnectionsPublishers(inputList: inputList, promisedRender: { [weak self] renderRequest in
            self?.promisedRender(renderRequest)
        }, render: { [weak self] renderRequest in
            self?.render(via: renderRequest)
        })
    }
}
