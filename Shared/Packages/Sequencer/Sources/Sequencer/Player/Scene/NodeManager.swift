//
//  NodeManager.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 2/4/16.
//  Copyright © 2016 Moondeer Studios. All rights reserved.
//
import Foundation
import MIDI
import MoonDev

/// Class for managing a collection of `Node` instances.
@available(iOS 14.0, *)
public final class NodeManager
{
  /// The node dispatching object owning the nodes being managed.
  public unowned let owner: NodeDispatch

  /// Default initializer.
  public init(owner: NodeDispatch) { self.owner = owner }

  /// The set of nodes currently being managed.
  public private(set) var nodes: OrderedSet<NodeRef> = []

  /// Set of node identifiers awaiting callback with a `Node` instance.
  private var pendingNodes: Set<UUID> = []

  /// Fades out all the elements in `nodes`, optionally removing them from the player.
  public func stopNodes(remove: Bool = false)
  {
    for nodeRef in nodes { nodeRef.reference?.fadeOut(remove: remove) }

    logi("nodes stopped\(remove ? " and removed" : "")")
  }

  /// Fades in all the elements in `nodes`.
  public func startNodes()
  {
    for nodeRef in nodes { nodeRef.reference?.fadeIn() }

    logi("nodes started")
  }

  /// appends a reference for `node` to `nodes` and generates a `NodeEvent` for the
  /// addition.
  /// - Throws: Any error encountered connecting `node`.
  public func add(node: MIDINode) throws
  {
    // Connect the node.
    try owner.connect(node: node)

    // Generate and append the node event on the owner's event queue.
    owner.eventQueue.async
    {
      [time = time.barBeatTime, unowned node, weak self] in

      let identifier = NodeEvent.Identifier(nodeIdentifier: node.identifier)
      let data = NodeEvent.Data.add(identifier: identifier,
                                    trajectory: node.path.initialTrajectory,
                                    generator: node.generator)
      self?.owner.add(event: .node(NodeEvent(data: data, time: time)))
    }

    // Insert the node into our set
    nodes.append(NodeRef(node))

    // Remove the identifier from `pendingNodes`.
    pendingNodes.remove(node.identifier)

    logi("adding node \(node.name!) (\(node.identifier))")
  }

  /// Places or removes a `Node` according to `event`.
  public func handle(event: NodeEvent)
  {
    switch event.data
    {
      case let .add(eventIdentifier, trajectory, generator):
        // Add a node with using the specified data.

        let identifier = eventIdentifier.nodeIdentifier

        logi("""
        placing node with identifier \(identifier), \
        trajectory \(trajectory), \
        generator \(String(describing: generator))
        """)

        // Make sure a node hasn't already been place for this identifier
        guard nodes.first(where: { $0.reference?.identifier == identifier }) == nil,
              pendingNodes ∌ identifier
        else
        {
          fatalError("The identifier is pending or already placed.")
        }

        pendingNodes.insert(identifier)

        // Place a node
        player.placeNew(trajectory,
                        target: owner,
                        generator: generator,
                        identifier: identifier)

      case let .remove(eventIdentifier):
        // Remove the node matching `eventIdentifier`.

        let identifier = eventIdentifier.nodeIdentifier

        logi("removing node with identifier \(identifier)")

        guard let idx = nodes
                .firstIndex(where: { $0.reference?.identifier == identifier }),
              let node = nodes[idx].reference
        else
        {
          fatalError("failed to find node with mapped identifier \(identifier)")
        }

        do
        {
          try remove(node: node)
        }
        catch
        {
          loge("\(error as NSObject)")
        }

        player.remove(node: node)
    }
  }

  /// Remove `node` from the player generating a node removal event and leaving any events
  /// generated by `node`.
  public func remove(node: MIDINode) throws { try remove(node: node, delete: false) }

  /// Remove `node` from the player deleting any events generated by `node`.
  public func delete(node: MIDINode) throws { try remove(node: node, delete: true) }

  /// Performs the actual removal of `node` according to the value of `delete`.
  private func remove(node: MIDINode, delete: Bool) throws
  {
    // Check that `node` is actually an element of `nodes`.
    guard let idx = nodes.firstIndex(where: { $0.reference === node }),
          let node = nodes.remove(at: idx).reference
    else
    {
      throw NodeDispatchError.nodeNotFound
    }

    logi("removing node \(node.name!) \(node.identifier)")

    // TODO: make sure disabling the line below doesn't lead to hanging notes.
    //    node.sendNoteOff()

    // Disconnect the node.
    try owner.disconnect(node: node)

    // Handle event creation/deletion according to the value of `delete`.
    switch delete
    {
      case true:
        // Remove any events generated by the node from the owner's event container.

        owner.eventQueue.async
        {
          [identifier = node.identifier, weak self] in

          self?.owner.eventContainer.removeEvents
          {
            if case let .node(event) = $0, event.identifier.nodeIdentifier == identifier
            {
              return true
            }
            else
            {
              return false
            }
          }
        }

      case false:
        // Generate an event for removing the node.

        owner.eventQueue.async
        {
          [time = time.barBeatTime, identifier = node.identifier, weak self] in

          let eventIdentifier = NodeEvent.Identifier(nodeIdentifier: identifier)
          self?.owner.add(event:
                            .node(NodeEvent(data: .remove(identifier: eventIdentifier),
                                            time: time)))
        }
    }
  }
}
