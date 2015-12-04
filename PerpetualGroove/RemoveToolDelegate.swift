//
//  RemoveToolDelegate.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 12/1/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import UIKit
import SpriteKit
import MoonKit

final class RemoveToolDelegate: MIDIPlayerNodeDelegate {

  unowned let player: MIDIPlayerNode

  var active = false {
    didSet {
      guard active != oldValue else { return }
      switch active {
        case true:
          sequence = MIDIDocumentManager.currentDocument?.sequence
          refreshAllNodeLighting()
        case false:
          sequence = nil
          player.midiNodes.forEach { removeLightingFromNode($0) }
      }
    }
  }

  private typealias NodeRef = Weak<MIDINode>

  private var touch: UITouch? { didSet { if touch == nil { nodesToRemove.removeAll() } } }
  private var nodesToRemove: Set<NodeRef> = [] {
    didSet {
      nodesToRemove.flatMap({$0.reference}).forEach {
        guard let light = $0.childNodeWithName("removeToolLighting") as? SKLightNode
                where light.categoryBitMask != 1 else { return }
        light.lightColor = .blackColor()
      }
    }
  }

  private static var categoryShift: UInt32 = 1 {
    didSet { categoryShift = (1 ... 31).clampValue(categoryShift) }
  }
  private static var foregroundLightNode: SKLightNode  {
    let node = SKLightNode()
    node.name = lightNodeName
    node.categoryBitMask = 1 << categoryShift++
    node.lightColor = foregroundLightColor
    node.falloff = 1
    return node
  }

  private static let lightNodeName = "removeToolLighting"
  private static let foregroundLightColor = UIColor.whiteColor()
  private static let backgroundLightColor = UIColor.clearColor()

  private static var backgroundLightNode: SKLightNode {
    let node = SKLightNode()
    node.name = lightNodeName
    node.categoryBitMask = 1
    node.lightColor = backgroundLightColor
    return node
  }

  private weak var sequence: Sequence? {
    didSet {
      guard oldValue !== sequence else { return }
      if let oldSequence = oldValue {
        receptionist.stopObserving(Sequence.Notification.DidChangeTrack, from: oldSequence)
      }
      if let sequence = sequence {
        receptionist.observe(Sequence.Notification.DidChangeTrack,
          from: sequence,
          callback: {[weak self] _ in self?.track = self?.sequence?.currentTrack})
      }
      track = sequence?.currentTrack
    }
  }

  /**
   lightNodeForBackground:

   - parameter node: MIDINode
  */
  private func lightNodeForBackground(node: MIDINode) {
    let lightNode: SKLightNode
    switch node.childNodeWithName("removeToolLighting") as? SKLightNode {
      case let light? where light.categoryBitMask != 1:
        light.categoryBitMask = 1
        light.lightColor = RemoveToolDelegate.backgroundLightColor
        lightNode = light
      case nil:
        lightNode = RemoveToolDelegate.backgroundLightNode
        node.addChild(lightNode)
      default:
        return
    }

    node.lightingBitMask = lightNode.categoryBitMask
  }

  /**
   lightNodeForForeground:

   - parameter node: MIDINode
  */
  private func lightNodeForForeground(node: MIDINode) {
    let lightNode: SKLightNode
    switch node.childNodeWithName("removeToolLighting") as? SKLightNode {
      case let light? where light.categoryBitMask == 1:
        light.categoryBitMask = 1 << RemoveToolDelegate.categoryShift++
        light.lightColor = RemoveToolDelegate.foregroundLightColor
        lightNode = light
      case nil:
        lightNode = RemoveToolDelegate.foregroundLightNode
        node.addChild(lightNode)
      default:
        return
    }

    node.lightingBitMask = lightNode.categoryBitMask
  }

  /** refreshAllNodeLighting */
  private func refreshAllNodeLighting() {
    guard let track = track else { return }
    let trackNodes = track.nodes.flatMap({$0.reference})
    let (foregroundNodes, backgroundNodes) = player.midiNodes.bisect { trackNodes ∋ $0 }
    foregroundNodes.forEach { lightNodeForForeground($0) }
    backgroundNodes.forEach { lightNodeForBackground($0) }
  }

  /**
   removeLightingFromNode:

   - parameter node: MIDINode
  */
  private func removeLightingFromNode(node: MIDINode) {
    node.childNodeWithName("removeToolLighting")?.removeFromParent()
    node.lightingBitMask = 0
  }

  private weak var track: InstrumentTrack? {
    didSet {
      if touch != nil { touch = nil }
      guard active && oldValue !== track else { return }
      oldValue?.nodes.flatMap({$0.reference}).forEach { lightNodeForBackground($0) }
      track?.nodes.flatMap({$0.reference}).forEach { lightNodeForForeground($0) }
    }
  }

  /**
   initWithPlayerNode:

   - parameter playerNode: MIDIPlayerNode
   */
  init(playerNode: MIDIPlayerNode) {
    player = playerNode
    receptionist.observe(MIDIDocumentManager.Notification.DidChangeDocument,
      from: MIDIDocumentManager.self,
      callback: {[weak self] _ in self?.sequence = MIDIDocumentManager.currentDocument?.sequence})
    receptionist.observe(MIDIPlayerNode.Notification.DidAddNode,
      from: playerNode,
      callback: {[weak self] notification in
        guard let node = notification.addedNode, track = notification.addedNodeTrack else { return }
        if self?.track === track { self?.lightNodeForForeground(node) }
        else { self?.lightNodeForBackground(node) }
      })
  }

  /** removeMarkedNodes */
  private func removeMarkedNodes() {
    do {
      for node in nodesToRemove.flatMap({$0.reference}) {
        try track?.removeNode(node)
        node.fadeOut(remove: true)
      }
    } catch {
      logError(error)
    }
  }

  private let receptionist: NotificationReceptionist = {
    let receptionist = NotificationReceptionist(callbackQueue: NSOperationQueue.mainQueue())
    receptionist.logContext = LogManager.MIDIFileContext
    return receptionist
  }()

  /**
  trackNodesAtPoint:

  - parameter point: CGPoint

  - returns: [Weak<MIDINode>]
  */
  private func trackNodesAtPoint(point: CGPoint) -> [NodeRef] {
    let midiNodes = player.nodesAtPoint(point).flatMap({$0 as? MIDINode}).map({NodeRef($0)})
    return midiNodes.filter({track?.nodes.contains($0) == true})
  }

  /**
  touchesBegan:withEvent:

  - parameter touches: Set<UITouch>
  - parameter event: UIEvent?
  */
  func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
    guard active && self.touch == nil else { return }
    touch = touches.first
    guard let point = touch?.locationInNode(player) where player.containsPoint(point) else { return }
    nodesToRemove ∪= trackNodesAtPoint(point)
  }

  /**
  touchesCancelled:withEvent:

  - parameter touches: Set<UITouch>?
  - parameter event: UIEvent?
  */
  func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) { touch = nil }

  /**
  touchesEnded:withEvent:

  - parameter touches: Set<UITouch>
  - parameter event: UIEvent?
  */
  func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
    guard touch != nil && touches.contains(touch!) else { return }
    removeMarkedNodes()
    touch = nil
  }

  /**
  touchesMoved:withEvent:

  - parameter touches: Set<UITouch>
  - parameter event: UIEvent?
  */
  func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
    guard touch != nil && touches.contains(touch!) else { return }
    guard let point = touch?.locationInNode(player) where player.containsPoint(point) else {
      touch = nil
      return
    }
    nodesToRemove ∪= trackNodesAtPoint(point)
  }

}
