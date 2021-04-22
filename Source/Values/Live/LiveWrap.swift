//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-04-22.
//

import Foundation
import CoreGraphics

public class LiveWrap: Identifiable {
    
    public var name: String
    public var typeName: String
    
    public var defaultValue: Floatable
    public var minimumValue: Floatable?
    public var maximumValue: Floatable?
    public var incrementValue: Floatable?

    public var node: NODE!
    
    public enum LiveType {
        case bool
        case int
        case float
        case point
        case size
        case color
        case resolution
        case enumable
    }
    public let type: LiveType?
    
    public var get: (() -> (Floatable))!
    public var set: ((Floatable) -> ())!
    public var setFloats: (([CGFloat]) -> ())!

    public init(type: LiveType? = nil,
                typeName: String,
                name: String? = nil,
                value: Floatable,
                min: Floatable? = nil,
                max: Floatable? = nil,
                inc: Floatable? = nil) {
        
        precondition(!typeName.contains(" "))
        precondition(typeName.first!.isUppercase)
        
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
        
    }
        
}
