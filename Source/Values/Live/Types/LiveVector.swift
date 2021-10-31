//
//  LiveVector.swift
//  
//
//  Created by Anton Heestand on 2021-04-22.
//

import simd

@propertyWrapper public class LiveVector: LiveWrap {
    
    public var wrappedValue: SIMD3<Double> {
        didSet {
            guard wrappedValue != oldValue else { return }
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
    
    public init(wrappedValue: SIMD3<Double>, _ typeName: String, name: String? = nil) {
        self.wrappedValue = wrappedValue
        super.init(type: .vector, typeName: typeName, name: name, value: wrappedValue, min: SIMD3<Double>(x: 0.0, y: 0.0, z: 0.0), max: SIMD3<Double>(x: 1.0, y: 1.0, z: 1.0))
        get = { [weak self] in self?.wrappedValue ?? SIMD3<Double>(x: -1.0, y: -1.0, z: -1.0) }
        set = { [weak self] in self?.wrappedValue = $0 as! SIMD3<Double> }
        setFloats = { [weak self] in self?.wrappedValue = SIMD3<Double>(floats: $0) }
    }
    
    public override func getLiveCodable() -> LiveCodable {
        LiveCodableVector(vector: wrappedValue, typeName: typeName, visibilityDepth: visibilityDepth)
    }
    
    public override func setLiveCodable(_ liveCodable: LiveCodable) {
        super.setLiveCodable(liveCodable)
        guard let liveCodableVector: LiveCodableVector = liveCodable as? LiveCodableVector else { return }
        wrappedValue = liveCodableVector.vector
    }
    
}

public class LiveCodableVector: LiveCodable {
    var vector: SIMD3<Double>
    init(vector: SIMD3<Double>, typeName: String, visibilityDepth: Int) {
        self.vector = vector
        super.init(typeName: typeName, type: .vector, visibilityDepth: visibilityDepth)
    }
    enum CodingKeys: CodingKey {
        case vector
    }
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vector = try container.decode(SIMD3<Double>.self, forKey: .vector)
        try super.init(from: decoder)
    }
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(vector, forKey: .vector)
        try super.encode(to: encoder)
    }
}
