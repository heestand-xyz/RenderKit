//
//  Created by Anton Heestand on 2021-04-22.
//

import Foundation
import Resolution

@propertyWrapper public class LiveResolution: LiveWrap {
    
    public var wrappedValue: Resolution {
        didSet {
            guard wrappedValue != oldValue else { return }
            guard !isSkeleton else { return }
            guard let node: NODE = node else {
                print("RenderKit Live property wrapper not linked to node.")
                return
            }
            node.applyResolution { [weak node] in
                node?.render()
            }
            currentValueSubject.send(wrappedValue)
            didSetValue?()
            changed()
        }
    }
    
    public var didSetValue: (() -> ())?
    
    public init(wrappedValue: Resolution, _ typeName: String, name: String? = nil) {
        self.wrappedValue = wrappedValue
        super.init(type: .resolution, typeName: typeName, name: name, value: wrappedValue, min: 1, max: 3_840)
        get = { [weak self] in self?.wrappedValue ?? .square(-1) }
        set = { [weak self] in self?.wrappedValue = $0 as! Resolution }
        setFloats = { [weak self] in self?.wrappedValue = Resolution(floats: $0) }
    }
    
    public override func getLiveCodable() -> LiveCodable {
        LiveCodableResolution(resolution: wrappedValue, typeName: typeName, visibilityDepth: visibilityDepth, externalConnectedIDs: externalConnectedIDs)
    }
    
    public override func setLiveCodable(_ liveCodable: LiveCodable) {
        super.setLiveCodable(liveCodable)
        guard let liveCodableResolution: LiveCodableResolution = liveCodable as? LiveCodableResolution else { return }
        wrappedValue = liveCodableResolution.resolution
    }
    
}

public class LiveCodableResolution: LiveCodable {
    var resolution: Resolution
    init(resolution: Resolution, typeName: String, visibilityDepth: Int, externalConnectedIDs: [UUID]) {
        self.resolution = resolution
        super.init(typeName: typeName, type: .resolution, visibilityDepth: visibilityDepth, externalConnectedIDs: externalConnectedIDs)
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
