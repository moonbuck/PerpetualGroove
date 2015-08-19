//
//  AudioManager.swift
//  MidiSprite
//
//  Created by Jason Cardwell on 8/8/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import Foundation
import AVFoundation
import MoonKit
import CoreMIDI
import CoreAudio
import AudioToolbox

final class AudioManager {

  static let queue = dispatch_queue_create("midi", DISPATCH_QUEUE_SERIAL)

  static private var graph = AUGraph()
  static private var ioNode = AUNode()
  static private var ioUnit = AudioUnit()
  static private var dynamicsNode = AUNode()
  static private var dynamicsUnit = AudioUnit()
  static private(set) var musicPlayer = MusicPlayer()
  static private(set) var musicSequence = MusicSequence()
  static private var mixerNode = AUNode()
  static private var mixerUnit = AudioUnit()

  private static var initialized = false

  /** initialize */
  static func initialize() {
    guard !initialized else { return }

    // Try to configure the audio session
    do {
      try configureAudioSession()
      try configureAudioGraph()
      try configureMusicPlayer()
    } catch { logError(error); return }

  }

  /** configureMusicPlayer */
  static func configureMusicPlayer() throws {
    try NewMusicPlayer(&musicPlayer) ➤ "Failed to create music player"
    try NewMusicSequence(&musicSequence) ➤ "Failed to create music sequence"
    try MusicSequenceSetAUGraph(musicSequence, graph) ➤ "Failed to set graph from sequence"
    try MusicPlayerSetSequence(musicPlayer, musicSequence) ➤ "Failed to set sequence on player"
  }


  /** configureAudioSession */
  private static func configureAudioSession() throws {
    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(AVAudioSessionCategoryPlayback)
    try audioSession.setActive(true)
  }

  /** configureAudioGraph */
  private static func configureAudioGraph() throws {
    // Create graph
    try NewAUGraph(&graph) ➤ "Failed to create new audio graph"

    // Add nodes
    var ioComponentDescription = AudioComponentDescription(componentType: kAudioUnitType_Output,
                                                           componentSubType: kAudioUnitSubType_RemoteIO,
                                                           componentManufacturer: kAudioUnitManufacturer_Apple,
                                                           componentFlags: 0,
                                                           componentFlagsMask: 0)

    try AUGraphAddNode(graph, &ioComponentDescription, &ioNode) ➤ "Failed to add io node"

    var dynamicsComponentDescription = AudioComponentDescription(componentType: kAudioUnitType_Effect,
                                                                 componentSubType: kAudioUnitSubType_DynamicsProcessor,
                                                                 componentManufacturer: kAudioUnitManufacturer_Apple,
                                                                 componentFlags: 0,
                                                                 componentFlagsMask: 0)
    try AUGraphAddNode(graph, &dynamicsComponentDescription, &dynamicsNode) ➤ "Failed to add dynamics node"

    var mixerComponentDescription = AudioComponentDescription(componentType: kAudioUnitType_Mixer,
                                                              componentSubType: kAudioUnitSubType_MultiChannelMixer,
                                                              componentManufacturer: kAudioUnitManufacturer_Apple,
                                                              componentFlags: 0,
                                                              componentFlagsMask: 0)
    try AUGraphAddNode(graph, &mixerComponentDescription, &mixerNode) ➤ "Failed to add mixer node to audio graph"

    // Open graph

    try AUGraphOpen(graph) ➤ "Failed to open audio graph"

    // Retrieve audio units

    try AUGraphNodeInfo(graph, ioNode, nil, &ioUnit) ➤ "Failed to retrieve io unit"
    try AUGraphNodeInfo(graph, dynamicsNode, nil, &dynamicsUnit) ➤ "Failed to retrieve dynamics unit"
    try AUGraphNodeInfo(graph, mixerNode, nil, &mixerUnit) ➤ "Failed to retrieve mixer unit"

    // Configure units

    var maxFrames = UInt32(4096)
    try AudioUnitSetProperty(ioUnit,
                             kAudioUnitProperty_MaximumFramesPerSlice,
                             kAudioUnitScope_Global,
                             0,
                             &maxFrames,
                             UInt32(sizeof(UInt32.self))) ➤ "Failed to set max frames per slice on io unit"
    try AudioUnitSetProperty(dynamicsUnit,
                             kAudioUnitProperty_MaximumFramesPerSlice,
                             kAudioUnitScope_Global,
                             0,
                             &maxFrames,
                             UInt32(sizeof(UInt32.self))) ➤ "Failed to set max frames per slice on dynamics unit"
    try AudioUnitSetProperty(mixerUnit,
                             kAudioUnitProperty_MaximumFramesPerSlice,
                             kAudioUnitScope_Global,
                             0,
                             &maxFrames,
                             UInt32(sizeof(UInt32.self))) ➤ "Failed to set max frames per slice on mixer unit"
    try AUGraphConnectNodeInput(graph, dynamicsNode, 0, ioNode, 0) ➤ "Failed to connect dynamics to io"
    try AUGraphConnectNodeInput(graph, mixerNode, 0, dynamicsNode, 0) ➤ "Failed to connect mixer to dynamis"


    // Initialize graph

    try AUGraphInitialize(graph) ➤ "Failed to initialize audio graph"

    try Mixer.initializeWithGraph(graph: graph, node: mixerNode)
  }

  /**
  newTrackForInstrument:

  - parameter instrument: Instrument
  */
  static func newTrackForInstrument(instrument: Instrument) throws -> MusicTrack {
    var musicTrack = MusicTrack()
    try MusicSequenceNewTrack(musicSequence, &musicTrack) ➤ "Failed to create new music track"
    try MusicTrackSetDestNode(musicTrack, instrument.node) ➤ "Failed to set dest node for track"
    return musicTrack
  }

  /** start */
  static func start() throws {
    var running = DarwinBoolean(false)
    try AUGraphIsRunning(graph, &running) ➤ "Failed to check running status of audio graph"
    guard !running else { return }
    try AUGraphStart(graph) ➤ "Failed to start audio graph"
  }

  /** stop */
  static func stop() throws {
    var running = DarwinBoolean(false)
    try AUGraphIsRunning(graph, &running) ➤ "Failed to check running status of audio graph"
    guard running else { return }
    try AUGraphStop(graph) ➤ "Failed to stop audio graph"
    try MusicPlayerIsPlaying(musicPlayer, &running) ➤ "Failed to check playing status of music player"
    guard running else { return }
    try MusicPlayerStop(musicPlayer) ➤ "Failed to stop music player"
  }

}
