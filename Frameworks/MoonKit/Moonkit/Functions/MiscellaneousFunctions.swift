//
//  MiscellaneousFunctions.swift
//  MoonKit
//
//  Created by Jason Cardwell on 5/8/15.
//  Copyright (c) 2015 Jason Cardwell. All rights reserved.
//

import Foundation

/**
nonce

- returns: String
*/
public func nonce() -> String { return NSUUID().UUIDString }

public func gcd<T:IntegerArithmeticType>(a: T, _ b: T) -> IntMax {
  var aMax = a.toIntMax(), bMax = b.toIntMax()
  while bMax != 0 {
    let t = bMax
    bMax = aMax % bMax
    aMax = t
  }
  return aMax
}
public func lcm<T:IntegerArithmeticType>(a: T, _ b: T) -> IntMax {
  let aMax = a.toIntMax()
  let bMax = b.toIntMax()
  return aMax / gcd(aMax, bMax) * bMax
}

/**
typeName:

- parameter object: Any

- returns: String
*/
public func typeName(object: Any) -> String { return _stdlib_getDemangledTypeName(object) }

/** Ticks since last device reboot */
public var hostTicks: UInt64 { return mach_absolute_time() }

/** Nanoseconds since last reboot */
public var hostTime: UInt64 { return UInt64(Float80(hostTicks) * nanosecondsPerHostTick) }

/** Ratio that represents the number of nanoseconds per host tick */
public var nanosecondsPerHostTick: Ratio<Float80> {
  var info = mach_timebase_info()
  mach_timebase_info(&info)
  return info.numer∶info.denom
}

