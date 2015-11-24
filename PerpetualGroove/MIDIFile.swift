//
//  MIDIFile.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 8/24/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import Foundation
import MoonKit
import struct AudioToolbox.CABarBeatTime


/** Struct that holds the data for a complete MIDI file */
struct MIDIFile {

  enum Format: Byte2 { case Zero, One, Two }

  static let emptyFile = MIDIFile(tracks: [])

  let tracks: [MIDIFileTrackChunk]

  private let header: MIDIFileHeaderChunk

  /**
  initWithFile:

  - parameter file: NSURL
  */
  init(file: NSURL) throws {
    guard let fileData = NSData(contentsOfURL: file) else {
      throw MIDIFileError(type: .ReadFailure, reason: "Failed to get data from '\(file)'")
    }
    try self.init(data: fileData)
  }

  /**
  initWithData:

  - parameter data: NSData
  */
  init(data: NSData) throws {

    let totalBytes = data.length
    guard totalBytes > 13 else {
      throw MIDIFileError(type:.FileStructurallyUnsound, reason: "Not enough bytes in file")
    }

    // Get a pointer to the underlying memory buffer
    let bytes = UnsafeBufferPointer<Byte>(start: UnsafePointer<Byte>(data.bytes), count: totalBytes)

    let headerBytes = bytes[bytes.startIndex ..< bytes.startIndex.advancedBy(14)]
    let h = try MIDIFileHeaderChunk(bytes: headerBytes)

    var tracksRemaining = h.numberOfTracks
    var t: [MIDIFileTrackChunk] = []

    var currentIndex = bytes.startIndex.advancedBy(14)

    while tracksRemaining > 0 {
      guard currentIndex.distanceTo(bytes.endIndex) > 8 else {
        throw MIDIFileError(type: .FileStructurallyUnsound,
                            reason: "Not enough bytes for remaining track chunks (\(tracksRemaining))")
      }
      guard bytes[currentIndex ..< currentIndex.advancedBy(4)].elementsEqual("MTrk".utf8) else {
        throw MIDIFileError(type: .InvalidHeader, reason: "Expected chunk header with type 'MTrk'")
      }
      let chunkLength = Byte4(bytes[currentIndex.advancedBy(4) ..< currentIndex.advancedBy(8)])
      guard currentIndex.advancedBy(Int(chunkLength) + 8) <= bytes.endIndex else {
        throw MIDIFileError(type:.FileStructurallyUnsound, reason: "Not enough bytes in track chunk \(t.count)")
      }

      let trackBytes = bytes[currentIndex ..< currentIndex.advancedBy(Int(chunkLength) + 8)]

      t.append(try MIDIFileTrackChunk(bytes: trackBytes))
      currentIndex.advanceBy(Int(chunkLength) + 8)
      tracksRemaining--
    }

    // TODO: We need to track signature changes to do this properly
    let beatsPerBar: UInt8 = 4
    let subbeatDivisor = h.division
    var processedTracks: [MIDIFileTrackChunk] = []
    for trackChunk in t {
      var ticks: UInt64 = 0
      var processedEvents: [MIDIEvent] = []
      for var trackEvent in trackChunk.events {
        guard let delta = trackEvent.delta else {
          throw MIDIFileError(type: .FileStructurallyUnsound, reason: "Track event missing delta value")
        }
        let deltaTicks = UInt64(delta.intValue)
        ticks += deltaTicks
        trackEvent.time = CABarBeatTime(tickValue: ticks, beatsPerBar: beatsPerBar, subbeatDivisor: subbeatDivisor)
        processedEvents.append(trackEvent)
      }
      processedTracks.append(MIDIFileTrackChunk(events: processedEvents))
    }

    header = h
    tracks = processedTracks
  }

  /**
  initWithFormat:division:tracks:

  - parameter format: Format
  - parameter division: Byte2
  - parameter tracks: [MIDITrackType]
  */
  init(format: Format = .One, division: Byte2 = 480, tracks: [MIDIFileTrackChunk]) {
    self.tracks = tracks
    header = MIDIFileHeaderChunk(format: format, numberOfTracks: Byte2(tracks.count), division: division)
  }

  var bytes: [Byte] {
    var bytes = header.bytes
    var trackData: [[Byte]] = []
    let beatsPerBar = Sequencer.timeSignature.beatsPerBar
    for track in tracks {
      var previousTime: CABarBeatTime = .start
      var trackBytes: [Byte] = []
      for event in track.events {
        let eventTime = event.time
        let eventTimeTicks = eventTime.tickValueWithBeatsPerBar(beatsPerBar)
        let previousTimeTicks = previousTime.tickValueWithBeatsPerBar(beatsPerBar)
        let delta = eventTimeTicks > previousTimeTicks ? eventTimeTicks - previousTimeTicks : 0
        previousTime = eventTime
        let deltaTime = VariableLengthQuantity(delta)
        let eventBytes = deltaTime.bytes + event.bytes
        trackBytes.appendContentsOf(eventBytes)
      }
      trackData.append(trackBytes)
    }

    for trackBytes in trackData {
      bytes.appendContentsOf(Array("MTrk".utf8))
      bytes.appendContentsOf(Byte4(trackBytes.count).bytes)
      bytes.appendContentsOf(trackBytes)
    }

    return bytes
  }
}

extension MIDIFile: CustomStringConvertible {
  var description: String { return "\(header)\n\("\n".join(tracks.map({$0.description})))" }
}

extension MIDIFile: CustomDebugStringConvertible {
  var debugDescription: String { var result = ""; dump(self, &result); return result }
}
