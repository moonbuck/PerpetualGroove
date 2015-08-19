//
//  Mixer.swift
//  MidiSprite
//
//  Created by Jason Cardwell on 8/15/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import Foundation
import MoonKit
import AudioToolbox
import AudioUnit
import CoreAudio

final class Mixer {

  // MARK: - Some typealiases of convenience

  typealias Bus = AudioUnitElement
  typealias ParameterValue = AudioUnitParameterValue

  // MARK: - An enumeration to wrap up notifications

  enum Notification {
    case TrackAdded (Bus)
    case TrackRemoved (Bus)

    enum NotificationName: String { case DidAddTrack, DidRemoveTrack }

    static let BusKey = "bus"

    var name: NotificationName {
      switch self {
      case .TrackAdded: return .DidAddTrack
      case .TrackRemoved: return .DidRemoveTrack
      }
    }

    private func post() {
      let userInfo: [NSObject:AnyObject]?
      switch self {
        case .TrackAdded(let bus):   userInfo = [Notification.BusKey: NSNumber(unsignedInt: bus)]
        case .TrackRemoved(let bus): userInfo = [Notification.BusKey: NSNumber(unsignedInt: bus)]
      }
      MSLogDebug("posting notification \(self))")
      NSNotificationCenter.defaultCenter().postNotificationName(name.rawValue, object: Mixer.self, userInfo: userInfo)
    }
  }

  // MARK: - Type for Mixer-specific errors

  enum Error: String, ErrorType, CustomStringConvertible {
    case GraphAlreadyExists = "The mixer already has a graph"
    case AudioUnitIsNotAMixer = "The audio unit for the specified node is not a mixer unit"
    case GraphNotInitialized = "The audio graph should already be initialized"
    case GraphOpen = "The graph provided has already been opened"
    case GraphNotOpen = "The graph provided has not already been opened"
    case IOUnitNotFound = "Failed to find an appropriate IO audio unit"
    case NilGraph = "Graph is nil"
    case NilMixerNode = "Mixer node is nil"
    case NilMixerUnit = "Mixer unit is nil"

    var description: String { return rawValue }
  }


  // MARK: - Static properties

  static private(set) var tracks: OrderedDictionary<Bus, InstrumentTrack> = [:]

  static var instruments: [Instrument] { return tracks.values.map { $0.instrument } }

  static private var mixerNode: AUNode?
  static private var mixerUnit: AudioUnit?
  static private var graph: AUGraph?

  static var currentTrack: InstrumentTrack?

  // MARK: - Initializing the mixer

  /**
  initializeWithGraph:

  - parameter g: AUGraph
  */
  static func initializeWithGraph(graph g: AUGraph, node: AUNode) throws {
    guard graph == nil else { throw Error.GraphAlreadyExists }
    var isInitialized = DarwinBoolean(false)
    try AUGraphIsInitialized(g, &isInitialized) ➤ "Failed to check whether graph is initialized"
    guard isInitialized else { throw Error.GraphNotInitialized }
    var audioUnit = AudioUnit()
    try AUGraphNodeInfo(g, node, nil, &audioUnit) ➤ "Failed to get audio unit from graph"
    var description = AudioComponentDescription()
    try AudioComponentGetDescription(audioUnit, &description) ➤ "Failed to get audio unit description"
    guard description.componentType == kAudioUnitType_Mixer
       && description.componentSubType == kAudioUnitSubType_MultiChannelMixer
       && description.componentManufacturer == kAudioUnitManufacturer_Apple else { throw Error.AudioUnitIsNotAMixer }
    mixerUnit = audioUnit
    mixerNode = node
    graph = g
  }

  // MARK: - Adding/Removing/Retrieving tracks

  /**
  existingTrackForInstrumentWithDescription:

  - parameter description: InstrumentDescription

  - returns: InstrumentTrack?
  */
  static func existingTrackWithSoundSet(soundSet: SoundSet) -> InstrumentTrack? {
    return tracks.filter({$2.instrument.soundSet == soundSet}).first?.2
  }

  /**
  nextAvailableBus

  - returns: Bus
  */
  private static func nextAvailableBus() -> Bus {
    guard tracks.count > 0 else { return 0 }
    return tracks.keys.maxElement()! + 1
  }

  /**
  newTrackForInstrumentWithDescription:

  - parameter description: InstrumentDescription
  */
  static func newTrackWithSoundSet(soundSet: SoundSet) throws -> InstrumentTrack {
    guard let graph = graph else { throw Error.NilGraph }
    guard let mixerNode = mixerNode else { throw Error.NilMixerNode }

    let instrument = try Instrument(graph: graph, soundSet: soundSet)

    let bus = nextAvailableBus()
    try AUGraphConnectNodeInput(graph, instrument.node, 0, mixerNode, bus) ➤ "Failed to connect instrument to mixer"
    try AUGraphUpdate(graph, nil) ➤ "Failed to update audio graph"

    let musicTrack = try AudioManager.newTrackForInstrument(instrument)

    let track = InstrumentTrack(instrument: instrument, bus: bus, track: musicTrack)
    tracks[bus] = track

    Notification.TrackAdded(bus).post()

    print("graph after \(__FUNCTION__)")
    CAShow(UnsafeMutablePointer<COpaquePointer>(graph))
    print("")

    return track
  }

  /**
  removeTrackOnBus:

  - parameter bus: Bus
  */
  static func removeTrackOnBus(bus: Bus) {

  }

  // MARK: - Internally used helpers

  private enum Parameter: String {
    case Volume, Pan, Enable
    var id: AudioUnitParameterID {
      switch self {
        case .Volume: return kMultiChannelMixerParam_Volume
        case .Pan:    return kMultiChannelMixerParam_Pan
        case .Enable: return kMultiChannelMixerParam_Enable
      }
    }
  }

  private enum Scope: String {
    case Input, Output
    var value: AudioUnitScope {
      switch self {
        case .Input: return kAudioUnitScope_Input
        case .Output:return kAudioUnitScope_Output
      }
    }
  }

  /**
  setParameter:forBus:toValue:

  - parameter parameter: Parameter
  - parameter bus: Bus
  - parameter value: ParameterValue
  */
  private static func setParameter(parameter: Parameter,
                             onBus bus: Bus,
                           toValue value: ParameterValue,
                             scope: Scope) throws
  {
    guard let mixerUnit = mixerUnit else { throw Error.NilMixerUnit }
    try AudioUnitSetParameter(mixerUnit, parameter.id, scope.value, bus, value, 0)
      ➤ "adjusting \(parameter.rawValue.lowercaseString) on bus \(bus)"
  }

  /**
  valueForParameter:onBus:

  - parameter parameter: Parameter
  - parameter bus: Bus
  */
  private static func valueForParameter(parameter: Parameter,
                                  onBus bus: Bus,
                                  scope: Scope) throws -> ParameterValue
  {
    guard let mixerUnit = mixerUnit else { throw Error.NilMixerUnit }
    var value = ParameterValue()
    try AudioUnitGetParameter(mixerUnit, parameter.id, scope.value, bus, &value)
      ➤ "retrieving \(parameter.rawValue.lowercaseString) on bus \(bus)"
    return value
  }

  // MARK: - Output volume/pan/enable

  /**
  setMasterVolume:

  - parameter volume: ParameterValue
  */
  static func setMasterVolume(volume: ParameterValue) throws {
    try setParameter(.Volume, onBus: 0, toValue: volume, scope: .Output)
  }

  /** masterVolume */
  static func masterVolume() throws -> ParameterValue {
    return try valueForParameter(.Volume, onBus: 0, scope: .Output)
  }

  /**
  setMasterPan:

  - parameter pan: ParameterValue
  */
  static func setMasterPan(pan: ParameterValue) throws {
    try setParameter(.Pan, onBus: 0, toValue: pan, scope: .Output)
  }

  /** masterPan */
  static func masterPan() throws -> ParameterValue {
    return try valueForParameter(.Pan, onBus: 0, scope: .Output)
  }

  /** masterEnable */
  static func masterEnable() throws {
    try setParameter(.Enable, onBus: 0, toValue: ParameterValue(1), scope: .Output)
  }

  /** masterDisable */
  static func masterDisable() throws {
    try setParameter(.Enable, onBus: 0, toValue: ParameterValue(0), scope: .Output)
  }

  /** isMasterEnabled */
  static func isMasterEnabled() throws -> Bool {
    return try valueForParameter(.Enable, onBus: 0, scope: .Output) == 1
  }

  // MARK: - Input volume/pan/enable

  /**
  setVolume:onBus:

  - parameter volume: ParameterValue
  - parameter bus: Bus
  */
  static func setVolume(volume: ParameterValue, onBus bus: Bus) throws {
    try setParameter(.Volume, onBus: bus, toValue: volume, scope: .Input)
  }

  /**
  setPan:onBus:

  - parameter pan: ParameterValue
  - parameter bus: Bus
  */
  static func setPan(pan: ParameterValue, onBus bus: Bus) throws {
    try setParameter(.Pan, onBus: bus, toValue: pan, scope: .Input)
  }

  /**
  volumeOnBus:

  - parameter bus: Bus
  */
  static func volumeOnBus(bus: Bus) throws -> ParameterValue {
    return try valueForParameter(.Volume, onBus: bus, scope: .Input)
  }

  /**
  panOnBus:

  - parameter bus: Bus
  */
  static func panOnBus(bus: Bus) throws -> ParameterValue {
    return try valueForParameter(.Pan, onBus: bus, scope: .Input)
  }

  /**
  enableBus:

  - parameter bus: Bus
  */
  static func enableBus(bus: Bus) throws {
    try setParameter(.Enable, onBus: bus, toValue: ParameterValue(1), scope: .Input)
  }

  /**
  disableBus:

  - parameter bus: Bus
  */
  static func disableBus(bus: Bus) throws {
    try setParameter(.Enable, onBus: bus, toValue: ParameterValue(0), scope: .Input)
  }

  /**
  isBusEnabled:

  - parameter bus: Bus
  */
  static func isBusEnabled(bus: Bus) throws -> Bool {
    return try valueForParameter(.Enable, onBus: bus, scope: .Input) == 1
  }

}