//
//  MIDINodeDispatch.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 1/13/16.
//  Copyright © 2016 Moondeer Studios. All rights reserved.
//

import Foundation
import MoonKit

/// Typealias for a weak `MIDINode` instance.
typealias MIDINodeRef = Weak<MIDINode>

/// Protocol for the common properties and methods of objects that generate `MIDINode` instances.
protocol MIDINodeDispatch: class, MIDIEventDispatch, Named {

  /// Name to assign to the next node dispatched.
  var nextNodeName: String { get }

  /// The color associated with the dispatching instance.
  var color: TrackColor { get }

  /// The node manager for the dispatching instance.
  var nodeManager: MIDINodeManager! { get }

  /// Makes the necessary connections for dispatching `node`.
  /// - Throws: `MIDINodeDispatchError.NodeAlreadyConnected` or any error encountered making connections.
  func connect(node: MIDINode) throws

  /// Disconnects resources tied to `node`.
  /// - Throws: `MIDINodeDispatch.NodeNotFound` or any error encountered disconnecting.
  func disconnect(node: MIDINode) throws

  /// Flag indicating whether events generated by dispatched nodes should be recorded.
  var isRecording: Bool { get }

}

/// Enumeration of errors thrown by `MIDINodeDispatch` methods.
enum MIDINodeDispatchError: String, Swift.Error, CustomStringConvertible {
  case NodeNotFound = "The specified node was not found among the nodes of the dispatch source."
  case NodeAlreadyConnected = "The specified node has already been connected."
}
