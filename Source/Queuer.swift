//
//  Created by Anton Heestand on 2021-03-17.
//

import Foundation

protocol QueuerDelegate: AnyObject {
    func queuerNode(id: UUID) -> NODE?
}

public class Queuer {
    
    weak var delegate: QueuerDelegate?
    
    public enum QueuerError: LocalizedError {
        case duplicate
        public var errorDescription: String? {
            switch self {
            case .duplicate:
                return "Queuer Error - Duplicate"
            }
        }
    }
    
    struct Item {
        let request: RenderRequest
        let completion: (Result<Void, Error>) -> ()
    }
    private var newQueue: [Item] = []
    private var uniqueQueue: [Item] = []
    
    func frameLoop() {
//        render()
    }
    
    func check() {
        let newUniqueQueue = newQueue.reduce([Item](), { items, item in
            var items: [Item] = items
            if !items.contains(where: { iItem in
                iItem.request.nodeID == item.request.nodeID
            }) {
                items.append(item)
            }
            return items
        })
        for item in newQueue {
            if !uniqueQueue.contains(where: { iItem in
                iItem.request.id == item.request.id
            }) {
                item.completion(.failure(QueuerError.duplicate))
            }
        }
        uniqueQueue.append(contentsOf: newUniqueQueue)
        newQueue = []
        render()
    }
    
    func render() {
        guard !uniqueQueue.isEmpty else { return }
        for item in uniqueQueue {
            guard let node: NODE = delegate?.queuerNode(id: item.request.nodeID) else { continue }
            guard !node.renderInProgress else { return }
        }
        for item in uniqueQueue {
            item.completion(.success(()))
        }
        uniqueQueue = []
    }
    
    public func add(request: RenderRequest, completion: @escaping (Result<Void, Error>) -> ()) {
        newQueue.append(Item(request: request, completion: completion))
        DispatchQueue.main.async { [weak self] in
            self?.check()
        }
    }

}
