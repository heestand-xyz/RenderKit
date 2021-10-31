//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-04-22.
//

import Foundation

@propertyWrapper public class LiveInt: LiveWrap {
    
    let updateResolution: Bool
    
    public var wrappedValue: Int {
        didSet {
            guard wrappedValue != oldValue else { return }
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
    
    public init(wrappedValue: Int, _ typeName: String, name: String? = nil, range: ClosedRange<Int>, clamped: Bool = false, updateResolution: Bool = false) {
        self.wrappedValue = wrappedValue
        self.updateResolution = updateResolution
        super.init(type: .int, typeName: typeName, name: name, value: wrappedValue, min: range.lowerBound, max: range.upperBound, clamped: clamped)
        get = { [weak self] in self?.wrappedValue ?? -1 }
        set = { [weak self] in self?.wrappedValue = $0 as! Int }
        setFloats = { [weak self] in self?.wrappedValue = Int(floats: $0) }
    }
    
    public override func getLiveCodable() -> LiveCodable {
        LiveCodableInt(intValue: wrappedValue, typeName: typeName, visibilityDepth: visibilityDepth)
    }
    
    public override func setLiveCodable(_ liveCodable: LiveCodable) {
        super.setLiveCodable(liveCodable)
        guard let liveCodableInt: LiveCodableInt = liveCodable as? LiveCodableInt else { return }
        wrappedValue = liveCodableInt.intValue
    }

}

public class LiveCodableInt: LiveCodable {
    var intValue: Int
    init(intValue: Int, typeName: String, visibilityDepth: Int) {
        self.intValue = intValue
        super.init(typeName: typeName, type: .int, visibilityDepth: visibilityDepth)
    }
    enum CodingKeys: CodingKey {
        case intValue
    }
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intValue = try container.decode(Int.self, forKey: .intValue)
        try super.init(from: decoder)
    }
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(intValue, forKey: .intValue)
        try super.encode(to: encoder)
    }
}
