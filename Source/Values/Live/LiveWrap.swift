//
//  Created by Anton Heestand on 2021-04-22.
//

import Foundation
import CoreGraphics
import Combine

public enum LiveType: String, Codable {
    
    case bool
    case int
    case float
    case point
    case size
    case vector
    case color
    case resolution
    case resolution3d
    case `enum`
    
    public var liveCodableType: LiveCodable.Type {
        switch self {
        case .bool:
            return LiveCodableBool.self
        case .int:
            return LiveCodableInt.self
        case .float:
            return LiveCodableFloat.self
        case .point:
            return LiveCodablePoint.self
        case .size:
            return LiveCodableSize.self
        case .vector:
            return LiveCodableVector.self
        case .color:
            return LiveCodableColor.self
        case .resolution:
            return LiveCodableResolution.self
        case .resolution3d:
            return LiveCodableResolution3D.self
        case .enum:
            return LiveCodableEnum.self
        }
    }
}

public class LiveWrap: Identifiable {
    
    public var name: String
    public var typeName: String
    
    public var defaultValue: Floatable
    public var minimumValue: Floatable?
    public var maximumValue: Floatable?
    public var incrementValue: Floatable?
    public var clamped: Bool

    public weak var node: NODE?
    
    public let type: LiveType
    
    public var visibilityDepth: Int
    public var externalConnectedIDs: [UUID]
    
    public var get: (() -> (Floatable))!
    public var set: ((Floatable) -> ())!
    public var setFloats: (([CGFloat]) -> ())!
    
    public lazy var currentValueSubject: CurrentValueSubject<Floatable, Never> = .init(defaultValue)
    
    var isSkeleton: Bool = false
    
    public init(type: LiveType,
                typeName: String,
                name: String? = nil,
                value: Floatable,
                min: Floatable? = nil,
                max: Floatable? = nil,
                inc: Floatable? = nil,
                clamped: Bool = false) {
        
        precondition(!typeName.contains(" "))
        precondition(typeName.first!.isLowercase)
        
        func camelToTitleCased(_ string: String) -> String {
            if string.count <= 1 {
                return string.uppercased()
            }
            let regex = try! NSRegularExpression(pattern: "(?=\\S)[A-Z]", options: [])
            let range = NSMakeRange(1, string.count - 1)
            var titlecased = regex.stringByReplacingMatches(in: string, range: range, withTemplate: " $0")
            for i in titlecased.indices {
                if i == titlecased.startIndex || titlecased[titlecased.index(before: i)] == " " {
                    titlecased.replaceSubrange(i...i, with: String(titlecased[i]).uppercased())
                }
            }
            return titlecased
        }
        
        self.type = type
        self.typeName = typeName
        self.name = name ?? camelToTitleCased(typeName)
        
        defaultValue = value
        
        minimumValue = min
        maximumValue = max
        incrementValue = inc
        self.clamped = clamped
        
        visibilityDepth = 0
        externalConnectedIDs = []
    }
    
    public func getLiveCodable() -> LiveCodable {
        LiveCodable(typeName: typeName, type: type, visibilityDepth: visibilityDepth, externalConnectedIDs: externalConnectedIDs)
    }
    
    public func setLiveCodable(_ liveCodable: LiveCodable) {
        visibilityDepth = liveCodable.visibilityDepth
        externalConnectedIDs = liveCodable.externalConnectedIDs
    }
        
    public static func skeleton(liveCodable: LiveCodable) -> LiveWrap {
        let liveWrap: LiveWrap
        switch liveCodable {
        case is LiveCodableBool:
            liveWrap = LiveBool(wrappedValue: false, liveCodable.typeName)
        case is LiveCodableColor:
            liveWrap = LiveColor(wrappedValue: .clear, liveCodable.typeName)
        case is LiveCodableEnum:
            liveWrap = LiveEnum(wrappedValue: EmptyLiveEnum.empty, liveCodable.typeName)
        case is LiveCodableFloat:
            liveWrap = LiveFloat(wrappedValue: 0.0, liveCodable.typeName)
        case is LiveCodableInt:
            liveWrap = LiveInt(wrappedValue: 0, liveCodable.typeName, range: 0...1)
        case is LiveCodablePoint:
            liveWrap = LivePoint(wrappedValue: .zero, liveCodable.typeName)
        case is LiveCodableResolution:
            liveWrap = LiveResolution(wrappedValue: .zero, liveCodable.typeName)
        case is LiveCodableResolution3D:
            liveWrap = LiveResolution3D(wrappedValue: .zero, liveCodable.typeName)
        case is LiveCodableSize:
            liveWrap = LiveSize(wrappedValue: .zero, liveCodable.typeName)
        case is LiveCodableVector:
            liveWrap = LiveVector(wrappedValue: .zero, liveCodable.typeName)
        default:
            fatalError("Live Codable is Unknown")
        }
        liveWrap.setLiveCodable(liveCodable)
        liveWrap.isSkeleton = true
        return liveWrap
    }
    
    func changed() {
        node?.liveValueChanged()
    }
}

public class LiveCodable: Codable {
    
    public var typeName: String
    public let type: LiveType
    public var visibilityDepth: Int
    public var externalConnectedIDs: [UUID]
    
    init(typeName: String, type: LiveType, visibilityDepth: Int, externalConnectedIDs: [UUID]) {
        self.typeName = typeName
        self.type = type
        self.visibilityDepth = visibilityDepth
        self.externalConnectedIDs = externalConnectedIDs
    }
    
    enum CodingKeys: CodingKey {
        case typeName
        case type
        case visibilityDepth
        case externalConnectedIDs
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        typeName = try container.decode(String.self, forKey: .typeName)
        type = try container.decode(LiveType.self, forKey: .type)
        visibilityDepth = try container.decodeIfPresent(Int.self, forKey: .visibilityDepth) ?? 0
        externalConnectedIDs = try container.decodeIfPresent([UUID].self, forKey: .externalConnectedIDs) ?? []
    }
}

extension LiveWrap: Equatable {
    
    public static func == (lhs: LiveWrap, rhs: LiveWrap) -> Bool {
        lhs.typeName == rhs.typeName
    }
}
