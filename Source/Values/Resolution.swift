//
//  Resolution.swift
//  
//
//  Created by Anton Heestand on 2021-04-24.
//

import Resolution

extension Resolution {
    
    public static func auto(render: Render) -> Resolution {
        let scale = Resolution.scale
        for node in render.linkedNodes.compactMap(\.node) {
            guard let superview = node.view.superview else { continue }
            let size = superview.frame.size
            return .custom(w: Int(size.width * scale), h: Int(size.height * scale))
        }
        return ._128
    }
    
}

extension Resolution: Floatable {}
