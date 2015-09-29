//
//  Placement.swift
//  MidiSprite
//
//  Created by Jason Cardwell on 9/27/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import Foundation
import MoonKit

struct Placement {
  let position: CGPoint
  let vector: CGVector
  static let zero = Placement(position: .zero, vector: .zero)
  init(position p: CGPoint, vector v: CGVector) { position = p; vector = v }
}

extension Placement: ByteArrayConvertible {
  var bytes: [Byte] {
    let positionString = NSStringFromCGPoint(position)
    let vectorString = NSStringFromCGVector(vector)
    let string = "{\(positionString), \(vectorString)}"
    return Array(string.utf8)
  }
  init(_ bytes: [Byte]) {
    let castBytes = bytes.map({CChar($0)})
    guard let string = String.fromCString(castBytes) else { self = .zero; return }

    let float = "-?[0-9]+(?:\\.[0-9]+)?"
    let value = "\\{\(float), \(float)\\}"
    guard let match = (~/"\\{(\(value)), (\(value))\\}").firstMatch(string, anchored: true),
      positionCapture = match.captures[1],
      vectorCapture = match.captures[2] else { self = .zero; return }

    position = CGPointFromString(positionCapture.string)
    vector = CGVectorFromString(vectorCapture.string)
  }
}

extension Placement: CustomStringConvertible {
  var description: String {
    return "{ position: \(position.description(3)); vector: \(vector.description(3)) }"
  }
}

extension Placement: CustomDebugStringConvertible {
  var debugDescription: String {
    return "Placement { position: \(position.debugDescription); vector: \(vector.debugDescription) }"
  }
}