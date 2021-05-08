//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-04-22.
//

import Foundation
import Resolution

@propertyWrapper public class LiveResolution: LiveWrap {
    
    public var wrappedValue: Resolution {
        didSet {
            guard wrappedValue != oldValue else { return }
            guard let node: NODE = node else {
                print("RenderKit Live property wrapper not linked to node.")
                return
            }
            node.applyResolution {
                node.render()
            }
        }
    }
    
    public init(wrappedValue: Resolution, _ typeName: String, name: String? = nil) {
        self.wrappedValue = wrappedValue
        super.init(type: .resolution, typeName: typeName, name: name, value: wrappedValue, min: 1, max: 3_840)
        get = { self.wrappedValue }
        set = { self.wrappedValue = $0 as! Resolution }
        setFloats = { self.wrappedValue = Resolution(floats: $0) }
    }
    
    public override func getLiveCodable() -> LiveCodable {
        LiveCodableResolution(resolution: wrappedValue, typeName: typeName)
    }
    
    public override func setLiveCodable(_ liveCodable: LiveCodable) {
        guard let liveCodableResolution: LiveCodableResolution = liveCodable as? LiveCodableResolution else { return }
        wrappedValue = liveCodableResolution.resolution
    }
    
}

public class LiveCodableResolution: LiveCodable {
    var resolution: Resolution
    init(resolution: Resolution, typeName: String) {
        self.resolution = resolution
        super.init(typeName: typeName, type: .resolution)
    }
    enum CodingKeys: CodingKey {
        case resolution
    }
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resolution = try container.decode(Resolution.self, forKey: .resolution)
        try super.init(from: decoder)
    }
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(resolution, forKey: .resolution)
        try super.encode(to: encoder)
    }
}
