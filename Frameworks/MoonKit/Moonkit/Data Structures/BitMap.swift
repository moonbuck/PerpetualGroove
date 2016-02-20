//
//  BitMap.swift
//  MoonKit
//
//  Created by Jason Cardwell on 2/19/16.
//  Copyright © 2016 Jason Cardwell. All rights reserved.
//

import Foundation

/// A wrapper around a bitmap storage with room for at least bitCount bits.
/// This is a modified version of the `_BitMap` struct found in the swift stdlib source code
public struct BitMap {
  public let values: UnsafeMutablePointer<UInt>
  public let bitCount: Int

  // Note: We use UInt here to get unsigned math (shifts).
  @warn_unused_result
  public static func wordIndex(i: UInt) -> UInt {
    return i / UInt._sizeInBits
  }

  @warn_unused_result
  public static func bitIndex(i: UInt) -> UInt {
    return i % UInt._sizeInBits
  }

  @warn_unused_result
  public static func wordsFor(bitCount: Int) -> Int {
    return bitCount + sizeof(Int) - 1 / sizeof(Int)
  }

  public init(storage: UnsafeMutablePointer<UInt>, bitCount: Int) {
    self.bitCount = bitCount
    self.values = storage
  }

  public var numberOfWords: Int {
    @warn_unused_result
    get {
      return BitMap.wordsFor(bitCount)
    }
  }

  public func initializeToZero() {
    for i in 0 ..< numberOfWords {
      (values + i).initialize(0)
    }
  }

  public subscript(i: Int) -> Bool {
    @warn_unused_result
    get {
      precondition(i < Int(bitCount) && i >= 0, "index out of bounds")
      let idx = UInt(i)
      let word = values[Int(BitMap.wordIndex(idx))]
      let bit = word & (1 << BitMap.bitIndex(idx))
      return bit != 0
    }
    nonmutating set {
      precondition(i < Int(bitCount) && i >= 0, "index out of bounds")
      let idx = UInt(i)
      let wordIdx = BitMap.wordIndex(idx)
      if newValue {
        values[Int(wordIdx)] =
          values[Int(wordIdx)] | (1 << BitMap.bitIndex(idx))
      } else {
        values[Int(wordIdx)] =
          values[Int(wordIdx)] & ~(1 << BitMap.bitIndex(idx))
      }
    }
  }
}