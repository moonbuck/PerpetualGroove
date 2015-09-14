//
//  InstrumentTrack.swift
//  MidiSprite
//
//  Created by Jason Cardwell on 8/14/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import Foundation
import UIKit
import MoonKit
import AudioToolbox
import CoreMIDI

final class InstrumentTrack: MIDITrackType, Equatable {

  var description: String {
    var result = "Track(\(name)) {\n"
    result += "\tinstrument: \(instrument.description.indentedBy(4, true))\n"
    result += "\tcolor: \(color)\n\tevents: {\n"
    result += ",\n".join(events.map({$0.description.indentedBy(8)}))
    result += "\n\t}\n}"
    return result
  }

  typealias Program = Instrument.Program
  typealias Channel = Instrument.Channel

  // MARK: - Constant properties

  let instrument: Instrument
  let color: Color
  let playbackMode: Bool

  typealias NodeIdentifier = MIDINodeEvent.Identifier

  private var nodes: Set<MIDINode> = []
  private var notes: Set<NodeIdentifier> = []
  private var fileIDToNodeID: [NodeIdentifier:NodeIdentifier] = [:]
  private var client = MIDIClientRef()
  private var inPort = MIDIPortRef()
  private var outPort = MIDIPortRef()
  private let fileQueue: dispatch_queue_t?
  private var pendingIdentifier: NodeIdentifier?

  let time = BarBeatTime(clockSource: Sequencer.clockSource)

  var recording = false

  private func recordingStatusDidChange(notification: NSNotification) { recording = Sequencer.recording }

  private var notificationReceptionist: NotificationReceptionist?

  private func appendEvent(var event: MIDITrackEvent) {
    guard !playbackMode && recording else { return }
    event.time = time.time
    events.append(event)
  }
  private(set) var events: [MIDITrackEvent] = []

  var chunk: MIDIFileTrackChunk {
    var trackEvents = events
    trackEvents.insert(MetaEvent(.SequenceTrackName(name: name)), atIndex: 0)
    let instrumentName = "instrument:\(instrument.soundSet.url.lastPathComponent!)"
    trackEvents.insert(MetaEvent(.Text(text: instrumentName)), atIndex: 1)
    trackEvents.insert(ChannelEvent(.ProgramChange, instrument.channel, instrument.program), atIndex: 2)
    trackEvents.append(MetaEvent(.EndOfTrack))
    return MIDIFileTrackChunk(events: trackEvents)
  }

  // MARK: - Editable properties

  var name: String { return label ?? instrument.programPreset.name }
  var label: String?

  var volume: Float { get { return instrument.volume } set { instrument.volume = newValue } }
  var pan: Float { get { return instrument.pan } set { instrument.pan = newValue } }

  enum Error: String, ErrorType, CustomStringConvertible {
    case NodeNotFound = "The specified node was not found among the track's nodes"
  }

  /**
  addNode:

  - parameter node: MIDINode
  */
  func addNode(node: MIDINode) throws {
    nodes.insert(node)
    let identifier = NodeIdentifier(ObjectIdentifier(node).uintValue)
    notes.insert(identifier)
    try MIDIPortConnectSource(inPort, node.endPoint, nil) ➤ "Failed to connect to node \(node.name!)"
    guard recording else {
      if let pendingIdentifier = pendingIdentifier {
        fileIDToNodeID[pendingIdentifier] = identifier
        self.pendingIdentifier = nil
      }
      return
    }
    dispatch_async(fileQueue!) {
      [placement = node.placement, attributes = node.note, texture = node.textureType] in

      self.appendEvent(
        MIDINodeEvent(.Add(identifier: identifier, placement: placement, attributes: attributes, texture: texture)
        )
      )
    }
  }

  /**
  addNodeWithIdentifier:placement:attributes:texture:

  - parameter identifier: NodeIdentifier
  - parameter placement: MIDINode.Placement
  - parameter attributes: NoteAttributes
  - parameter texture: MIDINode.TextureType
  */
  private func addNodeWithIdentifier(identifier: NodeIdentifier,
                           placement: MIDINode.Placement,
                          attributes: NoteAttributes,
                             texture: MIDINode.TextureType)
  {
    guard pendingIdentifier == nil else { fatalError("already have an identifier pending: \(pendingIdentifier!)") }
    guard let midiPlayer = MIDIPlayerViewController.currentInstance?.playerScene?.midiPlayer else {
      fatalError("trying to add node without a midi player")
    }
    pendingIdentifier = identifier
    midiPlayer.placeNew(placement, targetTrack: self, attributes: attributes, texture: texture)
  }

  /**
  removeNodeWithIdentifier:

  - parameter identifier: NodeIdentifier
  */
  private func removeNodeWithIdentifier(identifier: NodeIdentifier) {
    guard let mappedIdentifier = fileIDToNodeID[identifier] else {
      fatalError("trying to remove node for unmapped identifier \(identifier)")
    }
    guard let idx = nodes.indexOf({$0.sourceID == mappedIdentifier}) else {
      fatalError("failed to find node with mapped identifier \(mappedIdentifier)")
    }
    let node = nodes[idx]
    do {
      try removeNode(node)
      node.removeFromParent()
      fileIDToNodeID[identifier] = nil
    } catch {
      logError(error)
    }
  }

  /**
  removeNode:

  - parameter node: MIDINode
  */
  func removeNode(node: MIDINode) throws {
    guard let node = nodes.remove(node) else { throw Error.NodeNotFound }
    let identifier = NodeIdentifier(ObjectIdentifier(node).uintValue)
    notes.remove(identifier)
    node.sendNoteOff()
    try MIDIPortDisconnectSource(inPort, node.endPoint) ➤ "Failed to disconnect to node \(node.name!)"
    guard recording else { return }
    dispatch_async(fileQueue!) {
      self.appendEvent(MIDINodeEvent(.Remove(identifier: identifier)))
    }
  }

  /**
  Reconstructs the `uintValue` of an `ObjectIdentifier` using packet data bytes 4 through 11

  - parameter packet: MIDIPacket

  - returns: UInt?
  */
  private func nodeIdentifierFromPacket(var packet: MIDIPacket) -> NodeIdentifier? {
    guard packet.length == UInt16(sizeof(NodeIdentifier.self) + 3) else { return nil }
    return NodeIdentifier(withUnsafePointer(&packet.data) {
      UnsafeBufferPointer<Byte>(start: UnsafePointer<Byte>($0).advancedBy(3), count: sizeof(NodeIdentifier.self))
    })
  }

  /**
  read:context:

  - parameter packetList: UnsafePointer<MIDIPacketList>
  - parameter context: UnsafeMutablePointer<Void>
  */
  private func read(packetList: UnsafePointer<MIDIPacketList>, context: UnsafeMutablePointer<Void>) {

//    guard !playbackMode else { return }

    // Forward the packets to the instrument
    do { try MIDISend(outPort, instrument.endPoint, packetList) ➤ "Failed to forward packet list to instrument" }
    catch { logError(error) }

    // Check if we are recording, otherwise skip event processing
    guard recording else { return }
    
    dispatch_async(fileQueue!) {
      let packets = packetList.memory
      let packetPointer = UnsafeMutablePointer<MIDIPacket>.alloc(1)
      packetPointer.initialize(packets.packet)
      guard packets.numPackets == 1 else { fatalError("Packets must be sent to track one at a time") }

      let packet = packetPointer.memory
      let ((status, channel), note, velocity) = ((packet.data.0 >> 4, packet.data.0 & 0xF), packet.data.1, packet.data.2)
      let event: MIDITrackEvent?
      switch status {
        case 9:  event = ChannelEvent(.NoteOn, channel, note, velocity)
        case 8:  event = ChannelEvent(.NoteOff, channel, note, velocity)
        default: event = nil
      }
      if event != nil { self.appendEvent(event!) }
    }
  }

  /**
  dispatchChannelEvent:

  - parameter channelEvent: ChannelEvent
  */
  private func dispatchChannelEvent(channelEvent: ChannelEvent) {
    var packetList = MIDIPacketList()
    let packet = MIDIPacketListInit(&packetList)
    let size = sizeof(UInt32.self) + sizeof(MIDIPacket.self)
    var data: [Byte] = [channelEvent.status.value, channelEvent.data1]
    if let data2 = channelEvent.data2 { data.append(data2) }
    let timeStamp = time.timeStamp
    MIDIPacketListAdd(&packetList, size, packet, timeStamp, 3, data)
    withUnsafePointer(&packetList) {
      do { try MIDISend(outPort, instrument.endPoint, $0) ➤ "Failed to dispatch packet list to instrument" }
      catch { logError(error) }
    }
  }

  /**
  reset:

  - parameter notification: NSNotification
  */
  private func reset(notification: NSNotification) { time.reset() }

  /**
  didStart:

  - parameter notification: NSNotification
  */
  private func didStart(notification: NSNotification) { logDebug("time = \(time)") }

  /** initializeNotificationReceptionist */
  private func initializeNotificationReceptionist() {
    guard notificationReceptionist == nil else { return }
    typealias Callback = NotificationReceptionist.Callback
    let recordingCallback: Callback = (Sequencer.self, NSOperationQueue.mainQueue(), recordingStatusDidChange)
    let resetCallback: Callback = (Sequencer.self, NSOperationQueue.mainQueue(), reset)
    let didStartCallback: Callback = (Sequencer.self, NSOperationQueue.mainQueue(), didStart)
    notificationReceptionist = NotificationReceptionist(callbacks: [
      Sequencer.Notification.DidTurnOnRecording.name.value : recordingCallback,
      Sequencer.Notification.DidTurnOffRecording.name.value : recordingCallback,
      Sequencer.Notification.DidReset.name.value : resetCallback,
      Sequencer.Notification.DidStart.name.value: didStartCallback
      ])
  }

  /** initializeMIDIClient */
  private func initializeMIDIClient() throws {
    try MIDIClientCreateWithBlock("track \(instrument.bus)", &client, nil) ➤ "Failed to create midi client"
    try MIDIOutputPortCreate(client, "Output", &outPort) ➤ "Failed to create out port"
    try MIDIInputPortCreateWithBlock(client, name, &inPort, read) ➤ "Failed to create in port"
  }

  /**
  initWithBus:track:

  - parameter b: Bus
  */
  init(instrument i: Instrument) throws {
    instrument = i
    color = Color.allCases[Sequencer.sequence.tracks.count % 10]
    fileQueue = serialQueueWithLabel("BUS \(instrument.bus)", qualityOfService: QOS_CLASS_BACKGROUND)
    recording = Sequencer.recording
    playbackMode = false

    initializeNotificationReceptionist()

    try initializeMIDIClient()
  }

  private var eventMap: [CABarBeatTime:[MIDITrackEvent]] = [:]

  /**
  dispatchEventsForTime:

  - parameter time: CABarBeatTime
  */
  private func dispatchEventsForTime(time: CABarBeatTime) {
    logDebug("time: \(time)")
    guard let events = eventMap[time] else { return }
    for event in events {
      switch event {
//        case let channelEvent as ChannelEvent: dispatchChannelEvent(channelEvent)
        case let nodeEvent as MIDINodeEvent:
          switch nodeEvent.data {
            case let .Add(i, p, a, t):    addNodeWithIdentifier(i, placement: p, attributes: a, texture: t)
            case let .Remove(identifier): removeNodeWithIdentifier(identifier)
          }
        default: break
      }

    }
  }

  /**
  initWithTrackChunk:

  - parameter trackChunk: MIDIFileTrackChunk
  */
  init(trackChunk: MIDIFileTrackChunk) throws {
    playbackMode = true
    color = Color.allCases[Sequencer.sequence.tracks.count % 10]
    fileQueue = nil
    recording = false

    let isInstrumentEvent: (MIDITrackEvent) -> Bool = {
      guard let metaEvent = $0 as? MetaEvent else { return false }
      switch metaEvent.data {
        case .Text(let text) where text.hasPrefix("instrument:"): return true
        default: return false
      }
    }

    let isProgramChangeEvent: (MIDITrackEvent) -> Bool = {
      guard let channelEvent = $0 as? ChannelEvent else { return false }
      switch channelEvent.status.type {
        case .ProgramChange: return true
        default: return false
      }
    }

    guard let instrumentMetaEvent = trackChunk.events.first(isInstrumentEvent) as? MetaEvent else { fatalError("wtf") }


    guard case var .Text(instrumentName) = instrumentMetaEvent.data else { fatalError("wtf") }

    instrumentName = instrumentName[instrumentName.startIndex.advancedBy(11)..<]

     guard let fileURL = NSBundle.mainBundle().URLForResource(instrumentName, withExtension: nil) else { fatalError("wtf") }

    guard let soundSet = try? SoundSet(url: fileURL) else { fatalError("wtf") }
    guard let programEvent = trackChunk.events.first(isProgramChangeEvent) as? ChannelEvent else { fatalError("wtf") }
    guard let instrumentMaybe = try? Instrument(soundSet: soundSet, program: programEvent.data1, channel: programEvent.status.channel) else { fatalError("wtf") }
//    {
      instrument = instrumentMaybe
//    } else {
//      fatalError("wtf")
//      instrument = Instrument(instrument: Sequencer.auditionInstrument)
//    }

    events = trackChunk.events

    for event in events {
      let eventTime = event.time
      var eventBag: [MIDITrackEvent] = eventMap[eventTime] ?? []
      eventBag.append(event)
      eventMap[eventTime] = eventBag
    }
    for eventTime in eventMap.keys { time.registerCallback(dispatchEventsForTime, forTime: eventTime) }

    logDebug("eventMap = \(eventMap)")

    initializeNotificationReceptionist()

    try initializeMIDIClient()
  }

  // MARK: - Enumeration for specifying the color attached to a `MIDITrackType`
  enum Color: UInt32, EnumerableType, CustomStringConvertible {
    case White      = 0xffffff
    case Portica    = 0xf7ea64
    case MonteCarlo = 0x7ac2a5
    case FlamePea   = 0xda5d3a
    case Crimson    = 0xd6223e
    case HanPurple  = 0x361aee
    case MangoTango = 0xf88242
    case Viking     = 0x6bcbe1
    case Yellow     = 0xfde97e
    case Conifer    = 0x9edc58
    case Apache     = 0xce9f58

    var value: UIColor { return UIColor(RGBHex: rawValue) }
    var description: String {
      switch self {
        case .White:      return "White"
        case .Portica:    return "Portica"
        case .MonteCarlo: return "MonteCarlo"
        case .FlamePea:   return "FlamePea"
        case .Crimson:    return "Crimson"
        case .HanPurple:  return "HanPurple"
        case .MangoTango: return "MangoTango"
        case .Viking:     return "Viking"
        case .Yellow:     return "Yellow"
        case .Conifer:    return "Conifer"
        case .Apache:     return "Apache"
      }
    }

    /// `White` case is left out so that it is harder to assign the color used by `MasterTrack`
    static let allCases: [Color] = [.Portica, .MonteCarlo, .FlamePea, .Crimson, .HanPurple,
                                    .MangoTango, .Viking, .Yellow, .Conifer, .Apache]
  }

}


func ==(lhs: InstrumentTrack, rhs: InstrumentTrack) -> Bool { return lhs.instrument == rhs.instrument }

