//
//  ChordGenerator.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 11/22/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import Foundation
import CoreMIDI
import MoonKit

struct ChordGenerator {
  var chord = Chord()
  var octave = Octave.four
  var duration = Duration.eighth
  var velocity = Velocity.𝑚𝑓

  var root: Note { get { return chord.root } set { chord.root = newValue } }

  var midiNotes: [NoteGenerator] {
    var result: [NoteGenerator] = []
    let notes = chord.notes
    guard let rootIndex = notes.index(of: chord.root) else { return result }

    if rootIndex > 0 {
      for note in notes[0 ..< rootIndex] {
        let octave: Octave?
        if note > chord.root {
          octave = Octave(rawValue: self.octave.rawValue - 1)
        } else {
          octave = self.octave
        }
        guard octave != nil else { continue }
        let tone = NoteGenerator.Tone(note, octave!)
        result.append(NoteGenerator(tone: tone, duration: duration, velocity: velocity))
      }
    }

    var currentOctave = octave
    var previousNote = chord.root
    for note in notes[rootIndex|->] {
      if note < previousNote {
        guard let nextOctave = Octave(rawValue: currentOctave.rawValue + 1) else { return result }
        currentOctave = nextOctave
      }
      let tone = NoteGenerator.Tone(note, currentOctave)
      result.append(NoteGenerator(tone: tone, duration: duration, velocity: velocity))
      previousNote = note
    }

    return result
  }

  /**
  initWithChord:octave:duration:velocity:

  - parameter chord: Chord
  - parameter octave: Octave
  - parameter duration: Duration
  - parameter velocity: Velocity
  */
  init(chord: Chord, octave: Octave, duration: Duration, velocity: Velocity) {
    self.chord = chord
    self.octave = octave
    self.duration = duration
    self.velocity = velocity
  }

  /**
  initWithPattern:generator:

  - parameter pattern: Chord.ChordPattern
  - parameter generator: NoteGenerator
  */
  init(pattern: Chord.ChordPattern, generator: NoteGenerator) {
    chord = Chord(generator.tone.note, pattern)
    octave = generator.octave
    duration = generator.duration
    velocity = generator.velocity
  }
}

extension ChordGenerator: JSONValueConvertible {
  var jsonValue: JSONValue {
    return ObjectJSONValue([
      "chord": chord.jsonValue,
      "octave": octave.jsonValue,
      "duration": duration.jsonValue,
      "velocity": velocity.jsonValue
      ]).jsonValue
  }
}

extension ChordGenerator: JSONValueInitializable {
  init?(_ jsonValue: JSONValue?) {
    guard let dict = ObjectJSONValue(jsonValue),
              let chord = Chord(dict["chord"]),
              let octave = Octave(dict["octave"]),
              let duration = Duration(dict["duration"]),
              let velocity = Velocity(dict["velocity"]) else { return nil }
    self.chord = chord
    self.octave = octave
    self.duration = duration
    self.velocity = velocity
  }
}

extension ChordGenerator: MIDIGeneratorType {

  /**
   receiveNoteOn:

   - parameter endPoint: MIDIEndpointRef
   */
  func receiveNoteOn(_ endPoint: MIDIEndpointRef, _ identifier: UInt64) throws {
    for note in midiNotes { try note.receiveNoteOn(endPoint, identifier) }
  }

  /**
   receiveNoteOff:

   - parameter endPoint: MIDIEndpointRef
   */
  func receiveNoteOff(_ endPoint: MIDIEndpointRef, _ identifier: UInt64) throws {
    for note in midiNotes { try note.receiveNoteOff(endPoint, identifier) }
  }

  /**
   sendNoteOn:endPoint:

   - parameter endPoint: MIDIEndpointRef
   */
  func sendNoteOn(_ outPort: MIDIPortRef, _ endPoint: MIDIEndpointRef) throws {
    for note in midiNotes { try note.sendNoteOn(outPort, endPoint) }
  }

  /**
   sendNoteOff:endPoint:

   - parameter endPoint: MIDIEndpointRef
   */
  func sendNoteOff(_ outPort: MIDIPortRef, _ endPoint: MIDIEndpointRef) throws {
    for note in midiNotes { try note.sendNoteOff(outPort, endPoint) }
  }

}

extension ChordGenerator: Equatable {}

func ==(lhs: ChordGenerator, rhs: ChordGenerator) -> Bool {
  return lhs.chord == rhs.chord
      && lhs.octave == rhs.octave
      && lhs.duration == rhs.duration
      && lhs.velocity == rhs.velocity
}


