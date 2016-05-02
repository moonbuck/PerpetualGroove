//
//  OrderedDictionaryTests.swift
//  OrderedDictionaryTests
//
//  Created by Jason Cardwell on 2/25/16.
//  Copyright © 2016 Jason Cardwell. All rights reserved.
//

import XCTest
import Nimble
@testable import MoonKit
@testable import MoonKitTest

final class OrderedDictionaryTests: XCTestCase {
    
  func testCreation() {
    var orderedDictionary1 = OrderedDictionary<String, Int>(minimumCapacity: 8)
    expect(orderedDictionary1.capacity) >= 8
    expect(orderedDictionary1.count) == 0

    orderedDictionary1 = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5]
    expect(orderedDictionary1.capacity) >= 5
    expect(orderedDictionary1.count) == 5

    var orderedDictionary2 = OrderedDictionary<Int, String>(minimumCapacity: 8)
    expect(orderedDictionary2.capacity) >= 8
    expect(orderedDictionary2.count) == 0

    orderedDictionary2 = [1: "one", 2: "two", 3: "three", 4: "four", 5: "five"]
    expect(orderedDictionary2.capacity) >= 5
    expect(orderedDictionary2.count) == 5
  }

  func testInsertion() {
    var orderedDictionary1 = OrderedDictionary<String, Int>(minimumCapacity: 8)

    orderedDictionary1["one"] = 1
    expect(orderedDictionary1.count) == 1
    expect(orderedDictionary1["one"]) == 1
    expect(orderedDictionary1.values) == [1]

    orderedDictionary1["two"] = 2
    expect(orderedDictionary1.count) == 2
    expect(orderedDictionary1["two"]) == 2
    expect(orderedDictionary1.values) == [1, 2]

    orderedDictionary1["three"] = 3
    expect(orderedDictionary1.count) == 3
    expect(orderedDictionary1["three"]) == 3
    expect(orderedDictionary1.values) == [1, 2, 3]

    orderedDictionary1["four"] = 4
    expect(orderedDictionary1.count) == 4
    expect(orderedDictionary1["four"]) == 4
    expect(orderedDictionary1.values) == [1, 2, 3, 4]

    orderedDictionary1["five"] = 5
    expect(orderedDictionary1.count) == 5
    expect(orderedDictionary1["five"]) == 5
    expect(orderedDictionary1.values) == [1, 2, 3, 4, 5]

    var orderedDictionary2 = OrderedDictionary<Int, String>(minimumCapacity: 8)

    orderedDictionary2[1] = "one"
    expect(orderedDictionary2.count) == 1
    expect(orderedDictionary2[1]) == "one"
    expect(orderedDictionary2.values) == ["one"]

    orderedDictionary2[2] = "two"
    expect(orderedDictionary2.count) == 2
    expect(orderedDictionary2[2]) == "two"
    expect(orderedDictionary2.values) == ["one", "two"]

    orderedDictionary2[3] = "three"
    expect(orderedDictionary2.count) == 3
    expect(orderedDictionary2[3]) == "three"
    expect(orderedDictionary2.values) == ["one", "two", "three"]

    orderedDictionary2[4] = "four"
    expect(orderedDictionary2.count) == 4
    expect(orderedDictionary2[4]) == "four"
    expect(orderedDictionary2.values) == ["one", "two", "three", "four"]

    orderedDictionary2[5] = "five"
    expect(orderedDictionary2.count) == 5
    expect(orderedDictionary2[5]) == "five"
    expect(orderedDictionary2.values) == ["one", "two", "three", "four", "five"]
  }

  func testResize() {
    var orderedDictionary1 = OrderedDictionary<String, Int>(minimumCapacity: 8)
    orderedDictionary1["one"] = 1
    orderedDictionary1["two"] = 2
    orderedDictionary1["three"] = 3
    orderedDictionary1["four"] = 4
    orderedDictionary1["five"] = 5
    orderedDictionary1["six"] = 6
    expect(orderedDictionary1.values) == [1, 2, 3, 4, 5, 6]
    orderedDictionary1["seven"] = 7
    expect(orderedDictionary1.values) == [1, 2, 3, 4, 5, 6, 7]
    orderedDictionary1["eight"] = 8
    orderedDictionary1["nine"] = 9
    orderedDictionary1["ten"] = 10
    expect(orderedDictionary1.values) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

    var orderedDictionary2 = OrderedDictionary<Int, String>(minimumCapacity: 8)
    orderedDictionary2[1] = "one"
    orderedDictionary2[2] = "two"
    orderedDictionary2[3] = "three"
    orderedDictionary2[4] = "four"
    orderedDictionary2[5] = "five"
    orderedDictionary2[6] = "six"
    expect(orderedDictionary2.values) == ["one", "two", "three", "four", "five", "six"]
    orderedDictionary2[7] = "seven"
    expect(orderedDictionary2.values) == ["one", "two", "three", "four", "five", "six", "seven"]
    orderedDictionary2[8] = "eight"
    orderedDictionary2[9] = "nine"
    orderedDictionary2[10] = "ten"
    expect(orderedDictionary2.values) == ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]

  }

  func testDeletion() {
    var orderedDictionary1: OrderedDictionary<String, Int> = ["one": 1, "two": 2, "three": 3]
    expect(orderedDictionary1.values) == [1, 2, 3]
    orderedDictionary1["two"] = nil
    expect(orderedDictionary1.values) == [1, 3]
    orderedDictionary1["one"] = nil
    expect(orderedDictionary1.values) == [3]
    orderedDictionary1["two"] = 2
    orderedDictionary1["one"] = 1
    expect(orderedDictionary1.values) == [3, 2, 1]

    var orderedDictionary2: OrderedDictionary<Int, String> = [1: "one", 2: "two", 3: "three"]
    expect(orderedDictionary2.values) == ["one", "two", "three"]
    orderedDictionary2[2] = nil
    expect(orderedDictionary2.values) == ["one", "three"]
    orderedDictionary2[1] = nil
    expect(orderedDictionary2.values) == ["three"]
    orderedDictionary2[2] = "two"
    orderedDictionary2[1] = "one"
    expect(orderedDictionary2.values) == ["three", "two", "one"]

  }

  func testCOW() {
    var orderedDictionary1: OrderedDictionary<String, Int> = ["one": 1, "two": 2, "three": 3]
    var orderedDictionary2 = orderedDictionary1
    expect(orderedDictionary1.owner) === orderedDictionary2.owner
    expect(orderedDictionary1.buffer.storage) === orderedDictionary2.buffer.storage

    orderedDictionary2["four"] = 4
    expect(orderedDictionary1.owner) !== orderedDictionary2.owner
    expect(orderedDictionary1.buffer.storage) !== orderedDictionary2.buffer.storage
  }

  func testSubscriptAccessors() {
    var orderedDictionary: OrderedDictionary<String, Int> = ["one": 1, "two": 2, "three": 3]
    expect(orderedDictionary["two"]) == 2
    let (k, v) = orderedDictionary[1]
    expect(k) == "two"
    expect(v) == 2
  }

  func testPerformanceWithCapacityReserved() {
    measureBlock {
      var d = OrderedDictionary<Int, String>(minimumCapacity: 1500)
      for i in 0 ..< 1000 { d[i] = String(i) }
      for i in 0.stride(to: 1000, by: 3) { d[i] = nil }
      for i in 1000 ..< 1200 { d[i] = String(i) }
    }
  }

  func testPerformanceWithoutCapacityReserved() {
    measureBlock {
      var d: OrderedDictionary<Int, String> = [:]
      for i in 0 ..< 1000 { d[i] = String(i) }
      for i in 0.stride(to: 1000, by: 3) { d[i] = nil }
      for i in 1000 ..< 1200 { d[i] = String(i) }
    }

  }

  func testContainerAsValue() {
    var orderedDictionary = OrderedDictionary<String, Array<Int>>()
    orderedDictionary["first"] = [1, 2, 3, 4]
    orderedDictionary["second"] = [5, 6, 7, 8]
    orderedDictionary["third"] = [9, 10]
    expect(orderedDictionary.count) == 3
    expect(orderedDictionary[0].1) == [1, 2, 3, 4]
    expect(orderedDictionary[1].1) == [5, 6, 7, 8]
    expect(orderedDictionary[2].1) == [9, 10]
    var array = orderedDictionary[1].1
    array.appendContentsOf([11, 12, 13, 14, 15, 16, 17, 18, 19, 20])
    orderedDictionary["second"] = array
    expect(orderedDictionary[1].1) == [5, 6, 7, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
  }

}
