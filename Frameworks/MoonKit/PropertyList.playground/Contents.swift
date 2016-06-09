//: Playground - noun: a place where people can play

import Foundation
import MoonKit

let url = NSBundle.mainBundle().URLForResource("D03A9A18-C46E-47C0-B132-832976AFC356_TestSummaries", withExtension: "plist")!
let rawPropertyList = try! String(contentsOfURL: url)

typealias Matcher = (String) -> (Bool, String, String)



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
      return ~/"\\s*<\\?xml\\s+version\\s*=\\s*\"[0-9.]+\"\\s+encoding\\s*=\\s*\"[^\"]+\"\\s*\\?>"
    case .DOCTYPE:
      return ~/"\\s*<!DOCTYPE\\s+plist\\s+PUBLIC\\s+\"-//Apple//DTD PLIST 1.0//EN\"\\s+\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"\\s*>"
    case .plist:
      return ~/"\\s*<plist\\s+version\\s*=\\s*\"[0-9.]+\"\\s*>((?:.|\\s)*)</plist>\\s*$"
    case .dict:
      return ~/"\\s*<dict>((?:.|\\s)*)</dict>\\s*"
    case .key:
      return ~/"\\s*<key>((?:.|\\s)*)</key>\\s*"
    case .integer:
      return ~/"\\s*<integer>((?:.|\\s)*)</integer>\\s*"
    case .string:
      return ~/"\\s*<string>((?:.|\\s)*)</string>\\s*"
    case .array:
      return ~/"\\s*<array>((?:.|\\s)*)</array>\\s*"
    case .real:
      return ~/"\\s*<real>((?:.|\\s)*)</real>\\s*"
    case .`true`:
      return ~/"\\s*<true\\s*/>\\s*"
    case .`false`:
      return ~/"\\s*<false\\s*/>\\s*"
    case .null:
      return ~/"\\s*<null\\s*/>\\s*"
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
  return (true, match[1]?.string, String(input.utf16[match.range.endIndex..<]))
}

enum PropertyListPrimitive {
  case String (Swift.String)
  case Int (Swift.Int)
  case Double (Swift.Double)
  case Bool (Swift.Bool)
  case None
}

func parsePrimitive(input: String) -> (match: Bool, primitive: PropertyListPrimitive, remainingInput: String?) {
  print("\n\n\(#function)  input = '\(input)'")

  var (match, tagContent, remainingInput) = parseTag(.string, input: input)
  guard !match else {
    guard let stringContent = tagContent else {
      // Throw error
      fatalError("invalid string tag")
    }
    return (true, PropertyListPrimitive.String(stringContent), remainingInput)
  }
  (match, tagContent, remainingInput) = parseTag(.integer, input: input)
  guard !match else {
    guard let integerContent = tagContent, integer = Int(integerContent) else {
      // Throw error
      fatalError("invalid integer tag")
    }
    return (true, PropertyListPrimitive.Int(integer), remainingInput)
  }
  (match, tagContent, remainingInput) = parseTag(.real, input: input)
  guard !match else {
    guard let realContent = tagContent, real = Double(realContent) else {
      // Throw error
      fatalError("invalid integer tag")
    }
    return (true, PropertyListPrimitive.Double(real), remainingInput)
  }

  (match, tagContent, remainingInput) = parseTag(.`true`, input: input)
  guard !match else {
    return (true, PropertyListPrimitive.Bool(true), remainingInput)
  }

  (match, tagContent, remainingInput) = parseTag(.`false`, input: input)
  guard !match else {
    return (true, PropertyListPrimitive.Bool(false), remainingInput)
  }

  return (false, PropertyListPrimitive.None, input)
}

func parseValue(input: String) -> (match: Bool, value: PropertyListValue, remainingInput: String?) {
  print("\n\n\(#function)  input = '\(input)'")

  let primitiveParse = parsePrimitive(input)
  guard !primitiveParse.match else {
    switch primitiveParse.primitive {
      case .String(let s): return (true, .String(s),  primitiveParse.remainingInput)
      case .Int(let i):    return (true, .Integer(i), primitiveParse.remainingInput)
      case .Double(let d): return (true, .Real(d),    primitiveParse.remainingInput)
      case .Bool(let b):   return (true, .Boolean(b), primitiveParse.remainingInput)
      case .None:          return (true, .Null,       primitiveParse.remainingInput)
    }
  }

  let arrayParse = parseTag(.array, input: input)
  guard !arrayParse.match else {
    guard let arrayContent = arrayParse.tagContent else {
      // Throw error
      fatalError("invalid array tag")
    }
    let array = parseArrayContent(arrayContent)
    return (true, .Array(array), arrayParse.remainingInput)
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
  return (true, .Dictionary(dict), dictParse.remainingInput)
}

func parseArrayContent(input: String) -> [PropertyListValue] {
  print("\n\n\(#function)  input = '\(input)'")

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
  }

  return result
}

func parseDictContent(input: String) -> [String:PropertyListValue] {
  print("\n\n\(#function)  input = '\(input)'")

  var result: [String:PropertyListValue] = [:]

  var remainingInput: String? = input
  while let currentInput = remainingInput {
    print("\n\ncurrentInput = '\(currentInput)'")
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
  }

  return result
}

func parsePropertyList(list: String) -> PropertyListValue {
  print("\n\n\(#function)  list = '\(list)'")

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
	<key>FormatVersion</key>
	<string>1.2</string>
	<key>RunDestination</key>
	<dict>
		<key>LocalComputer</key>
		<dict>
			<key>BusSpeedInMHz</key>
			<integer>100</integer>
			<key>CPUCount</key>
			<integer>1</integer>
			<key>CPUKind</key>
			<string>Intel Core i7</string>
			<key>CPUSpeedInMHz</key>
			<integer>2700</integer>
			<key>Identifier</key>
			<string>DDAADFE4-B874-5CA1-A924-4C69F2BFE2E4</string>
			<key>IsConcreteDevice</key>
			<true/>
			<key>LogicalCPUCoresPerPackage</key>
			<integer>8</integer>
			<key>ModelCode</key>
			<string>MacBookPro10,1</string>
			<key>ModelName</key>
			<string>MacBook Pro</string>
			<key>ModelUTI</key>
			<string>com.apple.macbookpro-15-retina-display</string>
			<key>Name</key>
			<string>My Mac</string>
			<key>NativeArchitecture</key>
			<string>x86_64</string>
			<key>OperatingSystemVersion</key>
			<string>10.11.4</string>
			<key>OperatingSystemVersionWithBuildNumber</key>
			<string>10.11.4 (15E65)</string>
			<key>PhysicalCPUCoresPerPackage</key>
			<integer>4</integer>
			<key>Platform</key>
			<dict>
				<key>Identifier</key>
				<string>com.apple.platform.macosx</string>
				<key>Name</key>
				<string>OS X</string>
			</dict>
			<key>RAMSizeInMegabytes</key>
			<integer>16384</integer>
		</dict>
		<key>Name</key>
		<string>iPad Air 2</string>
		<key>TargetArchitecture</key>
		<string>x86_64</string>
		<key>TargetDevice</key>
		<dict>
			<key>Identifier</key>
			<string>07FD8EB9-A094-4641-BF85-48610A82859C</string>
			<key>IsConcreteDevice</key>
			<true/>
			<key>ModelCode</key>
			<string>iPad5,4</string>
			<key>ModelName</key>
			<string>iPad Air 2</string>
			<key>ModelUTI</key>
			<string>com.apple.ipad-air2-a1567-b4b5b9</string>
			<key>Name</key>
			<string>iPad Air 2</string>
			<key>NativeArchitecture</key>
			<string>x86_64</string>
			<key>OperatingSystemVersion</key>
			<string>9.3</string>
			<key>OperatingSystemVersionWithBuildNumber</key>
			<string>9.3 (13E230)</string>
			<key>Platform</key>
			<dict>
				<key>Identifier</key>
				<string>com.apple.platform.iphonesimulator</string>
				<key>Name</key>
				<string>iOS Simulator</string>
			</dict>
		</dict>
		<key>TargetSDK</key>
		<dict>
			<key>Identifier</key>
			<string>iphonesimulator9.3</string>
			<key>IsInternal</key>
			<false/>
			<key>Name</key>
			<string>Simulator - iOS 9.3</string>
			<key>OperatingSystemVersion</key>
			<string>9.3</string>
		</dict>
	</dict>
	<key>TestableSummaries</key>
	<array>
		<dict>
			<key>ProjectPath</key>
			<string>PerpetualGroove/Frameworks/MoonKit/MoonKit.xcodeproj</string>
			<key>TargetName</key>
			<string>OrderedDictionaryTests</string>
			<key>TestName</key>
			<string>OrderedDictionaryTests</string>
			<key>TestObjectClass</key>
			<string>IDESchemeActionTestableSummary</string>
			<key>Tests</key>
			<array>
				<dict>
					<key>Subtests</key>
					<array>
						<dict>
							<key>Subtests</key>
							<array>
								<dict>
									<key>Subtests</key>
									<array>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testAppend()</string>
											<key>TestName</key>
											<string>testAppend()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>03A4AA7E-E8C3-42A0-A2F3-556C87B6B4AE</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testAppendContentsOf()</string>
											<key>TestName</key>
											<string>testAppendContentsOf()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>1EED7700-47F7-49D5-920C-628E7D64AB17</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testContainerAsValue()</string>
											<key>TestName</key>
											<string>testContainerAsValue()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>CA6CEFC3-A372-4AD5-BA92-09776864E099</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testCOW()</string>
											<key>TestName</key>
											<string>testCOW()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>85760411-F3BA-4E13-9E03-458714156EDB</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testCreation()</string>
											<key>TestName</key>
											<string>testCreation()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>27EC9C67-FA14-4F63-9934-A4F7C455D115</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testEquatable()</string>
											<key>TestName</key>
											<string>testEquatable()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>20991436-F4C3-455D-9D3A-D73A900FED2D</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testIndexForKey()</string>
											<key>TestName</key>
											<string>testIndexForKey()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>35F7AFC6-7C9A-4511-9BA9-59DCE4A468B3</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testInsertAtIndex()</string>
											<key>TestName</key>
											<string>testInsertAtIndex()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>87F95036-9455-4B37-889E-B9B6523B02B4</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testInsertContentsOfAtIndex()</string>
											<key>TestName</key>
											<string>testInsertContentsOfAtIndex()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>4E57908B-28E7-4ABA-B2B7-904670C4AD72</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testInsertValueForKey()</string>
											<key>TestName</key>
											<string>testInsertValueForKey()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>B9BF89B1-02EC-4D7A-B5EB-DAC5339950FE</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testKeys()</string>
											<key>TestName</key>
											<string>testKeys()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>583C8637-0870-427C-99C8-AB26CBA3A0D5</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testPrefix()</string>
											<key>TestName</key>
											<string>testPrefix()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>0DC877BD-24AF-49E6-9261-B5ADAE35C2A2</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testRemoveAll()</string>
											<key>TestName</key>
											<string>testRemoveAll()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>E14C88D7-CA58-403B-A55E-4E94D0B28C0C</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testRemoveAtIndex()</string>
											<key>TestName</key>
											<string>testRemoveAtIndex()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>357DBD0D-FD82-4F31-9321-FB75B87856EC</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testRemoveRange()</string>
											<key>TestName</key>
											<string>testRemoveRange()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>D071D061-6497-4DFC-A780-BA92765D1639</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testRemoveValueForKey()</string>
											<key>TestName</key>
											<string>testRemoveValueForKey()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>BCE65D7A-D960-47A7-AC58-9368731E37FE</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testReplaceRange()</string>
											<key>TestName</key>
											<string>testReplaceRange()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>F6CE6D63-319B-4F1C-A0F9-6F3D152A872A</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testResize()</string>
											<key>TestName</key>
											<string>testResize()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>7983B1CF-3CFE-485F-904E-AEC84915BAC9</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testSubscriptIndexAccessors()</string>
											<key>TestName</key>
											<string>testSubscriptIndexAccessors()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>43FA9418-8826-4709-A56F-16DD8DD27342</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testSubscriptKeyAccessors()</string>
											<key>TestName</key>
											<string>testSubscriptKeyAccessors()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>6B6BB15A-4F60-467D-BF30-B051431EDD4A</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testSubscriptRangeAccessors()</string>
											<key>TestName</key>
											<string>testSubscriptRangeAccessors()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>74C7068A-BF11-4A99-81DB-A5ACD31FD679</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testSuffix()</string>
											<key>TestName</key>
											<string>testSuffix()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>FF8439F5-8C80-4F4B-A10A-FCB59DCDB2BD</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testUpdateValueForKey()</string>
											<key>TestName</key>
											<string>testUpdateValueForKey()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>D5672A16-0ED4-49C6-A1B3-A82104A5C795</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedDictionaryBehaviorTests/testValues()</string>
											<key>TestName</key>
											<string>testValues()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>C43F4BB0-FB04-4CB7-84C5-17EE4F136351</string>
										</dict>
									</array>
									<key>TestIdentifier</key>
									<string>OrderedDictionaryBehaviorTests</string>
									<key>TestName</key>
									<string>OrderedDictionaryBehaviorTests</string>
									<key>TestObjectClass</key>
									<string>IDESchemeActionTestSummaryGroup</string>
								</dict>
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
							</array>
							<key>TestIdentifier</key>
							<string>OrderedDictionaryTests.xctest</string>
							<key>TestName</key>
							<string>OrderedDictionaryTests.xctest</string>
							<key>TestObjectClass</key>
							<string>IDESchemeActionTestSummaryGroup</string>
						</dict>
					</array>
					<key>TestIdentifier</key>
					<string>Selected tests</string>
					<key>TestName</key>
					<string>Selected tests</string>
					<key>TestObjectClass</key>
					<string>IDESchemeActionTestSummaryGroup</string>
				</dict>
			</array>
		</dict>
		<dict>
			<key>ProjectPath</key>
			<string>PerpetualGroove/Frameworks/MoonKit/MoonKit.xcodeproj</string>
			<key>TargetName</key>
			<string>OrderedSetTests</string>
			<key>TestName</key>
			<string>OrderedSetTests</string>
			<key>TestObjectClass</key>
			<string>IDESchemeActionTestableSummary</string>
			<key>Tests</key>
			<array>
				<dict>
					<key>Subtests</key>
					<array>
						<dict>
							<key>Subtests</key>
							<array>
								<dict>
									<key>Subtests</key>
									<array>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedSetBehaviorTests/testCOW()</string>
											<key>TestName</key>
											<string>testCOW()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>4099C135-5CB5-4C39-8999-3E688E20ED12</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedSetBehaviorTests/testCreation()</string>
											<key>TestName</key>
											<string>testCreation()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>AF97135F-DEDA-4CAF-A09A-420DBB82F37C</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedSetBehaviorTests/testDeletion()</string>
											<key>TestName</key>
											<string>testDeletion()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>1F36708F-47CF-469D-BA9E-7D9C8CD6984E</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedSetBehaviorTests/testDisjointWith()</string>
											<key>TestName</key>
											<string>testDisjointWith()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>A5538CB9-7193-4575-AD17-967AEB33CC8E</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedSetBehaviorTests/testInsertion()</string>
											<key>TestName</key>
											<string>testInsertion()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>98D1DD9E-2779-4458-BDC1-06CBDE014932</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedSetBehaviorTests/testIntersection()</string>
											<key>TestName</key>
											<string>testIntersection()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>24635EA5-5533-4C07-A6A2-9E0FD342D8B6</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedSetBehaviorTests/testReplaceRange()</string>
											<key>TestName</key>
											<string>testReplaceRange()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>ADAD6EB2-A4D6-42F5-A5A3-CE41AEE08D0C</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedSetBehaviorTests/testResize()</string>
											<key>TestName</key>
											<string>testResize()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>730B881E-326D-4CDD-B22C-C270DE4F2EE1</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedSetBehaviorTests/testStrictSubsetOf()</string>
											<key>TestName</key>
											<string>testStrictSubsetOf()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>895862CF-C021-447D-8999-80E88B8A8349</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedSetBehaviorTests/testStrictSupersetOf()</string>
											<key>TestName</key>
											<string>testStrictSupersetOf()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>8317226C-9EB2-4233-A953-695FC768AC52</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedSetBehaviorTests/testSubscriptIndexAccessors()</string>
											<key>TestName</key>
											<string>testSubscriptIndexAccessors()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>0CA4904A-3470-4B00-9231-797F7D35C5BF</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedSetBehaviorTests/testSubscriptRangAccssors()</string>
											<key>TestName</key>
											<string>testSubscriptRangAccssors()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>33072F39-A2DF-4A70-88D4-DF9AAE18F97F</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedSetBehaviorTests/testSubsetOf()</string>
											<key>TestName</key>
											<string>testSubsetOf()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>EB53F8AD-2AE3-40FA-8308-40720FCA98D2</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedSetBehaviorTests/testSubtract()</string>
											<key>TestName</key>
											<string>testSubtract()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>41630FE7-5C91-43ED-A90B-CFE278534D42</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedSetBehaviorTests/testSupersetOf()</string>
											<key>TestName</key>
											<string>testSupersetOf()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>4EE3C224-A649-44CF-ACA9-B8E446E597B1</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedSetBehaviorTests/testUnion()</string>
											<key>TestName</key>
											<string>testUnion()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>F346A49A-6CC8-4D5A-B12A-2DF7FF23410B</string>
										</dict>
										<dict>
											<key>TestIdentifier</key>
											<string>OrderedSetBehaviorTests/testXOR()</string>
											<key>TestName</key>
											<string>testXOR()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>AB340029-913B-41D9-99EE-77CDF81A21C2</string>
										</dict>
									</array>
									<key>TestIdentifier</key>
									<string>OrderedSetBehaviorTests</string>
									<key>TestName</key>
									<string>OrderedSetBehaviorTests</string>
									<key>TestObjectClass</key>
									<string>IDESchemeActionTestSummaryGroup</string>
								</dict>
								<dict>
									<key>Subtests</key>
									<array>
										<dict>
											<key>PerformanceMetrics</key>
											<array>
												<dict>
													<key>BaselineAverage</key>
													<real>0.69099999999999995</real>
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
														<real>0.71242164699999999</real>
														<real>0.64892235399999998</real>
														<real>0.70059479499999999</real>
														<real>0.69852904900000001</real>
														<real>0.69762727599999996</real>
														<real>0.70305436600000004</real>
														<real>0.70613881000000001</real>
														<real>0.69277959</real>
														<real>0.69926682299999998</real>
														<real>0.69365585600000002</real>
													</array>
													<key>Name</key>
													<string>Time</string>
													<key>UnitOfMeasurement</key>
													<string>seconds</string>
												</dict>
											</array>
											<key>TestIdentifier</key>
											<string>OrderedSetPerformanceTests/testDeletePerformance()</string>
											<key>TestName</key>
											<string>testDeletePerformance()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>41B1E49C-4BFA-4264-A6BE-7D73C85580C3</string>
										</dict>
										<dict>
											<key>PerformanceMetrics</key>
											<array>
												<dict>
													<key>BaselineAverage</key>
													<real>0.03056</real>
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
														<real>0.024489315000000001</real>
														<real>0.029021113000000001</real>
														<real>0.027147434000000002</real>
														<real>0.027457974999999999</real>
														<real>0.027551841000000001</real>
														<real>0.034055831000000002</real>
														<real>0.032901985000000002</real>
														<real>0.027980542000000001</real>
														<real>0.02746409</real>
														<real>0.029743018</real>
													</array>
													<key>Name</key>
													<string>Time</string>
													<key>UnitOfMeasurement</key>
													<string>seconds</string>
												</dict>
											</array>
											<key>TestIdentifier</key>
											<string>OrderedSetPerformanceTests/testInsertionPerformance()</string>
											<key>TestName</key>
											<string>testInsertionPerformance()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>74CA2984-1D1A-4F99-86A7-40F06AF48493</string>
										</dict>
										<dict>
											<key>PerformanceMetrics</key>
											<array>
												<dict>
													<key>BaselineAverage</key>
													<real>0.070755999999999999</real>
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
														<real>0.069741415000000001</real>
														<real>0.065663162999999997</real>
														<real>0.065787560999999994</real>
														<real>0.066205954999999997</real>
														<real>0.066921201999999999</real>
														<real>0.065251930999999999</real>
														<real>0.065058005000000002</real>
														<real>0.065979195000000004</real>
														<real>0.065679410999999993</real>
														<real>0.065961750999999999</real>
													</array>
													<key>Name</key>
													<string>Time</string>
													<key>UnitOfMeasurement</key>
													<string>seconds</string>
												</dict>
											</array>
											<key>TestIdentifier</key>
											<string>OrderedSetPerformanceTests/testIntersectionPerformance()</string>
											<key>TestName</key>
											<string>testIntersectionPerformance()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>8BDB2C34-E305-472E-8D01-C284CC291E32</string>
										</dict>
										<dict>
											<key>PerformanceMetrics</key>
											<array>
												<dict>
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
														<real>0.38304548199999999</real>
														<real>0.376492524</real>
														<real>0.38427486</real>
														<real>0.38021732600000002</real>
														<real>0.39147823999999998</real>
														<real>0.38572386400000003</real>
														<real>0.38308410300000001</real>
														<real>0.36865399799999998</real>
														<real>0.37752522700000002</real>
														<real>0.38337675999999998</real>
													</array>
													<key>Name</key>
													<string>Time</string>
													<key>UnitOfMeasurement</key>
													<string>seconds</string>
												</dict>
											</array>
											<key>TestIdentifier</key>
											<string>OrderedSetPerformanceTests/testOverallPerformance()</string>
											<key>TestName</key>
											<string>testOverallPerformance()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>300000EA-4E5C-4C9F-8443-1DF8D1DE2534</string>
										</dict>
										<dict>
											<key>PerformanceMetrics</key>
											<array>
												<dict>
													<key>BaselineAverage</key>
													<real>0.0071945999999999998</real>
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
														<real>0.025592488</real>
														<real>0.036124717000000001</real>
														<real>0.032954459999999998</real>
														<real>0.029919995000000001</real>
														<real>0.030667552000000001</real>
														<real>0.027939427999999999</real>
														<real>0.031111811999999999</real>
														<real>0.032812977</real>
														<real>0.027997043999999999</real>
														<real>0.029727185999999999</real>
													</array>
													<key>Name</key>
													<string>Time</string>
													<key>UnitOfMeasurement</key>
													<string>seconds</string>
												</dict>
											</array>
											<key>TestIdentifier</key>
											<string>OrderedSetPerformanceTests/testReplaceRangePerformance()</string>
											<key>TestName</key>
											<string>testReplaceRangePerformance()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>D788724F-D27B-4B6E-A217-3165AC62A525</string>
										</dict>
										<dict>
											<key>PerformanceMetrics</key>
											<array>
												<dict>
													<key>BaselineAverage</key>
													<real>0.066481999999999999</real>
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
														<real>0.065955973000000001</real>
														<real>0.064949570999999998</real>
														<real>0.065583249999999996</real>
														<real>0.065585570999999995</real>
														<real>0.065440797999999994</real>
														<real>0.065499567999999994</real>
														<real>0.066525170999999994</real>
														<real>0.066098499000000005</real>
														<real>0.064868877000000005</real>
														<real>0.065521266999999994</real>
													</array>
													<key>Name</key>
													<string>Time</string>
													<key>UnitOfMeasurement</key>
													<string>seconds</string>
												</dict>
											</array>
											<key>TestIdentifier</key>
											<string>OrderedSetPerformanceTests/testSubtractPerformance()</string>
											<key>TestName</key>
											<string>testSubtractPerformance()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>23939814-CC40-47CD-8B3A-9C67477C5ECF</string>
										</dict>
										<dict>
											<key>PerformanceMetrics</key>
											<array>
												<dict>
													<key>BaselineAverage</key>
													<real>0.035031</real>
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
														<real>0.031441782000000001</real>
														<real>0.037734546000000001</real>
														<real>0.035425269000000002</real>
														<real>0.041153782</real>
														<real>0.028713850999999999</real>
														<real>0.017264663</real>
														<real>0.031387998</real>
														<real>0.046434431999999998</real>
														<real>0.039809614</real>
														<real>0.030034287</real>
													</array>
													<key>Name</key>
													<string>Time</string>
													<key>UnitOfMeasurement</key>
													<string>seconds</string>
												</dict>
											</array>
											<key>TestIdentifier</key>
											<string>OrderedSetPerformanceTests/testUnionPerformance()</string>
											<key>TestName</key>
											<string>testUnionPerformance()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>E243AACF-4128-4F4C-88A4-89096ECA3E31</string>
										</dict>
										<dict>
											<key>PerformanceMetrics</key>
											<array>
												<dict>
													<key>BaselineAverage</key>
													<real>0.070313000000000001</real>
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
														<real>0.068066184000000002</real>
														<real>0.088453979000000002</real>
														<real>0.062446637999999999</real>
														<real>0.068341084999999996</real>
														<real>0.070519360000000003</real>
														<real>0.070482459999999997</real>
														<real>0.071095894000000007</real>
														<real>0.070998886999999997</real>
														<real>0.070075200000000004</real>
														<real>0.070327348999999997</real>
													</array>
													<key>Name</key>
													<string>Time</string>
													<key>UnitOfMeasurement</key>
													<string>seconds</string>
												</dict>
											</array>
											<key>TestIdentifier</key>
											<string>OrderedSetPerformanceTests/testXORPerformance()</string>
											<key>TestName</key>
											<string>testXORPerformance()</string>
											<key>TestObjectClass</key>
											<string>IDESchemeActionTestSummary</string>
											<key>TestStatus</key>
											<string>Success</string>
											<key>TestSummaryGUID</key>
											<string>7481ED78-17D1-440A-A1A4-C496DD710C07</string>
										</dict>
									</array>
									<key>TestIdentifier</key>
									<string>OrderedSetPerformanceTests</string>
									<key>TestName</key>
									<string>OrderedSetPerformanceTests</string>
									<key>TestObjectClass</key>
									<string>IDESchemeActionTestSummaryGroup</string>
								</dict>
							</array>
							<key>TestIdentifier</key>
							<string>OrderedSetTests.xctest</string>
							<key>TestName</key>
							<string>OrderedSetTests.xctest</string>
							<key>TestObjectClass</key>
							<string>IDESchemeActionTestSummaryGroup</string>
						</dict>
					</array>
					<key>TestIdentifier</key>
					<string>Selected tests</string>
					<key>TestName</key>
					<string>Selected tests</string>
					<key>TestObjectClass</key>
					<string>IDESchemeActionTestSummaryGroup</string>
				</dict>
			</array>
		</dict>
	</array>
</dict>
</plist>

*/
