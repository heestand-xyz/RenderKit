//
//  Created by Anton Heestand on 2021-04-22.
//

import Foundation

public class LiveEnumWrap: LiveWrap {
    public let rawIndices: [Int]
    public let names: [String]
    public var dynamicTypeNames: [String] {
        names.map { $0.lowercased().replacingOccurrences(of: " ", with: "-") }
    }
    public var currentCaseDynamicTypeName: String {
        let rawIndex: Int = self.get() as! Int
        guard let index: Int = rawIndices.firstIndex(of: rawIndex) else { return "" }
        guard index < dynamicTypeNames.count else { return "" }
        return dynamicTypeNames[index]
    }
    public var defaultCaseDynamicTypeName: String {
        let rawIndex: Int = defaultValue as! Int
        guard let index: Int = rawIndices.firstIndex(of: rawIndex) else { return "" }
        guard index < dynamicTypeNames.count else { return "" }
        return dynamicTypeNames[index]
    }
    public init(_ typeName: String, name: String? = nil, rawIndex: Int, rawIndices: [Int], names: [String]) {
        self.rawIndices = rawIndices
        self.names = names
        super.init(type: .enum, typeName: typeName, name: name, value: rawIndex)
    }
    public func setCase(typeName: String) {
        guard let index: Int = dynamicTypeNames.firstIndex(where: { $0 == typeName }) else { return }
        guard index < rawIndices.count else { return }
        let rawIndex: Int = rawIndices[index]
        set(rawIndex)
    }
}
