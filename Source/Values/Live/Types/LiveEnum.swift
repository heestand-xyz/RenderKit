//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-04-22.
//

import Foundation

@propertyWrapper public class LiveEnum<E: Enumable>: LiveEnumWrap {
    
    let updateResolution: Bool
    
    public var wrappedValue: E {
        didSet {
            guard wrappedValue.index != oldValue.index else { return }
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
    
    public init(wrappedValue: E, _ typeName: String, name: String? = nil, updateResolution: Bool = false) {
        self.updateResolution = updateResolution
        self.wrappedValue = wrappedValue
        super.init(typeName, name: name, rawIndex: wrappedValue.rawIndex, rawIndices: E.allCases.map(\.rawIndex), names: E.names)
        get = { [weak self] in self?.wrappedValue.rawIndex ?? 0 }
        set = { [weak self] in self?.wrappedValue = E(rawIndex: $0 as! Int) }
        setFloats = { [weak self] in self?.wrappedValue = E(rawIndex: Int(floats: $0)) }
    }
    
    public override func getLiveCodable() -> LiveCodable {
        LiveCodableEnum(caseTypeName: wrappedValue.typeName, typeName: typeName)
    }

    public override func setLiveCodable(_ liveCodable: LiveCodable) {
        guard let liveCodableEnum: LiveCodableEnum = liveCodable as? LiveCodableEnum else { return }
        wrappedValue = E(typeName: liveCodableEnum.caseTypeName) ?? E.allCases.first!
    }

}

public class LiveCodableEnum: LiveCodable {
    var caseTypeName: String
    init(caseTypeName: String, typeName: String) {
        self.caseTypeName = caseTypeName
        super.init(typeName: typeName, type: .enum)
    }
    enum CodingKeys: CodingKey {
        case caseTypeName
    }
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        caseTypeName = try container.decode(String.self, forKey: .caseTypeName)
        try super.init(from: decoder)
    }
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(caseTypeName, forKey: .caseTypeName)
        try super.encode(to: encoder)
    }
}
