//   LogManager.swift   PerpetualGroove    Created by Jason Cardwell on
//10/21/15.   Copyright © 2015 Moondeer Studios. All rights reserved.

import Foundation
import MoonKit
import struct AudioToolbox.CABarBeatTime
import class SpriteKit.SKNode

final class LogManager: MoonKit.LogManager {

  private(set) static var initialized = false

  static let MIDIFileContext  = LogContext(rawValue: 0b0000_0010_0000)
  static let SF2FileContext   = LogContext(rawValue: 0b0000_0100_0000)
  static let SequencerContext = LogContext(rawValue: 0b0000_1000_0000)
  static let SceneContext     = LogContext(rawValue: 0b0001_0000_0000)
  static let UIContext        = LogContext(rawValue: 0b0010_0000_0000)

  /** initialize */
  static func initialize() {
    guard !initialized else { return }

    setLogLevel(.Verbose, forType: NotificationReceptionist.self)

    MIDIDocumentManager.defaultLogContext     = MIDIFileContext// ∪ .Console
    MIDIDocument.defaultLogContext            = MIDIFileContext// ∪ .Console
    MIDIFile.defaultLogContext                = MIDIFileContext// ∪ .Console
    MIDIFileHeaderChunk.defaultLogContext     = MIDIFileContext// ∪ .Console
    MIDIFileTrackChunk.defaultLogContext      = MIDIFileContext// ∪ .Console
    MetaEvent.defaultLogContext               = MIDIFileContext// ∪ .Console
    ChannelEvent.defaultLogContext            = MIDIFileContext// ∪ .Console
    VariableLengthQuantity.defaultLogContext  = MIDIFileContext// ∪ .Console
    MIDINodeEvent.defaultLogContext           = MIDIFileContext// ∪ .Console
    MIDIEventContainer.defaultLogContext      = MIDIFileContext// ∪ .Console

    SF2File.defaultLogContext    = SF2FileContext// ∪ .Console
    Instrument.defaultLogContext = SF2FileContext// ∪ .Console
    SoundSet.defaultLogContext   = SF2FileContext// ∪ .Console
    INFOChunk.defaultLogContext  = SF2FileContext// ∪ .Console
    SDTAChunk.defaultLogContext  = SF2FileContext// ∪ .Console
    PDTAChunk.defaultLogContext  = SF2FileContext// ∪ .Console

    Sequencer.defaultLogContext       = SequencerContext// ∪ .Console
    Track.defaultLogContext           = SequencerContext// ∪ .Console
    MIDISequence.defaultLogContext    = SequencerContext// ∪ .Console
    AudioManager.defaultLogContext    = SequencerContext// ∪ .Console
    CABarBeatTime.defaultLogContext   = SequencerContext// ∪ .Console
    TimeSignature.defaultLogContext   = SequencerContext// ∪ .Console
    TrackColor.defaultLogContext      = SequencerContext// ∪ .Console
    Metronome.defaultLogContext       = SequencerContext// ∪ .Console
    MIDIClock.defaultLogContext       = SequencerContext// ∪ .Console
    BarBeatTime.defaultLogContext     = SequencerContext// ∪ .Console

    MIDIPlayerScene.defaultLogContext     = SceneContext
    MIDINodeHistory.defaultLogContext     = SceneContext
    MIDIPlayerNode.defaultLogContext      = SceneContext
    MIDIPlayerFieldNode.defaultLogContext = SceneContext
    MIDINode.defaultLogContext            = SceneContext
    Placement.defaultLogContext           = SceneContext

    MIDIPlayerViewController.defaultLogContext     = UIContext
    PurgatoryViewController.defaultLogContext      = UIContext
    DocumentsViewController.defaultLogContext      = UIContext
    InstrumentViewController.defaultLogContext     = UIContext
    NoteAttributesViewController.defaultLogContext = UIContext
    DocumentsViewLayout.defaultLogContext          = UIContext
    MixerLayout.defaultLogContext                  = UIContext
    BarBeatTimeLabel.defaultLogContext             = UIContext
    DocumentCell.defaultLogContext                 = UIContext
    MixerCell.defaultLogContext                    = UIContext

    addConsoleLoggers()

    let defaultDirectory: NSURL
    if let path = NSProcessInfo.processInfo().environment["GROOVE_LOG_DIR"] {
      defaultDirectory = NSURL(fileURLWithPath: path)
    } else {
      defaultDirectory = defaultLogDirectory
    }
    addDefaultFileLoggerForContext(.Console, directory: defaultDirectory)
    addDefaultFileLoggerForContext(MIDIFileContext, directory: defaultDirectory + "MIDI")
    addDefaultFileLoggerForContext(SF2FileContext, directory: defaultDirectory + "SoundFont")
    addDefaultFileLoggerForContext(SequencerContext, directory: defaultDirectory + "Sequencer")
    addDefaultFileLoggerForContext(SceneContext, directory: defaultDirectory + "Scene")
    addDefaultFileLoggerForContext(UIContext, directory: defaultDirectory + "UI")

    logLevel = .Debug
    logContext = .Console

    logDebug("\n".join("main bundle: '\(NSBundle.mainBundle().bundlePath)'",
                       "default log directory: '\(defaultDirectory.path!)'"))

    initialized = true
  }

  /**
  defaultFileLoggerForContext:directory:

  - parameter context: LogContext
  - parameter directory: NSURL

  - returns: DDFileLogger
  */
  static override func defaultFileLoggerForContext(context: LogContext, directory: NSURL) -> DDFileLogger {
    let logger = super.defaultFileLoggerForContext(context, directory: directory)
    logger.doNotReuseLogFiles = true
    (logger.logFormatter as? LogFormatter)?.afterMessage = ""
    return logger
  }

}

extension SF2File: Loggable {}
extension Instrument: Loggable {}
extension SoundSet: Loggable {}
extension EmaxSoundSet: Loggable {}
extension INFOChunk: Loggable {}
extension SDTAChunk: Loggable {}
extension PDTAChunk: Loggable {}

extension Sequencer: Loggable {}
extension Track: Loggable {}
extension MIDISequence: Loggable {}
extension AudioManager: Loggable {}
extension CABarBeatTime: Loggable {}
extension TimeSignature: Loggable {}
extension TrackColor: Loggable {}
extension Metronome: Loggable {}
extension MIDIClock: Loggable {}
extension BarBeatTime: Loggable {}

extension MIDIDocumentManager: Loggable {}
extension MIDIDocument: Loggable {}
extension MIDIFile: Loggable {}
extension MIDIFileHeaderChunk: Loggable {}
extension MIDIFileTrackChunk: Loggable {}
extension MetaEvent: Loggable {}
extension ChannelEvent: Loggable {}
extension VariableLengthQuantity: Loggable {}
extension MIDINodeEvent: Loggable {}
extension MIDINodeHistory: Loggable {}
extension MIDIEventContainer: Loggable {}

extension MIDIPlayerScene: Loggable {}
extension MIDIPlayerNode: Loggable {}
extension MIDIPlayerFieldNode: Loggable {}
extension MIDINode: Loggable {}
extension Placement: Loggable {}
extension SKNode: Nameable {}

extension MIDIPlayerViewController: Loggable {}
extension PurgatoryViewController: Loggable {}
extension DocumentsViewController: Loggable {}
extension InstrumentViewController: Loggable {}
extension NoteAttributesViewController: Loggable {}
extension DocumentsViewLayout: Loggable {}
extension MixerLayout: Loggable {}
extension BarBeatTimeLabel: Loggable {}
extension DocumentCell: Loggable {}
extension MixerCell: Loggable {}
