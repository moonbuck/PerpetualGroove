//
//  MIDINodeManager.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 2/4/16.
//  Copyright © 2016 Moondeer Studios. All rights reserved.
//

import Foundation
import MoonKit

/// Class for managing a collection of `MIDINode` instances for an owning `MIDINodeDispatch` object.
final class MIDINodeManager {

  /// The type for an event adding or removing a `MIDINode`.
  private typealias Event = MIDIEvent.MIDINodeEvent

  /// The object responsible for the manager.
  unowned let owner: MIDINodeDispatch

  /// Default initializer.
  init(owner: MIDINodeDispatch) { self.owner = owner }

  /// The set of nodes currently being managed.
  private(set) var nodes: OrderedSet<MIDINodeRef> = []

  /// Set of node identifiers awaiting callback with a `MIDINode` instance.
  private var pendingNodes: Set<UUID> = []

  /// Fades out all the elements in `nodes`, optionally removing them from the player.
  func stopNodes(remove: Bool = false) {

    for nodeRef in nodes { nodeRef.reference?.fadeOut(remove: remove) }

    Log.debug("nodes stopped\(remove ? " and removed" : "")")

  }

  /// Fades in all the elements in `nodes`.
  func startNodes() {

    for nodeRef in nodes { nodeRef.reference?.fadeIn() }

    Log.debug("nodes started")

  }

  /// appends a reference for `node` to `nodes` and generates a `MIDINodeEvent` for the addition.
  /// - Throws: Any error encountered connecting `node`.
  func add(node: MIDINode) throws {

    // Connect the node.
    try owner.connect(node: node)

    // Generate and append the node event on the owner's event queue.
    owner.eventQueue.async {
      [time = Time.current.barBeatTime, unowned node, weak self] in

      let identifier = Event.Identifier(nodeIdentifier: node.identifier)
      let data = Event.Data.add(identifier: identifier,
                                trajectory: node.path.initialTrajectory,
                                generator: node.generator)
      self?.owner.add(event: .node(Event(data: data, time: time)))
    }

    // Insert the node into our set
    nodes.append(MIDINodeRef(node))

    // Remove the identifier from `pendingNodes`.
    pendingNodes.remove(node.identifier)

    Log.debug("adding node \(node.name!) (\(node.identifier))")

  }

  /// Places or removes a `MIDINode` according to `event`.
  func handle(event: MIDIEvent.MIDINodeEvent) {

    switch event.data {

      case let .add(eventIdentifier, trajectory, generator):
        // Add a node with using the specified data.

        let identifier = eventIdentifier.nodeIdentifier

        Log.debug(", ".join("placing node with identifier \(identifier)",
          "trajectory \(trajectory)",
          "generator \(generator)"))

        // Make sure a node hasn't already been place for this identifier
        guard nodes.first(where: {$0.reference?.identifier == identifier}) == nil
          && pendingNodes ∌ identifier
          else
        {
          fatalError("The identifier is pending or already placed.")
        }

        pendingNodes.insert(identifier)

        // Place a node
        MIDINodePlayer.placeNew(trajectory, target: owner, generator: generator, identifier: identifier)

      case let .remove(eventIdentifier):
        // Remove the node matching `eventIdentifier`.

        let identifier = eventIdentifier.nodeIdentifier

        Log.debug("removing node with identifier \(identifier)")

        guard let idx = nodes.index(where: {$0.reference?.identifier == identifier}),
              let node = nodes[idx].reference else
        {
          fatalError("failed to find node with mapped identifier \(identifier)")
        }

        do {
          try remove(node: node)
        } catch {
          Log.error(error)
        }

        MIDINodePlayer.remove(node: node)

    }

  }

  /// Remove `node` from the player generating a node removal event and leaving any events
  /// generated by `node`.
  func remove(node: MIDINode) throws { try remove(node: node, delete: false) }

  /// Remove `node` from the player deleting any events generated by `node`.
  func delete(node: MIDINode) throws { try remove(node: node, delete: true) }

  /// Performs the actual removal of `node` according to the value of `delete`.
  private func remove(node: MIDINode, delete: Bool) throws {

    // Check that `node` is actually an element of `nodes`.
    guard let idx = nodes.index(where: {$0.reference === node}),
          let node = nodes.remove(at: idx).reference
      else
    {
        throw MIDINodeDispatchError.NodeNotFound
    }

    Log.debug("removing node \(node.name!) \(node.identifier)")

    //TODO: make sure disabling the line below doesn't lead to hanging notes.
//    node.sendNoteOff()

    // Disconnect the node.
    try owner.disconnect(node: node)

    // Handle event creation/deletion according to the value of `delete`.
    switch delete {

      case true:
        // Remove any events generated by the node from the owner's event container.

        owner.eventQueue.async {
          [identifier = node.identifier, weak self] in

          self?.owner.eventContainer.removeEvents {
            if case .node(let event) = $0, event.identifier.nodeIdentifier == identifier {
              return true
            } else {
              return false
            }
          }

        }

      case false:
        // Generate an event for removing the node.

        owner.eventQueue.async {
          [time = Time.current.barBeatTime, identifier = node.identifier, weak self] in

          let eventIdentifier = Event.Identifier(nodeIdentifier: identifier)
          self?.owner.add(event: .node(Event(data: .remove(identifier: eventIdentifier), time: time)))

        }

    }

  }

}
