//
//  OrderedDictionarySlice.swift
//  MoonKit
//
//  Created by Jason Cardwell on 5/5/16.
//  Copyright © 2016 Jason Cardwell. All rights reserved.
//

import Foundation

public struct OrderedDictionarySlice<Key:Hashable, Value>: _OrderedDictionary, _DestructorSafeContainer {

  typealias Buffer = OrderedDictionarySliceBuffer<Key, Value>
  typealias Storage = OrderedDictionaryStorage<Key, Value>

  public typealias Index = Int
  public typealias Element = (Key, Value)
  public typealias _Element = Element
  public typealias SubSequence = OrderedDictionarySlice<Key, Value>

  var buffer: Buffer

  var capacity: Int { return buffer.capacity }

  /// Returns a new buffer backed by storage cloned from the existing buffer.
  /// Unreachable elements are not copied; however, `startIndex` and `endIndex` values are preserved.
  func cloneBuffer(newCapacity: Int) -> Buffer {
    var clone = Buffer(minimumCapacity: newCapacity, offsetBy: startIndex)

    for position in buffer.indices {
      let bucket = buffer.bucketForPosition(position)
      let (key, value) = buffer.elementInBucket(bucket)
      clone.initializeKey(key, forValue: value, position: position)
      clone.endIndex += 1
    }

    clone.storage.count = buffer.count

    return clone
  }

  /// Checks that `owner` has only the one strong reference and that it's `buffer` has at least `minimumCapacity` capacity
  mutating func ensureUniqueWithCapacity(minimumCapacity: Int) -> (reallocated: Bool, capacityChanged: Bool) {
    switch (isUnique: buffer.isUniquelyReferenced(), hasCapacity: capacity >= minimumCapacity) {

      case (isUnique: true, hasCapacity: true):
        return (reallocated: false, capacityChanged: false)

      case (isUnique: true, hasCapacity: false):
        buffer = cloneBuffer(Buffer.minimumCapacityForCount(minimumCapacity))
        return (reallocated: true, capacityChanged: true)

      case (isUnique: false, hasCapacity: true):
        buffer = cloneBuffer(capacity)
        return (reallocated: true, capacityChanged: false)

      case (isUnique: false, hasCapacity: false):
        buffer = cloneBuffer(Buffer.minimumCapacityForCount(minimumCapacity))
        return (reallocated: true, capacityChanged: true)
    }

  }

  init(buffer: Buffer) { self.buffer = buffer }

  init(minimumCapacity: Int) {
    buffer = Buffer(minimumCapacity: minimumCapacity)
  }

  mutating func _removeAtIndex(index: Index, oldElement: UnsafeMutablePointer<Element>) {
    if oldElement != nil { oldElement.initialize(buffer.elementInBucket(buffer.bucketForPosition(index))) }
    ensureUniqueWithCapacity(capacity)
    buffer.destroyElementAt(index)
  }

  mutating func _removeValueForKey(key: Key, oldValue: UnsafeMutablePointer<Value?>) {
    guard let index = buffer.positionForKey(key) else {
      if oldValue != nil { oldValue.initialize(nil) }
      return
    }
    if oldValue != nil {
      let oldElement = UnsafeMutablePointer<Element>.alloc(1)
      _removeAtIndex(index, oldElement: oldElement)
      oldValue.initialize(oldElement.memory.1)
    } else {
      _removeAtIndex(index, oldElement: nil)
    }
  }

  mutating func _updateValue(value: Value,
                             forKey key: Key,
                                    oldValue: UnsafeMutablePointer<Value?>,
                                    oldKey: UnsafeMutablePointer<Key?>)
  {
    var (bucket, found) = buffer.find(key)

    if oldValue != nil || oldKey != nil {
      if found {
        let (key, value) = buffer.elementInBucket(bucket)
        if oldKey != nil { oldKey.initialize(key) }
        if oldValue != nil { oldValue.initialize(value) }
      } else {
        if oldKey != nil { oldKey.initialize(nil) }
        if oldValue != nil { oldValue.initialize(nil) }
      }
    }

    let minCapacity = found
      ? capacity
      : Buffer.minimumCapacityForCount(buffer.count + 1)

    let (_, capacityChanged) = ensureUniqueWithCapacity(minCapacity)
    if capacityChanged { (bucket, found) = buffer.find(key) }

    if found {
      buffer.setValue(value, inBucket: bucket)
    } else {
      buffer.initializeKey(key, forValue: value, bucket: bucket)
      buffer.endIndex += 1
    }
  }

  public init(elements: [Element]) {
    var keys: Set<Int> = []
    var filteredElements: [Element] = []
    for element in elements where !keys.contains(element.0.hashValue) {
      keys.insert(element.0.hashValue)
      filteredElements.append(element)
    }
    let buffer = Buffer(elements: filteredElements)
    self.init(buffer: buffer)
  }

}

// MARK: DictionaryLiteralConvertible
extension OrderedDictionarySlice: DictionaryLiteralConvertible {

  public init(dictionaryLiteral elements: Element...) {
    self.init(elements: elements)
  }

}

// MARK: MutableKeyValueCollection
extension OrderedDictionarySlice: MutableKeyValueCollection {

  /// Access the value associated with the given key.
  /// Reading a key that is not present in self yields nil. Writing nil as the value for a given key erases that key from self.
  /// - attention: Is there a conflict when `Key` = `Index` or do the differing return types resolve ambiguity?
  public subscript(key: Key) -> Value? {
    get { return buffer.valueForKey(key) }
    set {
      if let value = newValue { _updateValue(value, forKey: key, oldValue: nil, oldKey: nil) }
      else { _removeValueForKey(key, oldValue: nil) }
    }
  }

  public mutating func insertValue(value: Value, forKey key: Key) {
    _updateValue(value, forKey: key, oldValue: nil, oldKey: nil)
  }

  /// Removes the value associated with `key` and returns it. Returns `nil` if `key` is not present.
  public mutating func removeValueForKey(key: Key) -> Value? {
    let oldValue = UnsafeMutablePointer<Value?>.alloc(1)
    _removeValueForKey(key, oldValue: oldValue)
    return oldValue.memory
  }

  public mutating func updateValue(value: Value, forKey key: Key) -> Value? {
    let oldValue = UnsafeMutablePointer<Value?>.alloc(1)
    _updateValue(value, forKey: key, oldValue: oldValue, oldKey: nil)
    return oldValue.memory
  }

  /// Returns the index of `key` or `nil` if `key` is not present.
  public func indexForKey(key: Key) -> Index? { return buffer.positionForKey(key) }

  /// Returns the value associated with `key` or `nil` if `key` is not present.
  public func valueForKey(key: Key) -> Value? { return buffer.valueForKey(key) }

  public mutating func removeAtIndex(index: Index) -> Element {
    let oldElement = UnsafeMutablePointer<Element>.alloc(1)
    _removeAtIndex(index, oldElement: oldElement)
    return oldElement.memory
  }

}

// MARK: MutableCollectionType
extension OrderedDictionarySlice: MutableCollectionType {

  public var startIndex: Int { return buffer.startIndex }
  public var endIndex: Int  { return buffer.endIndex }

  public subscript(index: Index) -> Element {
    get { return buffer[index] }
    set {
      ensureUniqueWithCapacity(count)
      buffer.replaceElementAtPosition(index, with: newValue)
    }
  }

  public subscript(subRange: Range<Index>) -> SubSequence {
    get {
      precondition(indices.contains(subRange))
      return SubSequence(buffer: buffer[subRange])
    }
    set {
      replaceRange(subRange, with: newValue)
    }
  }

}

// MARK: RangeReplaceableCollectionType
extension OrderedDictionarySlice: RangeReplaceableCollectionType {

  public init() { buffer = Buffer() }

  public mutating func replaceRange<
    C:CollectionType where C.Generator.Element == Element
    >(subRange: Range<Index>, with newElements: C)
  {
    let requiredCapacity = count - subRange.count + numericCast(newElements.count)
    ensureUniqueWithCapacity(requiredCapacity)

    // Replace with uniqued collection
    buffer.replaceRange(subRange, with: newElements)
  }

}


// MARK: CustomStringConvertible
extension OrderedDictionarySlice: CustomStringConvertible {
  public var description: String {
    guard count > 0 else { return "[:]" }

    var result = "["
    var first = true
    for (key, value) in self {
      if first { first = false } else { result += ", " }
      debugPrint(key, terminator: "", toStream: &result)
      result += ": "
      debugPrint(value, terminator: "", toStream: &result)
    }
    result += "]"
    return result
  }
}

// MARK: Equatable
extension OrderedDictionarySlice: Equatable {}

public func == <Key: Hashable, Value>
  (lhs: OrderedDictionarySlice<Key, Value>, rhs: OrderedDictionarySlice<Key, Value>) -> Bool
{

  guard !(lhs.buffer.identity == rhs.buffer.identity && lhs.startIndex == rhs.startIndex && lhs.endIndex == rhs.endIndex) else { return true }

  for ((k1, _), (k2, _)) in zip(lhs, rhs) {
    guard k1 == k2 else { return false }
  }

  return lhs.count == rhs.count
}


public func == <Key: Hashable, Value: Equatable>
  (lhs: OrderedDictionarySlice<Key, Value>, rhs: OrderedDictionarySlice<Key, Value>) -> Bool
{

  guard !(lhs.buffer.identity == rhs.buffer.identity && lhs.startIndex == rhs.startIndex && lhs.endIndex == rhs.endIndex) else { return true }

  for ((k1, v1), (k2, v2)) in zip(lhs, rhs) {
    guard k1 == k2 && v1 == v2 else { return false }
  }

  return lhs.count == rhs.count
}
