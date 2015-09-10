//
//  Sequence.swift
//  MidiSprite
//
//  Created by Jason Cardwell on 8/23/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import Foundation
import AudioToolbox
import MoonKit

final class Sequence: CustomStringConvertible {

  /** An enumeration to wrap up notifications */
  enum Notification: String, NotificationType, NotificationNameType {
    case TrackAdded, TrackRemoved
    var object: AnyObject? { return Sequence.self }
  }

  var recording = false { didSet { tracks.forEach { $0.recording = recording } } }
  var description: String { return "Sequence {\n" + "\n".join(tracks.map({$0.description.indentedBy(4)})) + "\n}" }

  private let time = BarBeatTime(clockSource: Sequencer.clockSource)

  /** Collection of all the tracks in the composition */
  private(set) var tracks: [Track] = []

  /** The tempo track for the sequence */
  private let tempo = TempoTrack()

  var file: MIDIFile {
    return MIDIFile(format: .One, division: 480, tracks: [tempo as TrackType] + tracks.map({$0 as TrackType}))
  }

  /**
  newTrackWithInstrument:

  - parameter instrument: Instrument
  */

  func newTrackWithInstrument(instrument: Instrument) throws -> Track {
    let track = try Track(instrument: instrument)
    tracks.append(track)
    Notification.TrackAdded.post()
    return track
  }

  /**
  insertTempoChange:

  - parameter tempo: Double
  */
  func insertTempoChange(tempo: Double) { self.tempo.insertTempoChange(tempo) }

  /**
  writeToFile:

  - parameter file: NSURL
  */
  func writeToFile(file: NSURL, overwrite: Bool = false) throws {
    let midiFile = self.file
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
      let bytes = midiFile.bytes
      let data = NSData(bytes: bytes, length: bytes.count)
      do { try data.writeToURL(file, options: overwrite ? [.DataWritingAtomic] : [.DataWritingWithoutOverwriting]) }
      catch { logError(error) }
    }
  }

}