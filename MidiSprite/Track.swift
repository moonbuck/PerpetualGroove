//
//  Track.swift
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

final class Track: TrackType, Equatable {

  var description: String {
    return "Track(\(label)) {\n\tbus: \(bus)\n\tcolor: \(color)\nevents: {\n" +
           ",\n".join(events.map({$0.description.indentedBy(8)})) + "\n\t}\n}"
  }

  typealias Program = Instrument.Program
  typealias Channel = Instrument.Channel

  // MARK: - Constant properties

  var instrument: Instrument { return bus.instrument }

  let bus: Bus
  let color: Color

  private var nodes: Set<MIDINode> = []
  private var notes: Set<UInt> = []
  private var lastEvent: [UInt:MIDITimeStamp] = [:]
  private var client = MIDIClientRef()
  private var inPort = MIDIPortRef()
  private var outPort = MIDIPortRef()
  private let fileQueue: dispatch_queue_t
  private let time = BarBeatTime(clockSource: Sequencer.clockSource)

  private(set) var events: [TrackEvent] = []

  // MARK: - Editable properties

  private var _label: String?
  var label: String {
    get {
      guard _label == nil else { return _label! }
      _label = "BUS \(bus.element)"
      return _label!
    } set {
      _label = newValue
    }
  }

  var volume: Float { get { return bus.volume } set { bus.volume = newValue } }
  var pan: Float { get { return bus.pan } set { bus.pan = newValue } }

  enum Error: String, ErrorType, CustomStringConvertible {
    case NodeNotFound = "The specified node was not found among the track's nodes"
  }

  /**
  addNode:

  - parameter node: MIDINode
  */
  func addNode(node: MIDINode) throws {
    nodes.insert(node)
    let identifier = ObjectIdentifier(node).uintValue
    notes.insert(identifier)
    lastEvent[identifier] = 0
    dispatch_async(fileQueue) {
      [unowned self, placement = node.placement, timeStamp = time.timeStamp] in
        self.events.append(MetaEvent(deltaTime: timeStamp, data: .NodePlacement(placement: placement)))
    }
    try MIDIPortConnectSource(inPort, node.endPoint, nil) ➤ "Failed to connect to node \(node.name!)"
  }

  /**
  removeNode:

  - parameter node: MIDINode
  */
  func removeNode(node: MIDINode) throws {
    guard let node = nodes.remove(node) else { throw Error.NodeNotFound }
    let identifier = ObjectIdentifier(node).uintValue
    notes.remove(identifier)
    lastEvent[identifier] = nil
    node.sendNoteOff()
    try MIDIPortDisconnectSource(inPort, node.endPoint) ➤ "Failed to disconnect to node \(node.name!)"
  }

  /**
  Reconstructs the `uintValue` of an `ObjectIdentifier` using packet data bytes 4 through 11

  - parameter packet: MIDIPacket

  - returns: UInt?
  */
  private func nodeIdentifierFromPacket(var packet: MIDIPacket) -> UInt? {
    guard packet.length == 11 else { return nil }
    return UInt(withUnsafePointer(&packet.data) {
      Array(UnsafeMutableBufferPointer<Byte>(start: UnsafeMutablePointer<Byte>($0), count: 11)[3 ..< 11])
    })
//    return zip([packet.data.3, packet.data.4, packet.data.5, packet.data.6,
//                packet.data.7, packet.data.8, packet.data.9, packet.data.10],
//               [0, 8, 16, 24, 32, 40, 48, 56]).reduce(UInt(0)) { $0 | (UInt($1.0) << UInt($1.1)) }
  }

  /**
  read:context:

  - parameter packetList: UnsafePointer<MIDIPacketList>
  - parameter context: UnsafeMutablePointer<Void>
  */
  private func read(packetList: UnsafePointer<MIDIPacketList>, context: UnsafeMutablePointer<Void>) {
    dispatch_async(fileQueue) {
      [unowned self] in
      let packets = packetList.memory
      let packetPointer = UnsafeMutablePointer<MIDIPacket>.alloc(1)
      packetPointer.initialize(packets.packet)
      guard packets.numPackets == 1 else { fatalError("Packets must be sent to track one at a time") }

      let packet = packetPointer.memory
      guard let identifier = self.nodeIdentifierFromPacket(packet) where self.lastEvent[identifier] != packet.timeStamp else {
        return
      }
      self.lastEvent[identifier] = packet.timeStamp
      let ((status, channel), note, velocity) = ((packet.data.0 >> 4, packet.data.0 & 0xF), packet.data.1, packet.data.2)
      let event: TrackEvent?
      switch status {
        case 9:  event = ChannelEvent.noteOnEvent(packet.timeStamp, channel: channel, note: note, velocity: velocity)
        case 8:  event = ChannelEvent.noteOffEvent(packet.timeStamp, channel: channel, note: note, velocity: velocity)
        default: event = nil
      }
      if event != nil { self.events.append(event!) }
    }

    // Forward the packets to the instrument
    do { try MIDISend(outPort, bus.instrument.endPoint, packetList) ➤ "Failed to forward packet list to instrument" }
    catch { logError(error) }
  }

  /** Generates a MIDI file chunk from current track data */
  var chunk: TrackChunk {
    let nameEvent: TrackEvent = MetaEvent(deltaTime: .zero, data: .SequenceTrackName(name: label))
    let endEvent: TrackEvent  = MetaEvent(deltaTime: VariableLengthQuantity(time.timeStamp), data: .EndOfTrack)
    return TrackChunk(data: TrackChunkData(events: [nameEvent] + events + [endEvent]))
  }

  /**
  initWithBus:track:

  - parameter b: Bus
  */
  init(bus b: Bus) throws {
    bus = b
    color = Color.allCases[Int(bus.element) % 10]
    fileQueue = serialQueueWithLabel("BUS \(bus.element)", qualityOfService: QOS_CLASS_BACKGROUND)
    try MIDIClientCreateWithBlock("track \(bus.element)", &client, nil) ➤ "Failed to create midi client"
    try MIDIOutputPortCreate(client, "Output", &outPort) ➤ "Failed to create out port"
    try MIDIInputPortCreateWithBlock(client, label ?? "BUS \(bus.element)", &inPort, read) ➤ "Failed to create in port"
  }

  // MARK: - Enumeration for specifying the color attached to a `TrackType`
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


func ==(lhs: Track, rhs: Track) -> Bool { return lhs.bus == rhs.bus }

