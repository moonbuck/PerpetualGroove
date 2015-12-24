//
//  Sequencer.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 8/19/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import Foundation
import AudioToolbox
import MoonKit

/** Manager for MIDI-related aspects of the application */
final class Sequencer {

  // MARK: - Initialization

  private(set) static var initialized = false

  /** 
   Initializes `soundSets` using the bundled sound font files and creates `auditionInstrument` with the
   first found
  */
  static func initialize() {
    globalBackgroundQueue.async {
      guard !initialized else { return }

      let _ = receptionist
      soundSets = [
        EmaxSoundSet(.BrassAndWoodwinds),
        EmaxSoundSet(.KeyboardsAndSynths),
        EmaxSoundSet(.GuitarsAndBasses),
        EmaxSoundSet(.WorldInstruments),
        EmaxSoundSet(.DrumsAndPercussion),
        EmaxSoundSet(.Orchestral)
      ]
      let bundle = NSBundle.mainBundle()
      let exclude = soundSets.map({$0.url})
      guard var urls = bundle.URLsForResourcesWithExtension("sf2", subdirectory: nil) else { return }
      urls = urls.flatMap({$0.fileReferenceURL()})
      do {
        try urls.filter({$0 ∉ exclude}).forEach { soundSets.append(try SoundSet(url: $0)) }
        guard soundSets.count > 0 else {
          fatalError("failed to create any sound sets from bundled sf2 files")
        }
        let soundSet = soundSets[0]
        let program = UInt8(soundSet.presets[0].program)
        auditionInstrument = try Instrument(track: nil, soundSet: soundSet, program: program, channel: 0)
        Notification.DidUpdateAvailableSoundSets.post()
      } catch {
        logError(error)
      }
      initialized = true
      logDebug("Sequencer initialized")
    }
  }

  private static let receptionist: NotificationReceptionist = {
    let receptionist = NotificationReceptionist()
    receptionist.logContext = LogManager.SequencerContext
    receptionist.observe(MIDIDocumentManager.Notification.DidChangeDocument,
                    from: MIDIDocumentManager.self,
                   queue: NSOperationQueue.mainQueue(),
                callback: Sequencer.didChangeDocument)
    receptionist.observe(Transport.Notification.DidStart) {
      if let transport = $0.object as? Transport where transport === Sequencer.transport {
        Sequencer.Notification.DidStart.post(object: Sequencer.self, userInfo: $0.userInfo)
      }
    }
    receptionist.observe(Transport.Notification.DidPause) {
      if let transport = $0.object as? Transport where transport === Sequencer.transport {
        Sequencer.Notification.DidPause.post(object: Sequencer.self, userInfo: $0.userInfo)
      }
    }
    receptionist.observe(Transport.Notification.DidStop) {
      if let transport = $0.object as? Transport where transport === Sequencer.transport {
        Sequencer.Notification.DidStop.post(object: Sequencer.self, userInfo: $0.userInfo)
      }
    }
    receptionist.observe(Transport.Notification.DidJog) {
      if let transport = $0.object as? Transport where transport === Sequencer.transport {
        Sequencer.Notification.DidJog.post(object: Sequencer.self, userInfo: $0.userInfo)
      }
    }
    receptionist.observe(Transport.Notification.DidBeginJogging) {
      if let transport = $0.object as? Transport where transport === Sequencer.transport {
        Sequencer.Notification.DidBeginJogging.post(object: Sequencer.self, userInfo: $0.userInfo)
      }
    }
    receptionist.observe(Transport.Notification.DidEndJogging) {
      if let transport = $0.object as? Transport where transport === Sequencer.transport {
        Sequencer.Notification.DidEndJogging.post(object: Sequencer.self, userInfo: $0.userInfo)
      }
    }
    return receptionist
    }()

  /**
  didChangeDocument:

  - parameter notification: NSNotification
  */
  private static func didChangeDocument(notification: NSNotification) {
    reset()
  }

  // MARK: - Sequence

  static private var sequence: Sequence? { return MIDIDocumentManager.currentDocument?.sequence }

  // MARK: - Time

  /** The MIDI clock */
//  static private let primaryClock = MIDIClock(name: "primary")
//  static private let primaryTime = BarBeatTime(clockSource: primaryClock.endPoint)

//  static private let auxiliaryClock = MIDIClock(name: "auxiliary")
//  static private let auxiliaryTime = BarBeatTime(clockSource: auxiliaryClock.endPoint)

  static private let primaryTransport = Transport(name: "primary")
  static private let auxiliaryTransport = Transport(name: "auxiliary")

  static var transport: Transport {
    switch mode {
      case .Default: return primaryTransport
      case .Loop:    return auxiliaryTransport
    }
  }

//  static private var clock: MIDIClock {
//    switch mode {
//      case .Default: return primaryClock
//      case .Loop:    return auxiliaryClock
//    }
//  }

  static var time: BarBeatTime { return transport.time }

  static let resolution: UInt64 = 480

  static var tickInterval: UInt64 { return transport.clock.tickInterval }
  static var nanosecondsPerBeat: UInt64 { return transport.clock.nanosecondsPerBeat }
  static var microsecondsPerBeat: UInt64 { return transport.clock.microsecondsPerBeat }
  static var secondsPerBeat: Double { return transport.clock.secondsPerBeat }
  static var secondsPerTick: Double { return transport.clock.secondsPerTick }

  /** The tempo used by the MIDI clock in beats per minute */
  // TODO: Need to make sure the current tempo is set at the beginning of a new sequence
  static var tempo: Double { get { return transport.tempo } set { setTempo(newValue) } }

  /**
  setTempo:automated:

  - parameter tempo: Double
  - parameter automated: Bool = false
  */
  static func setTempo(tempo: Double, automated: Bool = false) {
    primaryTransport.clock.beatsPerMinute = UInt16(tempo)
    auxiliaryTransport.clock.beatsPerMinute = UInt16(tempo)
    if recording && !automated { sequence?.tempo = tempo }
  }

  static var timeSignature: TimeSignature = .FourFour { didSet { sequence?.timeSignature = timeSignature } }

  /**
  setTimeSignature:automated:

  - parameter signature: TimeSignature
  - parameter automated: Bool = false
  */
  static func setTimeSignature(signature: TimeSignature, automated: Bool = false) {
    if recording && !automated { sequence?.timeSignature = signature }
  }

  // MARK: - Tracking modes and states

  static private var state: State = [] { didSet { logDebug("\(oldValue) ➞ \(state)") } }

  static private var clockRunning = false

  static var mode: Mode = .Default {
    willSet {
      guard mode != newValue else { return }
      logDebug("willSet: \(mode.rawValue) ➞ \(newValue.rawValue)")
      switch newValue {
        case .Default:
          Notification.WillExitLoopMode.post()
          auxiliaryTransport.clock.stop()
        case .Loop:
          clockRunning = primaryTransport.clock.running
          primaryTransport.clock.stop()
          Notification.WillEnterLoopMode.post()
      }
      Notification.DidStop.post()
    }
    didSet {
      guard mode != oldValue else { return }
      logDebug("didSet: \(oldValue.rawValue) ➞ \(mode.rawValue)")
      switch mode {
        case .Default:
          if clockRunning { primaryTransport.clock.resume() }
          Notification.DidExitLoopMode.post()
        case .Loop:
          auxiliaryTransport.clock.reset()
          Notification.DidEnterLoopMode.post()
      }
      Notification.DidChangeTransport.post()
    }
  }

  // MARK: - Tracks

  static private(set) var soundSets: [SoundSetType] = []

  static private(set) var auditionInstrument: Instrument!

  /** instrumentWithCurrentSettings */
  static func instrumentWithCurrentSettings() -> Instrument {
    return Instrument(track: nil, instrument: auditionInstrument)
  }

  static weak var soundSetSelectionTarget: Instrument! = Sequencer.auditionInstrument {
    didSet {
      guard oldValue !== soundSetSelectionTarget else { return }
      Notification.SoundSetSelectionTargetDidChange.post(object: self, userInfo: [
        .OldSoundSetSelectionTarget: oldValue,
        .NewSoundSetSelectionTarget: soundSetSelectionTarget
      ])
    }
  }

  // MARK: - Transport

  static var playing:          Bool { return transport.playing   }
  static var paused:           Bool { return transport.paused    }
  static var jogging:          Bool { return transport.jogging   }
  static var recording:        Bool { return transport.recording }

  /** beginJog */
  static func beginJog() { transport.beginJog() }

  /**
  jog:

  - parameter revolutions: Float
  */
  static func jog(revolutions: Float) { transport.jog(revolutions) }

  /** endJog */
  static func endJog() { transport.endJog() }

  /**
  jogToTime:

  - parameter time: CABarBeatTime
  */
  static func jogToTime(t: CABarBeatTime) throws { try transport.jogToTime(t) }

  /** Starts the MIDI clock */
  static func play() { transport.play() }

  /** toggleRecord */
  static func toggleRecord() { state ⊻= .Recording; Notification.DidToggleRecording.post() }

  /** pause */
  static func pause() { transport.pause() }

  /** Moves the time back to 0 */
  static func reset() { transport.reset() }

  /** Stops the MIDI clock */
  static func stop() { transport.stop() }

}

// MARK: - State
extension Sequencer {

  private struct State: OptionSetType, CustomStringConvertible {
    let rawValue: Int

    static let Playing   = State(rawValue: 0b0000_0010)
    static let Recording = State(rawValue: 0b0000_0100)
    static let Paused    = State(rawValue: 0b0001_0000)
    static let Jogging   = State(rawValue: 0b0010_0000)

    var description: String {
      var result = "["
      var flagStrings: [String] = []
      if contains(.Playing)            { flagStrings.append("Playing")   }
      if contains(.Recording)          { flagStrings.append("Recording") }
      if contains(.Paused)             { flagStrings.append("Paused")    }
      if contains(.Jogging)            { flagStrings.append("Jogging")   }
      result += ", ".join(flagStrings)
      result += " ]"
      return result
    }
  }

}

// MARK: - Notification
extension Sequencer {

  // MARK: - Notifications
  enum Notification: String, NotificationType, NotificationNameType {
    case DidStart, DidPause, DidStop, DidReset
    case DidToggleRecording
    case DidBeginJogging, DidEndJogging
    case DidJog
    case WillEnterLoopMode, WillExitLoopMode
    case DidEnterLoopMode, DidExitLoopMode
    case DidChangeTransport
    case SoundSetSelectionTargetDidChange
    case DidUpdateAvailableSoundSets

    var object: AnyObject? { return Sequencer.self }

    enum Key: String, NotificationKeyType {
      case OldSoundSetSelectionTarget, NewSoundSetSelectionTarget
    }
  }

}

extension Sequencer {
  enum Mode: String { case Default, Loop }
}

// MARK: - Error
extension Sequencer {
  enum Error: String, ErrorType {
    case InvalidBarBeatTime
    case NotPermitted
  }
}

extension NSNotification {
  var oldSoundSetSelectionTarget: Instrument? {
    return userInfo?[Sequencer.Notification.Key.OldSoundSetSelectionTarget.key] as? Instrument
  }
  var newSoundSetSelectionTarget: Instrument? {
    return userInfo?[Sequencer.Notification.Key.NewSoundSetSelectionTarget.key] as? Instrument
  }
}