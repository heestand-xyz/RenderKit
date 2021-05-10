//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-04-22.
//

import CoreGraphics

@propertyWrapper public class LivePoint: LiveWrap {
    
    public var wrappedValue: CGPoint {
        didSet {
            guard wrappedValue != oldValue else { return }
            guard let node: NODE = node else {
                print("RenderKit Live property wrapper not linked to node.")
                return
            }
            node.render()
            currentValueSubject.send(wrappedValue)
        }
    }
    
    public init(wrappedValue: CGPoint, _ typeName: String, name: String? = nil) {
        self.wrappedValue = wrappedValue
        super.init(type: .point, typeName: typeName, name: name, value: wrappedValue, min: CGPoint(x: -1.0, y: -1.0), max: CGPoint(x: 1.0, y: 1.0))
        get = { self.wrappedValue }
        set = { self.wrappedValue = $0 as! CGPoint }
        setFloats = { self.wrappedValue = CGPoint(floats: $0) }
    }
    
    public override func getLiveCodable() -> LiveCodable {
        LiveCodablePoint(point: wrappedValue, typeName: typeName)
    }
    
    public override func setLiveCodable(_ liveCodable: LiveCodable) {
        guard let liveCodablePoint: LiveCodablePoint = liveCodable as? LiveCodablePoint else { return }
        wrappedValue = liveCodablePoint.point
    }
    
}

public class LiveCodablePoint: LiveCodable {
    var point: CGPoint
    init(point: CGPoint, typeName: String) {
        self.point = point
        super.init(typeName: typeName, type: .point)
    }
    enum CodingKeys: CodingKey {
        case point
    }
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        point = try container.decode(CGPoint.self, forKey: .point)
        try super.init(from: decoder)
    }
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(point, forKey: .point)
        try super.encode(to: encoder)
    }
}
