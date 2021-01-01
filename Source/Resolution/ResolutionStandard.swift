//
//  ResolutionStandard.swift
//  RenderKit
//
//  Created by Anton Heestand on 2019-10-04.
//  Copyright © 2019 Hexagons. All rights reserved.
//


import CoreGraphics
import Metal

public protocol ResolutionStandard: Equatable {
    
    var name: String { get }
    
    var rawWidth: Int { get }
    var rawHeight: Int { get }
    var rawDepth: Int { get }
    
    var count: Int { get }

    init(texture: MTLTexture)
    
    static func ==(lhs: Self, rhs: Self) -> Bool
    static func !=(lhs: Self, rhs: Self) -> Bool
    
    static func >(lhs: Self, rhs: Self) -> Bool?
    static func <(lhs: Self, rhs: Self) -> Bool?
    static func >=(lhs: Self, rhs: Self) -> Bool?
    static func <=(lhs: Self, rhs: Self) -> Bool?
    
    static func +(lhs: Self, rhs: Self) -> Self
    static func -(lhs: Self, rhs: Self) -> Self
    static func *(lhs: Self, rhs: Self) -> Self
    
    static func +(lhs: Self, rhs: CGFloat) -> Self
    static func -(lhs: Self, rhs: CGFloat) -> Self
    static func *(lhs: Self, rhs: CGFloat) -> Self
    static func /(lhs: Self, rhs: CGFloat) -> Self
    static func +(lhs: CGFloat, rhs: Self) -> Self
    static func -(lhs: CGFloat, rhs: Self) -> Self
    static func *(lhs: CGFloat, rhs: Self) -> Self
    
    static func +(lhs: Self, rhs: Int) -> Self
    static func -(lhs: Self, rhs: Int) -> Self
    static func *(lhs: Self, rhs: Int) -> Self
    static func /(lhs: Self, rhs: Int) -> Self
    static func +(lhs: Int, rhs: Self) -> Self
    static func -(lhs: Int, rhs: Self) -> Self
    static func *(lhs: Int, rhs: Self) -> Self
    
    static func +(lhs: Self, rhs: Double) -> Self
    static func -(lhs: Self, rhs: Double) -> Self
    static func *(lhs: Self, rhs: Double) -> Self
    static func /(lhs: Self, rhs: Double) -> Self
    static func +(lhs: Double, rhs: Self) -> Self
    static func -(lhs: Double, rhs: Self) -> Self
    static func *(lhs: Double, rhs: Self) -> Self
    
    static func +(lhs: Self, rhs: CGFloat) -> Self
    static func -(lhs: Self, rhs: CGFloat) -> Self
    static func *(lhs: Self, rhs: CGFloat) -> Self
    static func /(lhs: Self, rhs: CGFloat) -> Self
    static func +(lhs: CGFloat, rhs: Self) -> Self
    static func -(lhs: CGFloat, rhs: Self) -> Self
    static func *(lhs: CGFloat, rhs: Self) -> Self
    
}
