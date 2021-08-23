//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-04-22.
//

import PixelColor

@propertyWrapper public class LiveColor: LiveWrap {
    
    public var wrappedValue: PixelColor {
        didSet {
            guard wrappedValue.components != oldValue.components else { return }
            guard let node: NODE = node else {
                print("RenderKit Live property wrapper not linked to node.")
                return
            }
            node.render()
            currentValueSubject.send(wrappedValue)
            didSetValue?()
        }
    }
    
    public var didSetValue: (() -> ())?
    
    public init(wrappedValue: PixelColor, _ typeName: String, name: String? = nil) {
        self.wrappedValue = wrappedValue
        super.init(type: .color, typeName: typeName, name: name, value: wrappedValue)
        get = { [weak self] in self?.wrappedValue ?? .clear }
        set = { [weak self] in self?.wrappedValue = $0 as! PixelColor }
        setFloats = { [weak self] in self?.wrappedValue = PixelColor(floats: $0) }
    }
    
    public override func getLiveCodable() -> LiveCodable {
        LiveCodableColor(color: wrappedValue, typeName: typeName)
    }
    
    public override func setLiveCodable(_ liveCodable: LiveCodable) {
        guard let liveCodableColor: LiveCodableColor = liveCodable as? LiveCodableColor else { return }
        wrappedValue = liveCodableColor.color
    }

}

public class LiveCodableColor: LiveCodable {
    var color: PixelColor
    init(color: PixelColor, typeName: String) {
        self.color = color
        super.init(typeName: typeName, type: .color)
    }
    enum CodingKeys: CodingKey {
        case color
    }
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        color = try container.decode(PixelColor.self, forKey: .color)
        try super.init(from: decoder)
    }
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(color, forKey: .color)
        try super.encode(to: encoder)
    }
}

