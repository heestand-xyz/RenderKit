//
//  Created by Anton Heestand on 2021-04-22.
//

import Foundation
import CoreGraphics

@propertyWrapper public class LiveSize: LiveWrap {
    
    public var wrappedValue: CGSize {
        didSet {
            guard wrappedValue != oldValue else { return }
            guard !isSkeleton else { return }
            guard let node: NODE = node else {
                print("RenderKit Live property wrapper not linked to node.")
                return
            }
            node.render()
            currentValueSubject.send(wrappedValue)
            didSetValue?()
            changed()
        }
    }
    
    public var didSetValue: (() -> ())?
    
    public init(wrappedValue: CGSize, _ typeName: String, name: String? = nil) {
        self.wrappedValue = wrappedValue
        super.init(type: .size, typeName: typeName, name: name, value: wrappedValue, min: CGSize(width: 0.0, height: 0.0), max: CGSize(width: 2.0, height: 2.0))
        get = { [weak self] in self?.wrappedValue ?? CGSize(width: -1.0, height: -1.0) }
        set = { [weak self] in self?.wrappedValue = $0 as! CGSize }
        setFloats = { [weak self] in self?.wrappedValue = CGSize(floats: $0) }
    }
    
    public override func getLiveCodable() -> LiveCodable {
        LiveCodableSize(size: wrappedValue, typeName: typeName, visibilityDepth: visibilityDepth, externalConnectedIDs: externalConnectedIDs)
    }
    
    public override func setLiveCodable(_ liveCodable: LiveCodable) {
        super.setLiveCodable(liveCodable)
        guard let liveCodableSize: LiveCodableSize = liveCodable as? LiveCodableSize else { return }
        wrappedValue = liveCodableSize.size
    }
    
}

public class LiveCodableSize: LiveCodable {
    var size: CGSize
    init(size: CGSize, typeName: String, visibilityDepth: Int, externalConnectedIDs: [UUID]) {
        self.size = size
        super.init(typeName: typeName, type: .size, visibilityDepth: visibilityDepth, externalConnectedIDs: externalConnectedIDs)
    }
    enum CodingKeys: CodingKey {
        case size
    }
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        size = try container.decode(CGSize.self, forKey: .size)
        try super.init(from: decoder)
    }
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(size, forKey: .size)
        try super.encode(to: encoder)
    }
}
