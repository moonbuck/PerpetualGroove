//
//  SoundFont.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 10/19/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import Foundation
import MoonKit
import class UIKit.UIImage

/// A protocol specifying an interface for types wishing to serve as a sound font resource.
protocol SoundFont: CustomStringConvertible, JSONValueConvertible, JSONValueInitializable {

  /// The sound font file's location.
  var url: URL { get }

  /// The sound font file's data.
  var data: Data { get }

  /// The presets present in the sound font file.
  var presetHeaders: [SF2File.PresetHeader] { get }

  /// Whether the sound font contains general midi percussion presets.
  var isPercussion: Bool { get }

  /// The name to display in the user interface for the sound font.
  var displayName: String { get }

  /// The sound font file's base name without the extension.
  var fileName: String { get }

  /// The image to display in the user interface for the sound font.
  var image: UIImage { get }

  /// Accessor for retrieving a preset via the totally ordered array of presets.
  subscript(idx: Int) -> SF2File.PresetHeader { get }

  /// Accessor for retrieving a preset by its program and bank numbers.
  subscript(program program: UInt8, bank bank: UInt8) -> SF2File.PresetHeader? { get }

  /// Initialize a sound font using it's file location.
  init(url u: URL) throws

  /// Compare this sound font to another for equality. Two sound font's are equal if they point to
  /// the same resource.
  func isEqualTo(_ soundSet: SoundFont) -> Bool
}

extension SoundFont {

  /// A JSON object with an entry for 'url' containing the absolute string representation of `url`.
  var jsonValue: JSONValue { return ["url": url.absoluteString] }

  /// Initializing with a JSON value.
  /// - Parameter jsonValue: To be successful, `jsonValue` must be a JSON object with an entry for 
  ///                        'url` whose value is a string representing a valid URL.
  init?(_ jsonValue: JSONValue?) {

    // Get the url from the JSON value.
    guard let url = URL(string: String(ObjectJSONValue(jsonValue)?["url"]) ?? "") else {
      return nil
    }

    // Initialize with the url.
    do { try self.init(url: url) } catch { return nil }

  }

  /// Returns `true` iff `lhs.url` is equal to `rhs.url`.
  static func ==(lhs: Self, rhs: Self) -> Bool { return lhs.url == rhs.url }

  /// The hash value of `url`.
  var hashValue: Int { return url.hashValue }

  /// Property of convenience for looking up a sound font's index in the `Sequencer`'s `soundFonts` 
  /// collection.
  var index: Int? { return Sequencer.soundFonts.firstIndex(where: {isEqualTo($0)}) }

  /// Returns the element in `presetHeaders` located at `position`.
  subscript(position: Int) -> SF2File.PresetHeader { return presetHeaders[position] }

  /// Returns the element in `presetHeaders` with matching values for `program` and `bank`.
  subscript(program program: UInt8, bank bank: UInt8) -> SF2File.PresetHeader? {
    return presetHeaders.first(where: {$0.program == program && $0.bank == bank})
  }

  /// Returns `true` iff `other.url` is equal to `url`.
  func isEqualTo(_ other: SoundFont) -> Bool {

    // Get the two urls as file reference urls.
    let refURL1 = (url as NSURL).fileReferenceURL()
    let refURL2 = (other.url as NSURL).fileReferenceURL()

    // Compare the two urls.
    switch (refURL1, refURL2) {

      case let (url1?, url2?) where url1.isEqualToFileURL(url2):
        // The urls are equal, return `true`.

        return true

      case (nil, nil):
        // Both urls are nil, return `true`.
        return true

      default:
        // The urls are not equal, return `false`.

        return false

    }

  }

  /// The contents of `url` as raw data.
  /// - Requires: `url` is valid and reachable.
  var data: Data {
    return (try? Data(contentsOf: url)) ?? fatal("Failed to retrieve data from disk.")
  }

  /// The collection of preset headers generated by parsing `data`.
  var presetHeaders: [SF2File.PresetHeader] {
    return (try? SF2File.presetHeaders(from: data)) ?? []
  }

  /// The image to display in the user interface for the sound font. The default is an image of
  /// an oscillator.
  var image: UIImage { return #imageLiteral(resourceName: "oscillator") }

  /// Whether the sound font contains general midi percussion presets. The default is false.
  var isPercussion: Bool { return false }

  /// The base name of the file located at `url`.
  var fileName: String { return url.path.baseNameExt.baseName }

  /// The user-facing name of the sound font. The default is `fileName`.
  var displayName: String { return fileName }

  var description: String { return "\(displayName) - \(fileName)" }

}

/// A structure for creating a sound font with only a URL.
struct AnySoundFont: SoundFont {

  /// The URL for the file containing the sound font's data.
  let url: URL

  /// Initializing with a URL.
  /// - Requires: `url` is reachable.
  /// - Throws: `ErrorMessage` when `url` is not reachable.
  init(url: URL) throws {

    // Check that the url is reachable.
    guard try url.checkResourceIsReachable() else {
      throw ErrorMessage(errorDescription: "AnySoundFont.Error", failureReason: "Invalid URL")
    }

    // Initialize `url` with the specified URL.
    self.url = url

  }

  /// The 'SPYRO's Pure Oscillators' sound font located in the application's bundle.
  static let spyro = try! AnySoundFont(url: Bundle.main.url(forResource: "SPYRO's Pure Oscillators",
                                                            withExtension: "sf2")!)
  
}

/// A structure for sound fonts that are part of the 'Emax' collection located within the
/// application's bundle.
struct EmaxSoundFont: SoundFont {

  /// An enumeration of the volumes available within the 'Emax' collection.
  enum Volume: Int {
    case brassAndWoodwinds  = 1
    case keyboardsAndSynths = 2
    case guitarsAndBasses   = 3
    case worldInstruments   = 4
    case drumsAndPercussion = 5
    case orchestral         = 6
  }

  /// The URL for the sound font within the application's main bundle.
  var url: URL { return Bundle.main.url(forResource: fileName, withExtension: "sf2")! }

  /// The volume of the sound font.
  let volume: Volume

  /// Whether the sound font contains general midi percussion presets. This is `false` unless
  /// the sound font represents the 'drums and percussion' volume.
  var isPercussion: Bool { return volume == .drumsAndPercussion }

  /// The title-cased name of the sound font's volume.
  var displayName: String {
    switch volume {
      case .brassAndWoodwinds:  return "Brass & Woodwinds"
      case .keyboardsAndSynths: return "Keyboards & Synths"
      case .guitarsAndBasses:   return "Guitars & Basses"
      case .worldInstruments:   return "World Instruments"
      case .drumsAndPercussion: return "Drums & Percussion"
      case .orchestral:         return "Orchestral"
    }
  }

  /// The name of the sound font file within the application's main bundle.
  var fileName: String { return "Emax Volume \(volume.rawValue)" }

  /// The image to display in the user interface for the sound font. Unique to `volume`.
  var image: UIImage {
    switch volume {
      case .brassAndWoodwinds:  return #imageLiteral(resourceName: "brass")
      case .keyboardsAndSynths: return #imageLiteral(resourceName: "piano_keyboard")
      case .guitarsAndBasses:   return #imageLiteral(resourceName: "guitar_bass")
      case .worldInstruments:   return #imageLiteral(resourceName: "world")
      case .drumsAndPercussion: return #imageLiteral(resourceName: "percussion")
      case .orchestral:         return #imageLiteral(resourceName: "orchestral")
    }
  }

  /// Initializing with a volume.
  init(_ volume: Volume) { self.volume = volume }

  /// Initializing with a URL. The sound font is initialized by matching `url.path` against
  /// 'Emax Volume #` where '#' is a number between 1 and 6.
  /// - Throws: `ErrorMessage` when a `url` cannot be matched to a volume.
  init(url: URL) throws {

    // Retrieve the volume via regular expression matching.
    guard let volume = (url.path ~=> ~/"Emax Volume ([1-6])")?.1 else {
      throw ErrorMessage(errorDescription: "EmaxSoundFont.Error", failureReason: "Invalid URL")
    }

    // Initialize with the parsed volume number.
    self.init(Volume(rawValue: Int(volume)!)!)

  }

}
