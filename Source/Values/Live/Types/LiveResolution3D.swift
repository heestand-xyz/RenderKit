//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-04-22.
//

import Foundation
import Resolution

@propertyWrapper public class LiveResolution3D: LiveWrap {
    
    public var wrappedValue: Resolution3D {
        didSet {
            guard wrappedValue != oldValue else { return }
            guard let node: NODE = node else {
                print("RenderKit Live property wrapper not linked to node.")
                return
            }
            node.applyResolution { [weak node] in
                node?.render()
            }
            currentValueSubject.send(wrappedValue)
            didSetValue?()
        }
    }
    
    public var didSetValue: (() -> ())?
    
    public init(wrappedValue: Resolution3D, _ typeName: String, name: String? = nil) {
        self.wrappedValue = wrappedValue
        super.init(type: .resolution3d, typeName: typeName, name: name, value: wrappedValue, min: 1, max: 3_840)
        get = { [weak self] in self?.wrappedValue ?? .cube(-1) }
        set = { [weak self] in self?.wrappedValue = $0 as! Resolution3D }
        setFloats = { [weak self] in self?.wrappedValue = Resolution3D(floats: $0) }
    }
    
    public override func getLiveCodable() -> LiveCodable {
        LiveCodableResolution3D(resolution3d: wrappedValue, typeName: typeName)
    }
    
    public override func setLiveCodable(_ liveCodable: LiveCodable) {
        guard let liveCodableResolution3D: LiveCodableResolution3D = liveCodable as? LiveCodableResolution3D else { return }
        wrappedValue = liveCodableResolution3D.resolution3d
    }
    
}

public class LiveCodableResolution3D: LiveCodable {
    var resolution3d: Resolution3D
    init(resolution3d: Resolution3D, typeName: String) {
        self.resolution3d = resolution3d
        super.init(typeName: typeName, type: .resolution3d)
    }
    enum CodingKeys: CodingKey {
        case resolution3d
    }
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resolution3d = try container.decode(Resolution3D.self, forKey: .resolution3d)
        try super.init(from: decoder)
    }
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(resolution3d, forKey: .resolution3d)
        try super.encode(to: encoder)
    }
}
