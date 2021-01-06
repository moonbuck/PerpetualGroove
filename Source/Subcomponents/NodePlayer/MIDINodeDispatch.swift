//
//  MIDINodeDispatch.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 1/13/16.
//  Copyright © 2016 Moondeer Studios. All rights reserved.
//
import Foundation
import MoonKit
import MIDI
import Common

/// Typealias for a weak `MIDINode` instance.
public typealias MIDINodeRef = Weak<MIDINode>

/// Protocol for the common properties and methods of objects that generate `MIDINode` 
/// instances.
public protocol MIDINodeDispatch: MIDIEventDispatch, Named {

  /// Name to assign to the next node dispatched.
  var nextNodeName: String { get }

  /// The color associated with the dispatching instance.
  var color: TrackColor { get }

  /// The node manager for the dispatching instance.
  var nodeManager: MIDINodeManager { get }

  /// Makes the necessary connections for the dispatching `node`.
  /// - Throws: `MIDINodeDispatchError.nodeAlreadyConnected` or any error encountered 
  ///           making connections.
  func connect(node: MIDINode) throws

  /// Disconnects resources tied to `node`.
  /// - Throws: `MIDINodeDispatch.nodeNotFound` or any error encountered disconnecting.
  func disconnect(node: MIDINode) throws

  /// Flag indicating whether events generated by dispatched nodes should be recorded.
  var isRecording: Bool { get }

}

extension MIDINodeDispatch {

  public var nodes: [MIDINode] { return nodeManager.nodes.compactMap({$0.reference}) }

}

/// Enumeration of errors thrown by `MIDINodeDispatch` methods.
public enum MIDINodeDispatchError: String, Swift.Error, CustomStringConvertible {
  case nodeNotFound = "The specified node was not found."
  case nodeAlreadyConnected = "The specified node has already been connected."

  public var description: String { rawValue }
}
