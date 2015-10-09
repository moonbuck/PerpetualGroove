//
//  CGVector+MoonKitAdditions.swift
//  MoonKit
//
//  Created by Jason Cardwell on 10/8/15.
//  Copyright © 2015 Jason Cardwell. All rights reserved.
//

import Foundation

extension CGVector {
  public init?(_ string: String?) { if let s = string { self = CGVectorFromString(s) } else { return nil } }
  public static var nullVector: CGVector = CGVector(dx: CGFloat.NaN, dy: CGFloat.NaN)
  public var isNull: Bool { return dx.isNaN || dy.isNaN }
  public func dxDelta(vector: CGVector) -> CGFloat { return vector.isNull ? dx : dx - vector.dx }
  public func dyDelta(vector: CGVector) -> CGFloat { return vector.isNull ? dy : dy - vector.dy }
  public func delta(vector: CGVector) -> CGVector { return self - vector }
  public func absDXDelta(vector: CGVector) -> CGFloat { return abs(dxDelta(vector)) }
  public func absDYDelta(vector: CGVector) -> CGFloat { return abs(dyDelta(vector)) }
  public func absDelta(vector: CGVector) -> CGVector { return (self - vector).absolute }
  public var absolute: CGVector { return isNull ? self : CGVector(dx: abs(dx), dy: abs(dy)) }
  public init(_ point: CGPoint) { dx = point.x; dy = point.y }
  public var max: CGFloat { return dy > dx ? dy : dx }
  public var min: CGFloat { return dy < dx ? dy : dx }
  public func description(precision: Int) -> String {
    return precision >= 0 ? "(\(dx.rounded(precision)), \(dy.rounded(precision)))" : description
  }
}
extension CGVector: NilLiteralConvertible {
  public init(nilLiteral: ()) { self = CGVector.nullVector }
}

extension CGVector: CustomStringConvertible {
  public var description: String { return "(\(dx), \(dy))" }
}
extension CGVector: CustomDebugStringConvertible {
  public var debugDescription: String { return NSStringFromCGVector(self) }
}

extension CGVector: Unpackable2 {
  public var unpack: (CGFloat, CGFloat) { return (dx, dy) }
}

extension CGVector: Packable2 {
  public init(_ elements: (CGFloat, CGFloat)) { self.init(dx: elements.0, dy: elements.1) }
}

//public func -(lhs: CGVector, rhs: CGVector) -> CGVector {
//  return lhs.isNull ? rhs : (rhs.isNull ? lhs : CGVector(dx: lhs.dx - rhs.dx, dy: lhs.dy - rhs.dy))
//}
//public func +(lhs: CGVector, rhs: CGVector) -> CGVector {
//  return lhs.isNull ? rhs : (rhs.isNull ? lhs : CGVector(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy))
//}
//public func -=(inout lhs: CGVector, rhs: CGVector) { lhs = lhs - rhs }
//public func +=(inout lhs: CGVector, rhs: CGVector) { lhs = lhs + rhs }
//public func /(lhs: CGVector, rhs: CGVector) -> CGVector { return CGVector(dx: lhs.dx / rhs.dx, dy: lhs.dy / rhs.dy) }
public func /(lhs: CGVector, rhs: CGFloat) -> CGVector { return CGVector(dx: lhs.dx / rhs, dy: lhs.dy / rhs) }
public func /=(inout lhs: CGVector, rhs: CGFloat) { lhs = lhs / rhs }
public func *(lhs: CGVector, rhs: CGFloat) -> CGVector { return CGVector(dx: lhs.dx * rhs, dy: lhs.dy * rhs) }
//public func *(lhs: CGVector, rhs: CGVector) -> CGVector { return CGVector(dx: lhs.dx * rhs.dx, dy: lhs.dy * rhs.dy) }
public func *=(inout lhs: CGVector, rhs: CGFloat) { lhs = lhs * rhs }

public func sum<S:SequenceType where S.Generator.Element == CGVector>(s: S) -> CGVector {
  return s.reduce(CGVector(), combine: +)
}
