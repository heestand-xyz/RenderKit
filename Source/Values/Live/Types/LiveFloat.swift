//
//  Created by Anton Heestand on 2021-04-22.
//

import Foundation
import CoreGraphics

@propertyWrapper public class LiveFloat: LiveWrap {
    
    let updateResolution: Bool
    
    public var wrappedValue: CGFloat {
        didSet {
            guard wrappedValue != oldValue else { return }
            guard !isSkeleton else { return }
            guard let node: NODE = node else {
                print("RenderKit Live property wrapper not linked to node.")
                return
            }
            if updateResolution {
                node.applyResolution { [weak node] in
                    node?.render()
                }
            } else {
                node.render()
            }
            currentValueSubject.send(wrappedValue)
            didSetValue?()
            changed()
        }
    }
    
    public var didSetValue: (() -> ())?
    
    public init(wrappedValue: CGFloat, _ typeName: String, name: String? = nil, range: ClosedRange<CGFloat> = 0.0...1.0, increment: CGFloat = 0.25, clamped: Bool = false, updateResolution: Bool = false) {
        self.wrappedValue = wrappedValue
        self.updateResolution = updateResolution
        super.init(type: .float, typeName: typeName, name: name, value: wrappedValue, min: range.lowerBound, max: range.upperBound, inc: increment, clamped: clamped)
        get = { [weak self] in self?.wrappedValue ?? -1.0 }
        set = { [weak self] in self?.wrappedValue = $0 as! CGFloat }
        setFloats = { [weak self] in self?.wrappedValue = CGFloat(floats: $0) }
    }
    
    public override func getLiveCodable() -> LiveCodable {
        LiveCodableFloat(floatValue: wrappedValue, typeName: typeName, visibilityDepth: visibilityDepth, externalConnectedIDs: externalConnectedIDs)
    }
    
    public override func setLiveCodable(_ liveCodable: LiveCodable) {
        super.setLiveCodable(liveCodable)
        guard let liveCodableFloat: LiveCodableFloat = liveCodable as? LiveCodableFloat else { return }
        wrappedValue = liveCodableFloat.floatValue
    }

}

public class LiveCodableFloat: LiveCodable {
    var floatValue: CGFloat
    init(floatValue: CGFloat, typeName: String, visibilityDepth: Int, externalConnectedIDs: [UUID]) {
        self.floatValue = floatValue
        super.init(typeName: typeName, type: .float, visibilityDepth: visibilityDepth, externalConnectedIDs: externalConnectedIDs)
    }
    enum CodingKeys: CodingKey {
        case floatValue
    }
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        floatValue = try container.decode(CGFloat.self, forKey: .floatValue)
        try super.init(from: decoder)
    }
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(floatValue, forKey: .floatValue)
        try super.encode(to: encoder)
    }
}

