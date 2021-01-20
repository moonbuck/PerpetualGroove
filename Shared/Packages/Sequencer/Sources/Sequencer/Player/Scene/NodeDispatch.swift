//
//  NodeDispatch.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 1/13/16.
//  Copyright © 2016 Moondeer Studios. All rights reserved.
//
import Foundation
import MoonDev
import MIDI
import Common

/// Typealias for a weak `Node` instance.
@available(iOS 14.0, *)
public typealias NodeRef = Weak<MIDINode>

/// Protocol for the common properties and methods of types that generate
/// or manipulate `Node` instances.
@available(iOS 14.0, *)
public protocol NodeDispatch: EventDispatch, Named {

  /// Name to assign to the next node dispatched.
  var nextNodeName: String { get }

  /// The color associated with the dispatching instance.
  var color: Track.Color { get }

  /// The node manager for the dispatching instance.
  var nodeManager: NodeManager { get }

  /// Makes the necessary connections for the dispatching `node`.
  /// - Throws: `NodeDispatchError.nodeAlreadyConnected` or any error encountered 
  ///           making connections.
  func connect(node: MIDINode) throws

  /// Disconnects resources tied to `node`.
  /// - Throws: `NodeDispatch.nodeNotFound` or any error encountered disconnecting.
  func disconnect(node: MIDINode) throws

  /// Flag indicating whether events generated by dispatched nodes should be recorded.
  var isRecording: Bool { get }

}

@available(iOS 14.0, *)
extension NodeDispatch {

  public var nodes: [MIDINode] { nodeManager.nodes.compactMap(\.reference) }

}

/// Enumeration of errors thrown by `NodeDispatch` methods.
public enum NodeDispatchError: String, Swift.Error, CustomStringConvertible {
  case nodeNotFound = "The specified node was not found."
  case nodeAlreadyConnected = "The specified node has already been connected."

  public var description: String { rawValue }
}
