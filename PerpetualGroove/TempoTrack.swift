//
//  TempoTrack.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 8/27/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import Foundation
import CoreMIDI
import MoonKit

final class TempoTrack: Track {

  override var name: String { get { return "Tempo" } set {} }

  var recording: Bool = false
  var tempo: Double = Sequencer.tempo {
    didSet {
      guard tempo != oldValue && recording else { return }
      logDebug("inserting event for tempo \(tempo)")
      addEvent(.Meta(tempoEvent))
      Notification.DidUpdate.post(object: self)
    }
  }

  var timeSignature: TimeSignature = Sequencer.timeSignature {
    didSet {
      guard timeSignature != oldValue && recording else { return }
      logDebug("inserting event for signature \(timeSignature)")
      addEvent(.Meta(timeSignatureEvent))
      Notification.DidUpdate.post(object: self)
    }
  }

  private var timeSignatureEvent: MetaEvent {
    return MetaEvent(Sequencer.time.barBeatTime, .TimeSignature(signature: timeSignature, clocks: 36, notes: 8))
  }

  private var tempoEvent: MetaEvent {
    return MetaEvent(Sequencer.time.barBeatTime, .Tempo(bpm: tempo))
  }

  /**
  isTempoTrackEvent:

  - parameter trackEvent: MIDIEvent

  - returns: Bool
  */
  static func isTempoTrackEvent(trackEvent: MIDIEvent) -> Bool {
    guard case .Meta(let metaEvent) = trackEvent else { return false }
    switch metaEvent.data {
      case .Tempo, .TimeSignature, .EndOfTrack: return true
      case .SequenceTrackName(let name) where name.lowercaseString == "tempo": return true
      default: return false
    }
  }

  /**
  dispatchEvent:

  - parameter event: MIDIEvent
  */
  override func dispatchEvent(event: MIDIEvent) {
    guard case .Meta(let metaEvent) = event else { return }
    switch metaEvent.data {
      case let .Tempo(bpm): tempo = bpm; Sequencer.setTempo(bpm, automated: true)
      case let .TimeSignature(signature, _, _): timeSignature = signature
      default: break
    }
  }

  /**
  Initializer for non-playback mode tempo track
  
  - parameter s: Sequence
  */
  override init(sequence: Sequence) {
    super.init(sequence: sequence)
    addEvent(.Meta(timeSignatureEvent))
    addEvent(.Meta(tempoEvent))
  }

  /**
  initWithTrackChunk:

  - parameter trackChunk: MIDIFileTrackChunk
  - parameter s: Sequence
  */
  init(sequence: Sequence, trackChunk: MIDIFileTrackChunk) {
    super.init(sequence: sequence)
    addEvents(trackChunk.events.filter(TempoTrack.isTempoTrackEvent))

    if filterEvents({
      if case .Meta(let event) = $0, case .TimeSignature = event.data { return true } else { return false }
    }).count == 0
    {
      addEvent(.Meta(timeSignatureEvent))
    }

    if filterEvents({
      if case .Meta(let event) = $0, case .Tempo = event.data { return true } else { return false }
    }).count == 0
    {
      addEvent(.Meta(tempoEvent))
    }
  }

}
