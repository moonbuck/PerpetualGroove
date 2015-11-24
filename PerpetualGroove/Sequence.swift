//
//  Sequence.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 8/23/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import Foundation
import MoonKit
import struct AudioToolbox.CABarBeatTime

final class Sequence {


  // MARK: - Managing tracks
  
  var sequenceEnd: CABarBeatTime { return tracks.map({$0.endOfTrack}).maxElement() ?? .start }

  private(set) var instrumentTracks: [InstrumentTrack] = []
  private var _soloTracks: [Weak<InstrumentTrack>] = []
  var soloTracks: [InstrumentTrack] {
    let result = _soloTracks.flatMap {$0.reference}
    if result.count < _soloTracks.count { _soloTracks = _soloTracks.filter { $0.reference != nil } }
    return result
  }

  /**
  exchangeInstrumentTrackAtIndex:withTrackAtIndex:

  - parameter idx1: Int
  - parameter idx2: Int
  */
  func exchangeInstrumentTrackAtIndex(idx1: Int, withTrackAtIndex idx2: Int) {
    guard instrumentTracks.indices ⊇ [idx1, idx2] else { return }
    swap(&instrumentTracks[idx1], &instrumentTracks[idx2])
    logDebug("posting 'DidUpdate'")
    Notification.DidUpdate.post(object: self)
  }

  var currentTrackIndex: Int? {
    get { return currentTrack?.index }
    set {
      guard let newValue = newValue where instrumentTracks.indices ∋ newValue else { currentTrack = nil; return }
      currentTrack = instrumentTracks[newValue]
    }
  }

  private var currentTrackStack: Stack<Weak<InstrumentTrack>> = []

  weak var currentTrack: InstrumentTrack? {
    get { return currentTrackStack.peek?.reference }
    set {
      let userInfo: [Notification.Key:AnyObject?]?

      switch (currentTrackStack.peek?.reference, newValue) {

        case let (oldTrack, newTrack?) where instrumentTracks ∋ newTrack && oldTrack != newTrack:
          userInfo = [Notification.Key.OldTrack: oldTrack, Notification.Key.Track: newTrack]
          currentTrackStack.push(Weak(newTrack))
          newTrack.recording = Sequencer.recording

      case let (oldTrack?, nil):
          userInfo = [Notification.Key.OldTrack: oldTrack, Notification.Key.Track: nil]
          currentTrackStack.pop()

        case (nil, nil):
          fallthrough

        default:
          userInfo = nil

      }
      guard userInfo != nil else { return }
      Notification.DidChangeTrack.post(object: self, userInfo: userInfo)
    }
  }

  /** The tempo track for the sequence is the first element in the `tracks` array */
  private var tempoTrack: TempoTrack!

  var tempo: Double { get { return tempoTrack.tempo } set { tempoTrack.tempo = newValue } }

  var timeSignature: TimeSignature { get { return tempoTrack.timeSignature } set { tempoTrack.timeSignature = newValue } }

  /** Collection of all the tracks in the composition */
  var tracks: [Track] { return [tempoTrack] + instrumentTracks }

  /**
  toggleSoloForTrack:

  - parameter track: InstrumentTrack
  */
  func toggleSoloForTrack(track: InstrumentTrack) {
    guard instrumentTracks ∋ track else { logWarning("Request to toggle track not owned by sequence"); return }

    if let idx = soloTracks.indexOf(track), track = _soloTracks.removeAtIndex(idx).reference {
      guard track.solo else { fatalError("Internal inconsistency, track should have solo set to true to be in _soloTracks") }
      track.solo = false
      Notification.SoloCountDidChange.post(object: self,
                                           userInfo: [.OldCount: _soloTracks.count + 1, .NewCount: _soloTracks.count])
    } else {
      track.solo = true
      _soloTracks.append(Weak(track))
      Notification.SoloCountDidChange.post(object: self,
                                           userInfo: [.OldCount: _soloTracks.count - 1, .NewCount: _soloTracks.count])
    }
  }

  /** Conversion to the `MIDIFile` type  */
  var file: MIDIFile { return MIDIFile(format: .One, division: 480, tracks: tracks.map({$0.chunk})) }

  // MARK: - Receiving track and sequencer notifications

  private let receptionist: NotificationReceptionist = {
    let receptionist = NotificationReceptionist(callbackQueue: NSOperationQueue.mainQueue())
    receptionist.logContext = LogManager.MIDIFileContext
    return receptionist
  }()

  private var hasChanges = false

  /**
  trackDidUpdate:

  - parameter notification: NSNotification
  */
  private func trackDidUpdate(notification: NSNotification) {
    if Sequencer.playing { hasChanges = true }
    else {
      hasChanges = false
      logDebug("posting 'DidUpdate'")
      Notification.DidUpdate.post(object: self)
    }
  }

  /**
  toggleRecording:

  - parameter notification: NSNotification
  */
  private func toggleRecording(notification: NSNotification) {
    let recording = Sequencer.recording
    currentTrack?.recording = recording
    tempoTrack.recording = recording
  }

  /**
  sequencerDidReset:

  - parameter notification: NSNotification
  */
  private func sequencerDidReset(notification: NSNotification) {
    guard hasChanges else { return }
    hasChanges = false
    logDebug("posting 'DidUpdate'")
    Notification.DidUpdate.post(object: self)
  }

  private(set) weak var document: MIDIDocument?

  // MARK: - Initializing

  /**
  initWithFile:

  - parameter file: MIDIFile
  */
  init(file: MIDIFile, document: MIDIDocument) {
    self.document = document
    receptionist.observe(Sequencer.Notification.DidToggleRecording,
                    from: Sequencer.self,
                callback: weakMethod(self, Sequence.toggleRecording))
    receptionist.observe(Sequencer.Notification.DidReset,
                    from: Sequencer.self,
                callback: weakMethod(self, Sequence.sequencerDidReset))

    var trackChunks = ArraySlice(file.tracks)
    if let trackChunk = trackChunks.first
      where trackChunk.events.count == trackChunk.events.filter({ TempoTrack.isTempoTrackEvent($0) }).count
    {
      tempoTrack = TempoTrack(sequence: self, trackChunk: trackChunk)
      trackChunks = trackChunks.dropFirst()
    } else {
      tempoTrack = TempoTrack(sequence: self)
    }

//    for trackChunk in trackChunks { addTrack(trackChunk) }
    for track in trackChunks.flatMap({ try? InstrumentTrack(sequence: self, trackChunk: $0) }) {
      addTrack(track)
    }
  }

  deinit { print("instrumentTracks.count = \(instrumentTracks.count)") }

  // MARK: - Adding tracks

  /**
  insertTrackWithInstrument:

  - parameter instrument: Instrument
  */

  func insertTrackWithInstrument(instrument: Instrument) throws {
    addTrack(try InstrumentTrack(sequence: self, instrument: instrument))
    logDebug("posting 'DidUpdate'")
    Notification.DidUpdate.post(object: self)
  }

  /**
  addTrack:

  - parameter trackChunk: MIDIFileTrackChunk
  */
//  private func addTrack(trackChunk: MIDIFileTrackChunk) {
//    do {
//      let track = try InstrumentTrack(sequence: self, trackChunk: trackChunk)
//      addTrack(track)
//    } catch {
//      logError(error)
//    }
//  }

  /**
  addTrack:

  - parameter track: InstrumentTrack
  */
  private func addTrack(track: InstrumentTrack) {
    guard instrumentTracks ∌ track else { return }
    track.color = TrackColor.allCases[(instrumentTracks.count) % TrackColor.allCases.count]
    instrumentTracks.append(track)
    receptionist.observe(Track.Notification.DidUpdateEvents,
                    from: track,
                callback: weakMethod(self, Sequence.trackDidUpdate))

    logDebug("track added: \(track.name)")
    Notification.DidAddTrack.post(
      object: self,
      userInfo: [
        Notification.Key.AddedIndex: instrumentTracks.count - 1,
        Notification.Key.AddedTrack: track
      ]
    )
    if currentTrack == nil { currentTrack = track }
  }

  // MARK: - Removing tracks

  /**
  removeTrack:

  - parameter track: InstrumentTrack
  */
  func removeTrack(track: InstrumentTrack) {
    guard let idx = track.index where track.sequence === self else { return }
    removeTrackAtIndex(idx)
  }

  func removeTrackAtIndex(index: Int) {
    let track = instrumentTracks.removeAtIndex(index)
    receptionist.stopObserving(Track.Notification.DidUpdateEvents, from: track)
    logDebug("track removed: \(track.name)")
    Notification.DidRemoveTrack.post(
      object: self,
      userInfo: [
        Notification.Key.RemovedIndex: index,
        Notification.Key.RemovedTrack: track
      ]
    )
    if currentTrack == track { currentTrackStack.pop(); currentTrack?.recording = Sequencer.recording }
    logDebug("posting 'DidUpdate'")
    Notification.DidUpdate.post(object: self)
  }

}

// MARK: - Nameable
extension Sequence: Nameable { var name: String? { return document?.localizedName } }

// MARK: - CustomStringConvertible
extension Sequence: CustomStringConvertible {
  var description: String {
    return "\ntracks:\n" + "\n\n".join(tracks.map({$0.description.indentedBy(1, useTabs: true)}))
  }
}

// MARK: - CustomDebugStringConvertible
extension Sequence: CustomDebugStringConvertible {
  var debugDescription: String { var result = ""; dump(self, &result); return result }
}

// MARK: - Notification

extension Sequence {
  /** An enumeration to wrap up notifications */
  enum Notification: String, NotificationType, NotificationNameType {
    case DidAddTrack, DidRemoveTrack, DidChangeTrack, SoloCountDidChange, DidUpdate
    enum Key: String, NotificationKeyType {
      case Track, OldTrack, OldCount, RemovedIndex, AddedIndex, NewCount, AddedTrack, RemovedTrack
    }
  }
}

extension NSNotification {

  var track: InstrumentTrack?    { return userInfo?[Sequence.Notification.Key.Track.key] as? InstrumentTrack }
  var oldTrack: InstrumentTrack? { return userInfo?[Sequence.Notification.Key.OldTrack.key] as? InstrumentTrack }

  var oldCount: Int? { return (userInfo?[Sequence.Notification.Key.OldCount.key] as? NSNumber)?.integerValue }
  var newCount: Int? { return (userInfo?[Sequence.Notification.Key.NewCount.key] as? NSNumber)?.integerValue }

  var removedIndex: Int? {
    return (userInfo?[Sequence.Notification.Key.RemovedIndex.key] as? NSNumber)?.integerValue
  }
  var addedIndex: Int? {
    return (userInfo?[Sequence.Notification.Key.AddedIndex.key] as? NSNumber)?.integerValue
  }

  var addedTrack: InstrumentTrack? {
    return userInfo?[Sequence.Notification.Key.AddedTrack.key] as? InstrumentTrack
  }
  var removedTrack: InstrumentTrack? {
    return userInfo?[Sequence.Notification.Key.RemovedTrack.key] as? InstrumentTrack
  }

}