//: Playground - noun: a place where people can play

import Foundation
import MoonKit

let url = NSBundle.mainBundle().URLForResource("PropertyListTest", withExtension: "plist")!
let rawPropertyList = try! String(contentsOfURL: url)

enum PropertyListTag: String {

  case xml
  case DOCTYPE
  case plist
  case dict
  case key
  case integer
  case string
  case array
  case real
  case `true`
  case `false`
  case null

  var regex: RegularExpression {
    switch self {
    case .xml:
      return ~/"^\\s*<\\?xml\\s+version\\s*=\\s*\"[0-9.]+\"\\s+encoding\\s*=\\s*\"[^\"]+\"\\s*\\?>\\s*"
    case .DOCTYPE:
      return ~/"^\\s*<!DOCTYPE\\s+plist\\s+PUBLIC\\s+\"-//Apple//DTD PLIST 1.0//EN\"\\s+\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"\\s*>\\s*"
    case .plist:
      return ~/"^\\s*<plist\\s+version\\s*=\\s*\"[0-9.]+\"\\s*>((?:.|\\s)*)</plist>\\s*$"
    case .dict:
      return ~/"^\\s*<dict>((?:(?:.|\\s)(?!=<dict>))*)</dict>\\s*"
    case .key:
      return ~/"^\\s*<key>((?:.|\\s)*?)</key>\\s*"
    case .integer:
      return ~/"^\\s*<integer>((?:.|\\s)*)</integer>\\s*"
    case .string:
      return ~/"^\\s*<string>((?:.|\\s)*?)</string>\\s*"
    case .array:
      return ~/"^\\s*<array>((?:.|\\s)*)</array>\\s*"
    case .real:
      return ~/"^\\s*<real>((?:.|\\s)*?)</real>\\s*"
    case .`true`:
      return ~/"^\\s*<true\\s*/>\\s*"
    case .`false`:
      return ~/"^\\s*<false\\s*/>\\s*"
    case .null:
      return ~/"^\\s*<null\\s*/>\\s*"
    }
  }

}

enum PropertyListValue {
  case Boolean(Bool)
  case String(Swift.String)
  case Array(Swift.Array<PropertyListValue>)
  case Dictionary(Swift.Dictionary<Swift.String, PropertyListValue>)
  case Integer(Int)
  case Real(Double)
  case Null
}

func parseTag(tag: PropertyListTag, input: String) -> (match: Bool, tagContent: String?, remainingInput: String?) {
  guard let match = tag.regex.match(input).first else { return (false, nil, input) }
  let tagContent = match[1]?.string
  let remainingInput = input[match.range.endIndex.samePositionIn(input)!..<]
  return (true, tagContent, remainingInput.isEmpty ? nil : remainingInput)
}

enum PropertyListPrimitive {
  case String (Swift.String)
  case Int (Swift.Int)
  case Double (Swift.Double)
  case Bool (Swift.Bool)
  case None
}

func parsePrimitive(input: String) -> (match: Bool, primitive: PropertyListPrimitive, remainingInput: String?) {
//  print("\n\n\(#function)  input = '\(input)'")

  let result: (Bool, PropertyListPrimitive, String?)
//  defer {
//    print("\(#function)  result: \(result)")
//  }

  var (match, tagContent, remainingInput) = parseTag(.string, input: input)
  guard !match else {
    guard let stringContent = tagContent else {
      // Throw error
      fatalError("invalid string tag")
    }
    result = (true, PropertyListPrimitive.String(stringContent), remainingInput)
    return result
  }
  (match, tagContent, remainingInput) = parseTag(.integer, input: input)
  guard !match else {
    guard let integerContent = tagContent, integer = Int(integerContent) else {
      // Throw error
      fatalError("invalid integer tag")
    }
    result = (true, PropertyListPrimitive.Int(integer), remainingInput)
    return result
  }
  (match, tagContent, remainingInput) = parseTag(.real, input: input)
  guard !match else {
    guard let realContent = tagContent, real = Double(realContent) else {
      // Throw error
      fatalError("invalid integer tag")
    }
    result = (true, PropertyListPrimitive.Double(real), remainingInput)
    return result
  }

  (match, tagContent, remainingInput) = parseTag(.`true`, input: input)
  guard !match else {
    result = (true, PropertyListPrimitive.Bool(true), remainingInput)
    return result
  }

  (match, tagContent, remainingInput) = parseTag(.`false`, input: input)
  guard !match else {
    result = (true, PropertyListPrimitive.Bool(false), remainingInput)
    return result
  }

  result = (false, PropertyListPrimitive.None, input)
  return result
}

func parseValue(input: String) -> (match: Bool, value: PropertyListValue, remainingInput: String?) {
//  print("\n\n\(#function)  input = '\(input)'")

  let result: (Bool, PropertyListValue, String?)
//  defer {
//    print("\(#function)  result: \(result)")
//  }

  let primitiveParse = parsePrimitive(input)
  guard !primitiveParse.match else {
    let remainingInput = primitiveParse.remainingInput != nil && primitiveParse.remainingInput!.isEmpty ? nil : primitiveParse.remainingInput
    switch primitiveParse.primitive {
      case .String(let s): result = (true, .String(s),  remainingInput)
      case .Int(let i):    result = (true, .Integer(i), remainingInput)
      case .Double(let d): result = (true, .Real(d),    remainingInput)
      case .Bool(let b):   result = (true, .Boolean(b), remainingInput)
      case .None:          result = (true, .Null,       remainingInput)
    }
    return result
  }

  let arrayParse = parseTag(.array, input: input)
  guard !arrayParse.match else {
    guard let arrayContent = arrayParse.tagContent else {
      // Throw error
      fatalError("invalid array tag")
    }
    let array = parseArrayContent(arrayContent)
    let remainingInput = arrayParse.remainingInput != nil && arrayParse.remainingInput!.isEmpty ? nil : arrayParse.remainingInput
    result = (true, .Array(array), remainingInput)
    return result
  }

  let dictParse = parseTag(.dict, input: input)
  guard dictParse.match else {
    // Throw error
    fatalError("failed to match primitive, array or dict inside array content")
  }
  guard let dictContent = dictParse.tagContent else {
    // Throw error
    fatalError("invalid dict tag")
  }
  let dict = parseDictContent(dictContent)
  let remainingInput = dictParse.remainingInput != nil && dictParse.remainingInput!.isEmpty ? nil : dictParse.remainingInput
  result = (true, .Dictionary(dict), remainingInput)
  return result
}

func parseArrayContent(input: String) -> [PropertyListValue] {
//  print("\n\n\(#function)  input = '\(input)'")

  var result: [PropertyListValue] = []

  var remainingInput: String? = input
  while let currentInput = remainingInput {
    let (match, value, remainingInputʹ) = parseValue(currentInput)
    guard match else {
      // Throw error
      fatalError("failed to parse value where a value is expected")
    }

    result.append(value)
    remainingInput = remainingInputʹ
    if remainingInput != nil && remainingInput!.isEmpty { remainingInput = nil }
  }

//  print("\(#function)  result = \(result)")
  return result
}

func parseDictContent(input: String) -> [String:PropertyListValue] {
//  print("\n\n\(#function)  input = '\(input)'")

  var result: [String:PropertyListValue] = [:]

  var remainingInput: String? = input
  while let currentInput = remainingInput {
//    print("\n\ncurrentInput = '\(currentInput)'")
    let keyParse = parseTag(.key, input: currentInput)
    guard keyParse.match, let key = keyParse.tagContent, remainingInputʹ = keyParse.remainingInput else {
      // Throw error
      fatalError("invalid key tag or key tag without a matching value")
    }
    let (match, value, remainingInputʺ) = parseValue(remainingInputʹ)
    guard match else {
      // Throw error 
      fatalError("failed to parse value where value is expected")
    }
    result[key] = value
    remainingInput = remainingInputʺ
    if remainingInput != nil && remainingInput!.isEmpty { remainingInput = nil }
  }

//  print("\(#function)  result = \(result)")

  return result
}

func parsePropertyList(list: String) -> PropertyListValue {
//  print("\n\n\(#function)  list = '\(list)'")

  var (match, tagContent, remainingInput) = parseTag(.xml, input: list)

  guard match && remainingInput != nil else {
    // Throw error
    return .Null
  }

  (match, tagContent, remainingInput) = parseTag(.DOCTYPE, input: remainingInput!)
  guard match && remainingInput != nil else {
    // Throw error
    return .Null
  }

  (match, tagContent, remainingInput) = parseTag(.plist, input: remainingInput!)
  guard match, let plistContent = tagContent else {
    // Throw error
    return .Null
  }

  (match, tagContent, remainingInput) = parseTag(.dict, input: plistContent)

  guard match, let dictContent = tagContent else {
    (match, tagContent, remainingInput) = parseTag(.array, input: plistContent)
    guard match, let arrayContent = tagContent else {
      // Throw error
      return .Null
    }

//    print("arrayContent: \(arrayContent)")

    let array = parseArrayContent(arrayContent)
    return .Array(array)
  }

//  print(dictContent)
  let dict = parseDictContent(dictContent)
  return .Dictionary(dict)
}

let parsedObject = parsePropertyList(rawPropertyList)
print("parsedObject = \(parsedObject)")

/*
 
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Subtests</key>
	<array>
		<dict>
			<key>PerformanceMetrics</key>
			<array>
				<dict>
					<key>BaselineAverage</key>
					<real>0.15525</real>
					<key>BaselineName</key>
					<string>Local Baseline</string>
					<key>Identifier</key>
					<string>com.apple.XCTPerformanceMetric_WallClockTime</string>
					<key>MaxPercentRegression</key>
					<integer>10</integer>
					<key>MaxPercentRelativeStandardDeviation</key>
					<integer>10</integer>
					<key>MaxRegression</key>
					<real>0.10000000000000001</real>
					<key>MaxStandardDeviation</key>
					<real>0.10000000000000001</real>
					<key>Measurements</key>
					<array>
						<real>0.11162454600000001</real>
						<real>0.18490079000000001</real>
						<real>0.16682532999999999</real>
						<real>0.166004442</real>
						<real>0.16396802799999999</real>
						<real>0.16736647800000001</real>
						<real>0.16668433599999999</real>
						<real>0.16198454400000001</real>
						<real>0.16385017700000001</real>
						<real>0.15839913</real>
					</array>
					<key>Name</key>
					<string>Time</string>
					<key>UnitOfMeasurement</key>
					<string>seconds</string>
				</dict>
			</array>
			<key>TestIdentifier</key>
			<string>OrderedDictionaryPerformanceTests/testInsertValueForKeyPerformance()</string>
			<key>TestName</key>
			<string>testInsertValueForKeyPerformance()</string>
			<key>TestObjectClass</key>
			<string>IDESchemeActionTestSummary</string>
			<key>TestStatus</key>
			<string>Success</string>
			<key>TestSummaryGUID</key>
			<string>6861729D-EA6D-44A3-A49B-97BEF04F4F27</string>
		</dict>
		<dict>
			<key>PerformanceMetrics</key>
			<array>
				<dict>
					<key>BaselineAverage</key>
					<real>0.38169999999999998</real>
					<key>BaselineName</key>
					<string>May 25, 2016, 7:20:52 AM</string>
					<key>Identifier</key>
					<string>com.apple.XCTPerformanceMetric_WallClockTime</string>
					<key>MaxPercentRegression</key>
					<integer>10</integer>
					<key>MaxPercentRelativeStandardDeviation</key>
					<integer>10</integer>
					<key>MaxRegression</key>
					<real>0.10000000000000001</real>
					<key>MaxStandardDeviation</key>
					<real>0.10000000000000001</real>
					<key>Measurements</key>
					<array>
						<real>0.39553471200000001</real>
						<real>0.39544263400000002</real>
						<real>0.40088641699999999</real>
						<real>0.40136458000000003</real>
						<real>0.40363773200000003</real>
						<real>0.39683162999999999</real>
						<real>0.39860546000000002</real>
						<real>0.39481618200000002</real>
						<real>0.402274309</real>
						<real>0.39425138599999998</real>
					</array>
					<key>Name</key>
					<string>Time</string>
					<key>UnitOfMeasurement</key>
					<string>seconds</string>
				</dict>
			</array>
			<key>TestIdentifier</key>
			<string>OrderedDictionaryPerformanceTests/testOverallPerformance()</string>
			<key>TestName</key>
			<string>testOverallPerformance()</string>
			<key>TestObjectClass</key>
			<string>IDESchemeActionTestSummary</string>
			<key>TestStatus</key>
			<string>Success</string>
			<key>TestSummaryGUID</key>
			<string>3285FC19-4502-4325-B48B-DC3262B73303</string>
		</dict>
		<dict>
			<key>FailureSummaries</key>
			<array>
				<dict>
					<key>FileName</key>
					<string>/Users/Moondeer/Projects/PerpetualGroove/Frameworks/MoonKit/OrderedDictionaryTests/OrderedDictionaryPerformanceTests.swift</string>
					<key>LineNumber</key>
					<integer>41</integer>
					<key>Message</key>
					<string>failed: Time average is 569% worse (max allowed: 10%).</string>
					<key>PerformanceFailure</key>
					<true/>
				</dict>
			</array>
			<key>PerformanceMetrics</key>
			<array>
				<dict>
					<key>BaselineAverage</key>
					<real>0.09171</real>
					<key>BaselineName</key>
					<string>Local Baseline</string>
					<key>Identifier</key>
					<string>com.apple.XCTPerformanceMetric_WallClockTime</string>
					<key>MaxPercentRegression</key>
					<integer>10</integer>
					<key>MaxPercentRelativeStandardDeviation</key>
					<integer>10</integer>
					<key>MaxRegression</key>
					<real>0.10000000000000001</real>
					<key>MaxStandardDeviation</key>
					<real>0.10000000000000001</real>
					<key>Measurements</key>
					<array>
						<real>0.61691075299999998</real>
						<real>0.61683504</real>
						<real>0.61665684799999998</real>
						<real>0.61645478399999998</real>
						<real>0.61712898400000005</real>
						<real>0.61524738599999995</real>
						<real>0.60780837700000001</real>
						<real>0.605083174</real>
						<real>0.611933108</real>
						<real>0.61072429299999997</real>
					</array>
					<key>Name</key>
					<string>Time</string>
					<key>UnitOfMeasurement</key>
					<string>seconds</string>
				</dict>
			</array>
			<key>TestIdentifier</key>
			<string>OrderedDictionaryPerformanceTests/testRemoveValueForKeyPerformance()</string>
			<key>TestName</key>
			<string>testRemoveValueForKeyPerformance()</string>
			<key>TestObjectClass</key>
			<string>IDESchemeActionTestSummary</string>
			<key>TestStatus</key>
			<string>Failure</string>
			<key>TestSummaryGUID</key>
			<string>E2AA730B-3D2F-40EB-9E77-7728726AD518</string>
		</dict>
	</array>
	<key>TestIdentifier</key>
	<string>OrderedDictionaryPerformanceTests</string>
	<key>TestName</key>
	<string>OrderedDictionaryPerformanceTests</string>
	<key>TestObjectClass</key>
	<string>IDESchemeActionTestSummaryGroup</string>
</dict>
</plist>

*/
