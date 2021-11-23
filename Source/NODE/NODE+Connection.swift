//
//  Created by Anton Heestand on 2021-06-28.
//

import Foundation

extension NODE {
    
    public func setNeedsConnectSingle(new newInNode: (NODE & NODEOut)?, old oldInNode: (NODE & NODEOut)?) {
        guard var nodeInIO = self as? NODE & NODEInIO else { renderObject.logger.log(node: self, .error, .connection, "NODEIn's Only"); return }
        if let oldNodeOut = oldInNode {
            var nodeOut = oldNodeOut as! (NODE & NODEOutIO)
            for (i, nodeOutPath) in nodeOut.outputPathList.enumerated() {
                if nodeOutPath.nodeIn.id == nodeInIO.id {
                    nodeOut.outputPathList.remove(at: i)
                    break
                }
            }
            nodeInIO.inputList = []
            renderObject.logger.log(node: self, .info, .connection, "Disonnected Single: \(nodeOut.name)")
        }
        if let newNodeOut = newInNode {
            guard newNodeOut.id != self.id else {
                renderObject.logger.log(node: self, .error, .connection, "Can't connect to self.")
                return
            }
            var nodeOut = newNodeOut as! (NODE & NODEOutIO)
            nodeInIO.inputList = [nodeOut]
            nodeOut.outputPathList.append(NODEOutPath(nodeIn: nodeInIO, inIndex: 0))
            renderObject.logger.log(node: self, .info, .connection, "Connected Single: \(nodeOut.name)")
            connected()
        } else {
            disconnected()
        }
    }
    
    public func setNeedsConnectMerger(new newInNode: (NODE & NODEOut)?, old oldInNode: (NODE & NODEOut)?, second: Bool) {
        guard var nodeInIO = self as? NODE & NODEInIO else { renderObject.logger.log(node: self, .error, .connection, "NODEIn's Only"); return }
        guard let nodeInMerger = self as? NODEInMerger else { return }
        if let oldNodeOut = oldInNode {
            var nodeOut = oldNodeOut as! (NODE & NODEOutIO)
            for (i, nodeOutPath) in nodeOut.outputPathList.enumerated() {
                if nodeOutPath.nodeIn.id == nodeInIO.id {
                    nodeOut.outputPathList.remove(at: i)
                    break
                }
            }
            nodeInIO.inputList = []
            renderObject.logger.log(node: self, .info, .connection, "Disonnected Merger: \(nodeOut.name)")
        }
        if let newNodeOut = newInNode {
            if var nodeOutA = (!second ? newNodeOut : nodeInMerger.inputA) as? (NODE & NODEOutIO),
                var nodeOutB = (second ? newNodeOut : nodeInMerger.inputB) as? (NODE & NODEOutIO) {
                nodeInIO.inputList = [nodeOutA, nodeOutB]
                nodeOutA.outputPathList.append(NODEOutPath(nodeIn: nodeInIO, inIndex: 0))
                nodeOutB.outputPathList.append(NODEOutPath(nodeIn: nodeInIO, inIndex: 1))
                renderObject.logger.log(node: self, .info, .connection, "Connected Merger: \(nodeOutA.name), \(nodeOutB.name)")
                connected()
            }
        } else {
            disconnected()
        }
    }
    
    public func setNeedsConnectMulti(new newInNodes: [NODE & NODEOut], old oldInNodes: [NODE & NODEOut]) {
        guard var nodeInIO = self as? NODE & NODEInIO else { renderObject.logger.log(node: self, .error, .connection, "NODEIn's Only"); return }
        nodeInIO.inputList = newInNodes
        for oldInNode in oldInNodes {
            if var input = oldInNode as? (NODE & NODEOutIO) {
                for (j, nodeOutPath) in input.outputPathList.enumerated() {
                    if nodeOutPath.nodeIn.id == nodeInIO.id {
                        input.outputPathList.remove(at: j)
                        break
                    }
                }
            }
        }
        for (i, newInNode) in newInNodes.enumerated() {
            if var input = newInNode as? (NODE & NODEOutIO) {
                input.outputPathList.append(NODEOutPath(nodeIn: nodeInIO, inIndex: i))
            }
        }
        if !newInNodes.isEmpty {
            renderObject.logger.log(node: self, .info, .connection, "Connected Multi: \(newInNodes.map(\.name))")
            connected()
        } else {
            disconnected()
        }
    }
    
}

extension NODE {
    
    private func connected() {
        applyResolution { [weak self] in
            self?.render()
            DispatchQueue.main.async { [weak self] in
                self?.render()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.render()
            }
        }
        if let nodeIn: NODEIn = self as? NODEIn {
            nodeIn.didUpdateInputConnections()
        }
        didConnect()
    }
    
    private func disconnected() {
        renderObject.logger.log(node: self, .info, .connection, "Disconnected")
        texture = nil
        if let nodeIn: NODEIn = self as? NODEIn {
            nodeIn.didUpdateInputConnections()
        }
        didDisconnect()
    }
    
}
