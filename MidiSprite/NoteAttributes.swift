//
//  Note.swift
//  MidiSprite
//
//  Created by Jason Cardwell on 8/28/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import Foundation
import MoonKit

/** Protocol for types that can be converted to and from a value within the range of 0 ... 127  */
protocol MIDIValueConvertible: Hashable, Equatable {
  var MIDIValue: Byte { get }
  init(MIDIValue: Byte)
}

extension MIDIValueConvertible {
  var hashValue: Int { return MIDIValue.hashValue }
}

func ==<M:MIDIValueConvertible>(lhs: M, rhs: M) -> Bool { return lhs.MIDIValue == rhs.MIDIValue }

/** Structure that encapsulates MIDI information necessary for playing a note */
struct NoteAttributes: Equatable {

  var channel: UInt8 = 0

  /** An enumeration for specifying a note's pitch and octave */
  enum Note: RawRepresentable, Equatable, EnumerableType, MIDIValueConvertible {

    enum Letter: String, EnumerableType {
      case C="C", CSharp="C♯", D="D", DSharp="D♯", E="E", F="F", FSharp="F♯", G="G", GSharp="G♯", A="A", ASharp="A♯", B="B"

      init(_ i: UInt8) { self = Letter.allCases[Int(i % 12)] }
      init(var index: Int) { index %= Letter.allCases.count; self = Letter.allCases[index] }
      static let allCases: [Letter] = [C, CSharp, D, DSharp, E, F, FSharp, G, GSharp, A, ASharp, B]
    }

    case Pitch(letter: Letter, octave: Int)

    /**
    Initialize from MIDI value from 0 ... 127

    - parameter value: Int
    */
    init(var MIDIValue value: Byte) { value %= 128; self = .Pitch(letter: Letter(value), octave: (Int(value) / 12) - 1) }

    /**
    Initialize with string representation

    - parameter rawValue: String
    */
    init?(rawValue: String) {
      guard let match = (~/"^([A-G]♯?)((?:-1)|[0-9])$").firstMatch(rawValue),
        rawLetter = match.captures[1]?.string,
        letter = Letter(rawValue: rawLetter),
        rawOctave = match.captures[2]?.string,
        octave = Int(rawOctave) else { return nil }

      self = .Pitch(letter: letter, octave :octave)
    }

    var rawValue: String { switch self { case let .Pitch(letter, octave): return "\(letter.rawValue)\(octave)" } }

    var MIDIValue: Byte {  switch self { case let .Pitch(letter, octave): return UInt8((octave + 1) * 12 + letter.index) } }

    static let allCases: [Note] = (0...127).map({Note(MIDIValue: $0)})

  }

  /// The pitch and octave
  var note: Note = Note(MIDIValue: 60)

  /** Enumeration for a musical note duration */
  enum Duration: String, EnumerableType, ImageAssetLiteralType {
    case DoubleWhole, DottedWhole, Whole, DottedHalf, Half, DottedQuarter, Quarter, DottedEighth, Eighth, DottedSixteenth, 
         Sixteenth, DottedThirtySecond, ThirtySecond, DottedSixtyFourth, SixtyFourth, DottedHundredTwentyEighth, 
         HundredTwentyEighth, DottedTwoHundredFiftySixth, TwoHundredFiftySixth

    var seconds: Double {
      let secondsPerBeat = 60 / Sequencer.tempo
      switch self {
        case .DoubleWhole:                return secondsPerBeat * 8
        case .DottedWhole:                return secondsPerBeat * 6
        case .Whole:                      return secondsPerBeat * 4
        case .DottedHalf:                 return secondsPerBeat * 3
        case .Half:                       return secondsPerBeat * 2
        case .DottedQuarter:              return secondsPerBeat * 3╱2
        case .Quarter:                    return secondsPerBeat
        case .DottedEighth:               return secondsPerBeat * 3╱4
        case .Eighth:                     return secondsPerBeat * 1╱2
        case .DottedSixteenth:            return secondsPerBeat * 3╱8
        case .Sixteenth:                  return secondsPerBeat * 1╱4
        case .DottedThirtySecond:         return secondsPerBeat * 3╱16
        case .ThirtySecond:               return secondsPerBeat * 1╱8
        case .DottedSixtyFourth:          return secondsPerBeat * 3╱32
        case .SixtyFourth:                return secondsPerBeat * 1╱16
        case .DottedHundredTwentyEighth:  return secondsPerBeat * 3╱64
        case .HundredTwentyEighth:        return secondsPerBeat * 1╱32
        case .DottedTwoHundredFiftySixth: return secondsPerBeat * 3╱128
        case .TwoHundredFiftySixth:       return secondsPerBeat * 1╱64
      }
    }

    static let allCases: [Duration] = [.DoubleWhole, .DottedWhole, .Whole, .DottedHalf, .Half, .DottedQuarter, .Quarter,
                                       .DottedEighth, .Eighth, .DottedSixteenth, .Sixteenth, .DottedThirtySecond,
                                       .ThirtySecond, .DottedSixtyFourth, .SixtyFourth, .DottedHundredTwentyEighth, 
                                       .HundredTwentyEighth, .DottedTwoHundredFiftySixth, .TwoHundredFiftySixth ]
  }

  /// The duration of the played note
  var duration: Duration = .Eighth

  /** Enumeration for musical dynamics */
  enum Velocity: String, EnumerableType, ImageAssetLiteralType, MIDIValueConvertible {
    case Pianississimo
    case Pianissimo
    case Piano
    case MezzoPiano
    case MezzoForte
    case Forte
    case Fortissimo
    case Fortississimo
    var MIDIValue: Byte {
      switch self {
        case .Pianississimo: return 16
        case .Pianissimo:    return 33
        case .Piano:         return 49
        case .MezzoPiano:    return 64
        case .MezzoForte:    return 80
        case .Forte:         return 96
        case .Fortissimo:    return 112
        case .Fortississimo: return 126
      }
    }
    init(MIDIValue value: Byte) {
      switch value {
        case 0 ... 22:    self = .Pianississimo
        case 23 ... 40:   self = .Pianissimo
        case 41 ... 51:   self = .Piano
        case 52 ... 70:   self = .MezzoPiano
        case 71 ... 88:   self = .MezzoForte
        case 81 ... 102:  self = .Forte
        case 103 ... 119: self = .Fortissimo
        default:          self = .Fortississimo
      }
    }
    static let allCases: [Velocity] = [.Pianississimo, .Pianissimo, .Piano, .MezzoPiano, .MezzoForte, 
                                       .Forte, .Fortissimo, .Fortississimo]
  }

  /// The dynmamics for the note
  var velocity: Velocity = .MezzoForte
}


func ==(lhs: NoteAttributes.Note, rhs: NoteAttributes.Note) -> Bool { return lhs.MIDIValue == rhs.MIDIValue }

func ==(lhs: NoteAttributes, rhs: NoteAttributes) -> Bool {
  guard lhs.channel == rhs.channel   else { return false }
  guard lhs.duration == rhs.duration else { return false }
  guard lhs.velocity == rhs.velocity else { return false }
  guard lhs.note == rhs.note         else { return false }
  return true
}
