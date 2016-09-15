//
//  MIDIPlayer.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 12/5/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import Foundation
import UIKit
import SpriteKit
import MoonKit

final class MIDIPlayer {

  static let undoManager: UndoManager = {
    let undoManager = UndoManager()
    undoManager.groupsByEvent = false
    return undoManager
  }()

  fileprivate static let receptionist: NotificationReceptionist = {
    let receptionist = NotificationReceptionist()
    receptionist.logContext = LogManager.SceneContext
    receptionist.observe(notification: .DidChangeSequence,
                    from: Sequencer.self,
                callback: MIDIPlayer.didChangeSequence)
      receptionist.observe(notification: .DidEnterLoopMode,
                      from: Sequencer.self,
                  callback: MIDIPlayer.didEnterLoopMode)
      receptionist.observe(notification: .DidExitLoopMode,
                      from: Sequencer.self,
                  callback: MIDIPlayer.didExitLoopMode)
      receptionist.observe(notification: .WillEnterLoopMode,
                      from: Sequencer.self,
                  callback: MIDIPlayer.willEnterLoopMode)
      receptionist.observe(notification: .WillExitLoopMode,
                      from: Sequencer.self,
                  callback: MIDIPlayer.willExitLoopMode)
    return receptionist
  }()

  static weak var currentDispatch: MIDINodeDispatch? {
    didSet {
      guard currentDispatch !== oldValue else { return }
      logDebug("\(oldValue?.name ?? "nil") ➞ \(currentDispatch?.name ?? "nil")")
    }
  }

  /** updateCurrentDispatch */
  static fileprivate func updateCurrentDispatch() {
    guard let track = Sequencer.sequence?.currentTrack else { currentDispatch = nil; return }
    switch Sequencer.mode {
      case .Default: currentDispatch = track
      case .Loop:
        if let loop = loops[ObjectIdentifier(track)] { currentDispatch = loop }
        else {
          let loop = Loop(track: track)
          loops[ObjectIdentifier(track)] = loop
          currentDispatch = loop
        }
    }
  }

  fileprivate(set) static var initialized = false

  fileprivate static weak var sequence: Sequence? {
    didSet {
      guard sequence !== oldValue else { return }
      if let oldSequence = oldValue { receptionist.stopObserving(object: oldSequence) }
      if let sequence = sequence {
        receptionist.observe(notification: .DidRemoveTrack, from: sequence, callback: MIDIPlayer.didRemoveTrack)
        receptionist.observe(notification: .DidChangeTrack, from: sequence, callback: MIDIPlayer.didChangeTrack)
      }
      updateCurrentDispatch()
    }
  }

  /** initialize */
  static func initialize() {
    guard !initialized else { return }
    touch(receptionist); initialized = true
  }

  /**
   didChangeSequence:

   - parameter notification: NSNotification
  */
  static fileprivate func didChangeSequence(_ notification: Foundation.Notification) { sequence = Sequencer.sequence }

  /**
   didRemoveTrack:

   - parameter notification: NSNotification
  */
  static fileprivate func didRemoveTrack(_ notification: Foundation.Notification) {
    guard let track = notification.removedTrack else { return }
    loops[ObjectIdentifier(track)] = nil
    updateCurrentDispatch()
  }

  /**
   didChangeTrack:

   - parameter notification: NSNotification
   */
  static fileprivate func didChangeTrack(_ notification: Foundation.Notification) { updateCurrentDispatch() }
  
  /**
   willEnterLoopMode:

   - parameter notification: NSNotification
   */
  static fileprivate func willEnterLoopMode(_ notification: Foundation.Notification) {
    playerNode?.defaultNodes.forEach { $0.fadeOut() }
  }

  /**
   didEnterLoopMode:

   - parameter notification: NSNotification
   */
  static fileprivate func didEnterLoopMode(_ notification: Foundation.Notification) {
    loops.removeAll()
    updateCurrentDispatch()
  }

  /**
   willExitLoopMode:

   - parameter notification: NSNotification
   */
  static fileprivate func willExitLoopMode(_ notification: Foundation.Notification) {
    playerNode?.loopNodes.forEach { $0.fadeOut(remove: true) }
  }

  /**
   didExitLoopMode:

   - parameter notification: NSNotification
  */
  static fileprivate func didExitLoopMode(_ notification: Foundation.Notification) {
    playerNode?.defaultNodes.forEach { $0.fadeIn() }
    insertLoops()
    resetLoops()
    updateCurrentDispatch()
  }

  static var shouldInsertLoops = false

  static fileprivate func insertLoops() {
    logDebug("inserting loops: \(loops)")
    let startTime = Sequencer.time.barBeatTime + loopStart
    let endTime = Sequencer.time.barBeatTime + loopEnd
    for loop in loops.values where !loop.events.isEmpty {
      loop.start = startTime
      loop.end = endTime
      loop.track.addLoop(loop)
    }
  }

  /** resetLoops */
  static fileprivate func resetLoops() {
    loops.removeAll()
    loopStart = .start1
    loopEnd = .start1
    shouldInsertLoops = false
  }

  static weak var playerContainer: MIDIPlayerContainerViewController?
  
  static weak var playerNode: MIDIPlayerNode? {
    didSet {
      guard let node = playerNode else { return }
      addTool = AddTool(playerNode: node)
      removeTool = RemoveTool(playerNode: node, delete: false)
      deleteTool = RemoveTool(playerNode: node, delete: true)
      existingGeneratorTool = GeneratorTool(playerNode: node, mode: .existing)
      newGeneratorTool = GeneratorTool(playerNode: node, mode: .new)
      rotateTool = RotateTool(playerNode: node)
      currentTool = .none
    }
  }

  static fileprivate(set) var addTool: AddTool?
  static fileprivate(set) var removeTool: RemoveTool?
  static fileprivate(set) var deleteTool: RemoveTool?
  static fileprivate(set) var existingGeneratorTool: GeneratorTool?
  static fileprivate(set) var newGeneratorTool: GeneratorTool?
  static fileprivate(set) var rotateTool: RotateTool?

  static var currentTool: Tool = .none {
    willSet {
      logDebug("willSet: \(currentTool) ➞ \(newValue)")
      guard currentTool != newValue else { return }
      if undoManager.groupingLevel > 0 { undoManager.endUndoGrouping() }
      guard currentTool.toolType?.isShowingContent == true else { return }
      playerContainer?.dismissSecondaryController()
    }
    didSet {
      logDebug("didSet: \(oldValue) ➞ \(currentTool)")
      guard currentTool != oldValue else { return }
      if currentTool != .none { undoManager.beginUndoGrouping() }
      oldValue.toolType?.active = false
      currentTool.toolType?.active = true
      playerNode?.touchReceiver = currentTool.toolType
      Notification.DidSelectTool.post(userInfo: [.SelectedTool: currentTool.rawValue as Optional<AnyObject>])
    }
  }

  static fileprivate var loops: [ObjectIdentifier:Loop] = [:]

  static var loopStart: BarBeatTime = .start1
  static var loopEnd: BarBeatTime = .start1

  /**
   placeNew:targetTrack:generator:

   - parameter trajectory: Trajectory
   - parameter targetTrack: InstrumentTrack? = nil
   - parameter generator: MIDIGenerator
  */
  static func placeNew(_ trajectory: Trajectory,
                target: MIDINodeDispatch,
             generator: MIDIGenerator,
            identifier: MIDINode.Identifier = UUID())
  {
    dispatchToMain {
      guard let playerNode = playerNode else {
        logWarning("cannot place a node without a player node")
        return
      }

      do {
        let name = "<\(Sequencer.mode.rawValue)> \(target.nextNodeName)"
        let node = try MIDINode(trajectory: trajectory,
                                    name: name,
                                    dispatch: target,
                                    generator: generator,
                                    identifier: identifier)
        playerNode.addChild(node)

        try target.nodeManager.addNode(node)


        if !Sequencer.playing { Sequencer.play() }
        Notification.DidAddNode.post(userInfo: [.AddedNode: node, .AddedNodeTrack: target])
        logDebug("added node \(name)")

      } catch {
        logError(error)
      }
    }
  }

  /**
   removeNode:

   - parameter node: MIDINode
  */
  static func removeNode(_ node: MIDINode) {
    dispatchToMain {
      guard node.parent === playerNode else { return }
      node.fadeOut(remove: true)
      Notification.DidRemoveNode.post()
    }
  }

}

// MARK: - Notification
extension MIDIPlayer: NotificationDispatchType {

  /** An enumeration to wrap up notifications */
  enum Notification: String, NotificationType, NotificationNameType {
    case DidAddNode, DidRemoveNode, DidSelectTool
    var object: AnyObject? { return MIDIPlayer.self }
    enum Key: String, NotificationKeyType { case AddedNode, AddedNodeTrack, SelectedTool }
  }

}

extension Notification {
  var addedNode: MIDINode? {
    return userInfo?[MIDIPlayer.Notification.Key.AddedNode.key] as? MIDINode
  }
  var addedNodeTrack: InstrumentTrack? {
    return userInfo?[MIDIPlayer.Notification.Key.AddedNodeTrack.key] as? InstrumentTrack
  }
  var selectedTool: Tool? {
    guard let rawValue = userInfo?[MIDIPlayer.Notification.Key.SelectedTool.key] as? Int else {
      return nil
    }
    return Tool(rawValue)
  }
}
