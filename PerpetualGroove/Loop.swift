//
//  Loop.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 12/18/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import Foundation
import MoonKit

final class Loop: Swift.Sequence, MIDINodeDispatch {

  var time: BarBeatTime { return Swift.min(end - start, BarBeatTime.zero) }

  var repetitions: Int = 0
  var repeatDelay: UInt64 = 0
  var eventContainer: MIDIEventContainer
  var start: BarBeatTime = BarBeatTime.zero
  var end: BarBeatTime = BarBeatTime.zero

  let identifier: UUID
  var eventQueue: DispatchQueue { return track.eventQueue }

  fileprivate(set) var nodeManager: MIDINodeManager!

  var nodes: OrderedSet<HashableTuple<BarBeatTime, MIDINodeRef>> = []

  unowned let track: InstrumentTrack

  var color: TrackColor { return track.color }

  var recording: Bool { return Sequencer.mode == .loop && MIDIPlayer.currentDispatch === self }

  var nextNodeName: String { return "\(name) \(nodes.count + 1)" }

  var name: String { return "\(track.displayName) (\(identifier.uuidString))" }
  
  func connect(node: MIDINode) throws { try track.connect(node: node) }

  func disconnect(node: MIDINode) throws { try track.disconnect(node: node) }

  /// 'Marker' meta event in the following format:<br>
  ///      `start(`*identifier*`):`*repetitions*`:`*repeatDelay*
  var beginLoopEvent: AnyMIDIEvent {
    return .meta(MetaEvent(.marker(name: "start(\(identifier.uuidString)):\(repetitions):\(repeatDelay)")))
  }

  /// 'Marker' meta event in the following format:<br>
  ///      `end(`*identifier*`)`
  var endLoopEvent: AnyMIDIEvent {
    return .meta(MetaEvent(.marker(name: "end(\(identifier.uuidString))")))
  }

  init(track: InstrumentTrack) {
    self.track = track
    identifier = UUID()
    eventContainer = MIDIEventContainer()
  }

  init(grooveLoop: GrooveLoop, track: InstrumentTrack) {
    self.track = track
    identifier = grooveLoop.identifier
    repetitions = grooveLoop.repetitions
    repeatDelay = grooveLoop.repeatDelay
    start = grooveLoop.start
    var events: [AnyMIDIEvent] = []
    for node in grooveLoop.nodes.values {
      events.append(.node(node.addEvent))
      if let removeEvent = node.removeEvent {
        events.append(.node(removeEvent))
      }
    }

    self.eventContainer = MIDIEventContainer(events: events)
    nodeManager = MIDINodeManager(owner: self)
  }

  func registrationTimes<S:Swift.Sequence>(forAdding events: S) -> [BarBeatTime]
    where S.Iterator.Element == AnyMIDIEvent
  {
    return events.filter({ if case .node(_) = $0 { return true } else { return false } }).map({$0.time})
  }

  func dispatch(event: AnyMIDIEvent) {
    guard case .node(let nodeEvent) = event else { return }
      switch nodeEvent.data {
        case let .add(identifier, trajectory, generator):
          nodeManager.addNodeWithIdentifier(identifier.nodeIdentifier, trajectory: trajectory, generator: generator)
        case let .remove(identifier):
          do { try nodeManager.removeNodeWithIdentifier(identifier.nodeIdentifier, delete: false) } catch { logError(error) }
      }
  }

  func makeIterator() -> AnyIterator<AnyMIDIEvent> {
    var startEventInserted = false
    var endEventInserted = false
    var iteration = 0
    var offset: UInt64 = 0
    var currentGenerator = eventContainer.makeIterator()
    return AnyIterator {
      [
        startTicks = start.ticks,
        repeatCount = repetitions,
        totalTicks = time.ticks,
        delay = repeatDelay,
        beginEvent = beginLoopEvent,
        endEvent = endLoopEvent
      ]
      () -> AnyMIDIEvent? in

      if !startEventInserted {
        startEventInserted = true
        var event = beginEvent
        event.time = BarBeatTime(tickValue: startTicks)
        return event
      } else if var event = currentGenerator.next() {
        event.time = BarBeatTime(tickValue: startTicks + event.time.ticks + offset)
        return event
      } else if repeatCount >= {let i = iteration; iteration += 1; return i}() || repeatCount < 0 {
        offset += delay + totalTicks
        currentGenerator = self.eventContainer.makeIterator()
        if var event = currentGenerator.next() {
          event.time = BarBeatTime(tickValue: startTicks + event.time.ticks + offset)
          return event
        } else if !endEventInserted {
          endEventInserted = true
          var event = endEvent
          event.time = BarBeatTime(tickValue: startTicks + event.time.ticks + offset)
          return event
        } else {
          return nil
        }
      } else if !endEventInserted {
        endEventInserted = true
        var event = endEvent
        event.time = BarBeatTime(tickValue: startTicks + event.time.ticks + offset)
        return event
      } else {
        return nil
      }
    }
  }

}

extension Loop: CustomStringConvertible {

  var description: String {
    return "\n".join(
      "time: \(time)",
      "repetitions: \(repetitions)",
      "repeatDelay: \(repeatDelay)",
      "start: \(start)",
      "end: \(end)",
      "identifier: \(identifier)",
      "color: \(color)",
      "recording: \(recording)",
      "name: \(name)",
      "nodes: \(nodes)",
      "events: \(eventContainer)"
    )
  }
  
}
