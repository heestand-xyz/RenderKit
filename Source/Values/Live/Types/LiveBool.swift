//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-04-22.
//

import Foundation

@propertyWrapper public class LiveBool: LiveWrap {
    
    let updateResolution: Bool
    
    public var wrappedValue: Bool {
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
        }
    }
    
    public var didSetValue: (() -> ())?
    
    public init(wrappedValue: Bool, _ typeName: String, name: String? = nil, updateResolution: Bool = false) {
        self.wrappedValue = wrappedValue
        self.updateResolution = updateResolution
        super.init(type: .bool, typeName: typeName, name: name, value: wrappedValue)
        get = { [weak self] in self?.wrappedValue ?? false }
        set = { [weak self] in self?.wrappedValue = $0 as! Bool }
        setFloats = { [weak self] in self?.wrappedValue = Bool(floats: $0) }
    }
    
    public override func getLiveCodable() -> LiveCodable {
        LiveCodableBool(boolValue: wrappedValue, typeName: typeName)
    }
    
    public override func setLiveCodable(_ liveCodable: LiveCodable) {
        guard let liveCodableBool: LiveCodableBool = liveCodable as? LiveCodableBool else { return }
        wrappedValue = liveCodableBool.boolValue
    }
    
}

public class LiveCodableBool: LiveCodable {
    var boolValue: Bool
    init(boolValue: Bool, typeName: String) {
        self.boolValue = boolValue
        super.init(typeName: typeName, type: .bool)
    }
    enum CodingKeys: CodingKey {
        case boolValue
    }
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        boolValue = try container.decode(Bool.self, forKey: .boolValue)
        try super.init(from: decoder)
    }
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(boolValue, forKey: .boolValue)
        try super.encode(to: encoder)
    }
}
