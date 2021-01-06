//
//  InstrumentTrack.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 8/14/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//
import Common
import CoreMIDI
import Foundation
import MIDI
import MoonKit
import NodePlayer
import SoundFont

// MARK: - InstrumentTrack

/// A subclass of `Track` containing MIDI events for adding/removing MIDI nodes as well as
/// MIDI events for configuring the sound used for note events generated by those MIDI
/// nodes.
public final class InstrumentTrack: Sequencer.Track, NodeDispatch {
  // MARK: Stored Properties

  /// A manager for the MIDI nodes dispatched by the track.
  public private(set) lazy var nodeManager = NodeManager(owner: self)

  /// The MIDI event that specifies the instrument used by the track.
  private var instrumentEvent: MetaEvent!

  /// The MIDI event that specifies the program used by the track.
  private var programEvent: ChannelEvent!

  /// Handles registration/reception for various notifications from the track's instrument
  /// and the current transport.
  ///
  /// - TODO: Shouldn't we be more specific on which transport is observed?
  private let receptionist = NotificationReceptionist(callbackQueue: OperationQueue.main)

  /// The instrument used by the track.
  public private(set) var instrument: Instrument {
    didSet {
      $volume = instrument
      $pan = instrument
    }
  }

  /// The color used for this track.
  public var color: TrackColor = .muddyWaters

  /// Flag indicating whether the track is in a muted state, whether from a user request or
  /// as the result of another track being soloed. Changing the value of this property
  /// triggers a `muteStatusDidChange` notification to be posted for the track. When set to
  /// `true`, the current value of `volume` is cached and `volume` is set to `0`. When set
  /// to `false`, the cached value is restored. The default value of this property is
  /// `false`.
  public private(set) var isMuted = false {
    didSet {
      // Check that the value has actually changed.
      guard isMuted != oldValue else { return }

      // Swap the values of `volume` and `cachedVolume`.
      swap(&volume, &cachedVolume)

      // Post notification that the track's mute status has changed.
      postNotification(name: .muteStatusDidChange, object: self)
    }
  }

  /// Flag indicating whether the track should be silenced because one or more of the other
  /// tracks in the sequence are soloing. Changing the value of this property triggers the
  /// track to post a `forceMuteStatusDidChange` notification and to update the value of
  /// it's `isMuted` flag. The default value of this property is `false`.
  public var forceMute = false {
    didSet {
      // Check that the value has actually changed.
      guard forceMute != oldValue else { return }

      // Post notification that the value of the track's `forceMute` flag has changed.
      postNotification(name: .forceMuteStatusDidChange, object: self)

      // Update the `isMuted` flag given the new value for `forceMute`.
      updateIsMuted()
    }
  }

  /// Flag indicating whether the track has been muted through user request. Changing the
  /// value of this property causes the track to update it's `isMuted` flag. The default
  /// value of this property is `false`.
  public var mute = false {
    didSet {
      // Check that the value has actually changed.
      guard mute != oldValue else { return }

      // Update the value of `isMuted` given the new value for `mute`.
      updateIsMuted()
    }
  }

  /// Flag indicating whether the track has been added to the group of tracks selected to
  /// generate audio output. Whether the track generates output is determined by the
  /// following rules:
  /// 1. A track with a `solo` value of `true` always generates output.
  /// 2. As long as there is at least one track with a `solo` value of `true`, any track
  ///    with a `solo` value of `false` does not generate output.
  /// 3. When there are not any tracks with a `solo` value of `true`, whether or not a
  ///    track generates output is determined by the value of their `mute` property.
  /// Changes to the value of this property trigger the track to post a
  /// `soloStatusDidChange` notification and to update it's `isMuted` flag. The default
  /// value of this property is `false`.
  public var solo = false {
    didSet {
      // Check that the value has actually changed.
      guard solo != oldValue else { return }

      // Post notification that the value of the track's `solo` flag has changed.
      postNotification(name: .soloStatusDidChange, object: self)

      // Update the value of the track's `isMuted` flag given the new value for `solo`.
      updateIsMuted()
    }
  }

  /// This property stores the value of `volume` before being set to `0` when setting
  /// `isMuted` to `true` so that the volume level may be restored when setting `isMuted`
  /// to `false`.
  private var cachedVolume: Float = 0

  /// Indicates whether new events have been added to the track without posting a
  /// `didUpdate` notification.
  private var isModified = false

  /// The MIDI endpoints connected to the track's `inputPort`.
  private var connectedEndPoints: Set<MIDIEndpointRef> = []

  /// An index of the loops that have been added to the track keyed by their identifiers.
  private var loops: [UUID: Sequencer.Loop] = [:]

  /// The track's MIDI client.
  private var client = MIDIClientRef()

  /// The track's MIDI input port.
  private var inputPort = MIDIPortRef()

  /// The track's MIDI output port.
  private var outPort = MIDIPortRef()

  // MARK: Computed Properties

  /// The track's position in the ordered list of instrument tracks belonging to `sequence`.
  public var index: Int { unwrapOrDie { sequence.instrumentTracks.firstIndex(of: self) } }

  /// Derived property wrapping `instrument.volume`.
  @WritablePassThrough(\Instrument.volume) public var volume: Float

  /// Derived property wrapping `instrument.pan`.
  @WritablePassThrough(\Instrument.pan) public var pan: Float

  /// Flag indicating whether new events should be persisted. This is `true` iff the
  /// sequencer is in it's default mode and the track is the current dispatch for the
  /// MIDI node player.
  public var isRecording: Bool {
    Sequencer.shared.mode == .linear && Player.currentDispatch === self
  }

  /// The name to give the next node dispatched. The derived value of this property
  /// consists of the track's display name followed by a space and the node count
  /// incremented for the node being dispatched.
  public var nextNodeName: String { "\(displayName) \(nodeManager.nodes.count + 1)" }

  /// A name for the track suitable for display in the user interface. The value of this
  /// property is derived via the following checks:
  /// 1. If the track's name is not empty, return the track's name.
  /// 2. If the track has initialized such that the instrument is available, return program
  ///    name for the instrument's current preset.
  /// 3. Return the empty string.
  public var displayName: String {
    name.isEmpty ? instrument.preset.programName : name
  }

  override public var description: String {
    [
      "instrument: \(String(describing: instrument))",
      "color: \(color)",
      super.description
    ].joined(separator: "\n")
  }

  // MARK: Change Propagation

  /// Handler for `didChangePreset` notifications received from `instrument`. This method
  /// posts a `didUpdate` notification for the track.
  private func didChangePreset(_ notification: Foundation.Notification) {
    // Post notification that the track has been updated.
    postNotification(name: .didUpdate, object: self)
  }

  /// Handler for `didReset` notifications received from the transport. When the
  /// `isModified` flag has been set, this methods posts a `didUpdate` notification for
  /// the track and clears the flag.
  private func didReset(_ notification: Foundation.Notification) {
    // Check that the track has been modified.
    guard isModified else { return }

    logi("posting 'DidUpdate'")

    // Post notification that the track has been updated.
    postNotification(name: .didUpdate, object: self)

    // Clear the flag.
    isModified = false
  }

  // MARK: Muting

  /// Updates the value of `isMuted` using the current values for `forceMute`, `mute`, and
  /// `solo`. If either `forceMute` or `mute` is equal to `true` and `solo` is equal to
  /// `false` then `isMuted` will be set to `true`; otherwise, `isMuted` will be set to
  /// `false`.
  private func updateIsMuted() {
    // Check that the track is not soloing.
    guard !solo else {
      // Soloing tracks are never muted.
      isMuted = false

      return
    }

    // `isMuted` is `true` iff `forceMute` or `mute` is `true`.
    isMuted = forceMute || mute
  }

  // MARK: MIDIFile support

  /// Overridden to refresh the values of `instrumentEvent` and `programEvent` before
  /// invoking `super`'s implementation.
  override public func validate(events container: inout EventContainer) {
    // Create the text for the instrument event.
    let instrumentText = "instrument:\(instrument.soundFont.url.lastPathComponent)"

    // Update `instrumentEvent` with a new meta event containging `instrumentText`.
    instrumentEvent = MetaEvent(data: .text(text: instrumentText))

    // Update `programEvent` with a new program change channel event that uses
    // the instrument's channel and program values.
    programEvent = try! ChannelEvent(kind: .programChange,
                                     channel: instrument.channel,
                                     data1: instrument.program)

    // Invoke `super`.
    super.validate(events: &container)
  }

  /// The track's initial MIDI events. Overridden to append `instrumentEvent` and
  /// `programEvent` to the array returned by the inherited implementation.
  override public var headEvents: [Event] {
    super.headEvents + [.meta(instrumentEvent), .channel(programEvent)]
  }

  // MARK: Event Dispatch

  /// Adds the MIDI events in `events` to the track. Instrument events and program change
  /// events are used to update the `instrumentEvent` and `programEvent` properties before
  /// passing the remaining events to `super` for the default implementation provided by
  /// the `EventDispatch` protocol.
  ///
  /// - Parameter events: The sequence containing the MIDI events to add to the track.
  override public func add<Source>(events: Source)
    where Source: Swift.Sequence, Source.Element == Event
  {
    // Create an array for accumulating events to provide the default implementation.
    var filteredEvents: [Event] = []

    // Iterate through the events.
    for event in events {
      // Consider the kind of event.
      switch event {
        case .meta(let metaEvent):
          // Check the kind of data attached to the meta event

          switch metaEvent.data {
            case .text(let text)
            where text.hasPrefix("instrument:"):
              // The event specifies the track's instrument.

              // Update `instrumentEvent` with `event`.
              instrumentEvent = metaEvent

            default:
              // The event should be passed through to `super`.

              // Append the event to `filteredEvents`.
              filteredEvents.append(event)
          }

        case .channel(let channelEvent)
        where channelEvent.status.kind == .programChange:
          // The event specifies the program for the instrument.

          // Update `programEvent` with `event`.
          programEvent = channelEvent

        default:
          // The event should be passed through to `super`.

          // Append the event to `filteredEvents`.
          filteredEvents.append(event)
      }
    }

    // Update `isModified` to be `true` if it was already `true` or `filteredEvents` is
    // not empty.
    isModified = isModified || !filteredEvents.isEmpty

    // Invoke `super` with the unhandled events for default implementation provided by the
    // `EventDispatch` protocol.
    super.add(events: filteredEvents)
  }

  /// Callback for receiving MIDI packets over the track's `inputPort`.
  ///
  /// - Parameters:
  ///   - packetList: The list of packets to receive
  ///   - context: This parameter is ignored.
  private func read(_ packetList: UnsafePointer<MIDIPacketList>,
                    context: UnsafeMutableRawPointer?)
  {
    do {
      // Forward the packets to the instrument
      try require(MIDISend(outPort, instrument.endPoint, packetList),
                  "Failed to forward packet list to instrument")

    } catch {
      // Just log the error.
      loge("\(error)")
    }

    // Check whether events need to be processed for MIDI file creation purposes.
    guard isRecording else { return }

    // Process the packet asynchronously on the queue designated for MIDI event operations.
    // Note that the capture list includes the current bar beat time so it is accurate for
    // the time when the closure is created and not the time when the closure is executed.
    eventQueue.async {
      [weak self, time = Sequencer.shared.time.barBeatTime] in

      // Grab the packet from the list.
      guard let packet = Packet(packetList: packetList) else { return }

      // Create a variable to hold the MIDI event generated from the packet.
      let event: Event?

      // Consider the packet's `status` value.
      switch ChannelEvent.Status.Kind(rawValue: packet.status) {
        case .noteOn?:
          // The packet contains a 'note on' event.

          // Initialize `event` with the corresponding channel event.
          event = .channel(try! ChannelEvent(kind: .noteOn,
                                             channel: packet.channel,
                                             data1: packet.note,
                                             data2: packet.velocity,
                                             time: time))
        case .noteOff?:
          // The packet contains a 'note off' event.

          // Initialize `event` with the corresponding channel event.
          event = .channel(try! ChannelEvent(kind: .noteOff,
                                             channel: packet.channel,
                                             data1: packet.note,
                                             data2: packet.velocity,
                                             time: time))
        default:
          // The packet contains an unhandled event.

          // Initialize to `nil`.
          event = nil
      }

      // Check that there is an event to add.
      guard event != nil else { return }

      // Add the event.
      self?.add(event: event!)
    }
  }

  /// Dispatches the specified event. Overridden to pass MIDI node events to `nodeManager`
  /// for handling.
  /// - Parameter event: The MIDI event to dispatch.
  override public func dispatch(event: Event) {
    // Get the MIDI node event.
    guard case .node(let nodeEvent) = event else { return }

    // Handle the node event using the node manager.
    nodeManager.handle(event: nodeEvent)
  }

  /// Overridden to return times for MIDI node events contained by `events` in addition
  /// to the times returned by the default implementation.
  /// - Parameter events: The sequence of MIDI events for which time callbacks will be
  ///                     registered.
  /// - Returns: An array of bar-beat times to register for callbacks.
  override public func registrationTimes<Source>(forAdding events: Source) -> [BarBeatTime]
    where Source: Swift.Sequence, Source.Iterator.Element == Event
  {
    // Get the times for the MIDI node events in `events`.
    let nodeTimes = events.filter {
      if case .node = $0 { return true }
      else { return false }
    }.map { $0.time }

    // Return the node times along with the times returned by `super`.
    return nodeTimes + super.registrationTimes(forAdding: events)
  }

  // MARK: Node Connections

  /// Connects the node's `endPoint` with the track's MIDI input so that MIDI events
  /// dispatched by the node may be sent to the track's instrument.
  ///
  /// - Parameter node: The MIDI node whose output should be connected to the track's input.
  /// - Precondition: The node's `endPoint` has not already been connected by the track.
  /// - Throws: `NodeDispatchError.nodeAlreadyConnected` when the track has already
  ///           connected the node's `endPoint`. Any error encountered connecting the
  ///           node's `endPoint` with the track's `inputPort`.
  public func connect(node: Node) throws {
    // Check that the node's `endPoint` has not already been connected by the track.
    guard connectedEndPoints ∌ node.endPoint else {
      throw NodeDispatchError.nodeAlreadyConnected
    }

    // Connect the node's `endPoint` to the track's `inputPort`.
    try require(MIDIPortConnectSource(inputPort, node.endPoint, nil),
                "Failed to connect to node \(node.name!)")

    // Insert the node's `endPoint` into the collection of endpoints connected to the track.
    connectedEndPoints.insert(node.endPoint)
  }

  /// Disconnects the node's `endPoint` from the track's MIDI input.
  ///
  /// - Parameter node: The MIDI node to disconnect as an input source for the track.
  /// - Precondition: The node's `endPoint` has been connected by the track to the track's
  ///                 `inputPort`.
  /// - Throws: `NodeDispatchError.nodeNotFound` when the node has not been connected
  ///            to the track. Any error encountered disconnecting the node's `endPoint`
  ///            from the track's `inputPort`.
  public func disconnect(node: Node) throws {
    // Check that the node's endpoint was previously connected by the track.
    guard connectedEndPoints ∋ node.endPoint else {
      throw NodeDispatchError.nodeNotFound
    }

    // Disconnect the node's endpoint from the track's input.
    try require(MIDIPortDisconnectSource(inputPort, node.endPoint),
                "Failed to disconnect to node \(node.name!)")

    // Remove the node's endpoint from the set of connected endpoints.
    connectedEndPoints.remove(node.endPoint)
  }

  // MARK: Loop Management

  /// Adds the specified loop to the track by storing it in `loops` and adding the loop's
  /// MIDI events.
  ///
  /// - Parameter loop: The loop to add to the track.
  /// - Precondition: The loop has not already been added to the track.
  public func add(loop: Sequencer.Loop) {
    // Check that the loop has not already been added to the track.
    guard loops[loop.identifier] == nil else { return }

    logi("adding loop: \(loop)")

    // Store the loop by it's identifier.
    loops[loop.identifier] = loop

    // Add the loop's MIDI events.
    add(events: loop)
  }

  // MARK: Initializing

  /// Initializing with a sequence and an instrument. Initializes an empty track owned
  /// by the specified sequence that uses the specified instrument, assigning itself as
  /// the instrument's track.
  ///
  /// - Parameters:
  ///   - sequence: The `Sequence` that owns the created track.
  ///   - instrument: The `Instrument` to couple with the created track.
  /// - Throws: Any error encountered creating the MIDI client or MIDI ports for the track.
  public init(sequence: Sequencer.Sequence, instrument: Instrument) throws {
    // Initialize `instrument` using the specified instrument.
    self.instrument = instrument

    // Initialize using the specified sequence.
    super.init(sequence: sequence)

    // Initialize `instrumentEvent` using file name of the instrument's sound font.
    let instrumentText = "instrument:\(instrument.soundFont.url.lastPathComponent)"
    instrumentEvent = MetaEvent(data: .text(text: instrumentText))

    // Initialize `programEvent` with the instrument's channel and program values.
    programEvent = try! ChannelEvent(kind: .programChange,
                                     channel: instrument.channel,
                                     data1: instrument.program)

    // Initialize `color` with the next available track color.
    color = TrackColor.nextColor(
      currentColors: Set(sequence.instrumentTracks.map(\.color)))

    // Register for notifications and create MIDI client/ports. Must be called after
    // instrument initialization because notification registration requires the track's
    // instrument.
    try setup()
  }

  public init(sequence: Sequencer.Sequence,
              preset: Instrument.Preset?,
              color: TrackColor,
              name: String,
              events: [Event]) throws
  {
    let preset = preset ?? Sequencer.shared.auditionInstrument.preset
    instrument = try Instrument(preset: preset)
    super.init(sequence: sequence)
    self.color = color
    self.name = name
    add(events: events)
    try setup()
  }

  /// Initializing with a sequence and a MIDI file chunk.
  ///
  /// - Parameters:
  ///   - sequence: The `Sequence` that owns the created track.
  ///   - trackChunk: The `MIDIFile.TrackChunk` containing the MIDI events for initializing
  ///                 the track.
  /// - Throws: Any error encountered creating a new instrument for the track, any error
  ///           encountered creating the track's MIDI client/ports.
  /// - TODO: When using the MIDI events contained by `trackChunk` to generate the track's
  ///         instrument, a bank change event should be queried rather than assuming a
  ///         bank value of `0`.
  public init(sequence: Sequencer.Sequence, trackChunk: TrackChunk) throws {
    // Look for MIDI events relating to the instrument.
    if let instrumentIndex = trackChunk.events.firstIndex(where: {
      guard case .meta(let metaEvent) = $0,
            case .text(let text) = metaEvent.data,
            text.hasPrefix("instrument:")
      else { return false }
      return true
    }),
      let programIndex = trackChunk.events.firstIndex(where: {
        guard case .channel(let channelEvent) = $0,
              channelEvent.status.kind == .programChange
        else { return false }
        return true
      }),
      case .meta(let instrument) = trackChunk.events[instrumentIndex],
      case .channel(let program) = trackChunk.events[programIndex]
    {
      self.instrument = try Instrument(instrument: instrument, program: program)
    } else {
      instrument = try Instrument(preset: Sequencer.shared.auditionInstrument.preset)
    }

    // Initialize with the specified sequence.
    super.init(sequence: sequence)

    // Add the MIDI events provided by the chunk to the track.
    add(events: trackChunk.events)

    // Initialize `color` with the next available track color.
    color = .nextColor(currentColors: Set(sequence.instrumentTracks.map(\.color)))

    // Register for notifications and create MIDI client/ports. Must be called after
    // instrument initialization because notification registration requires the track's
    // instrument.
    try setup()
  }

  /// Registers for transport and instrument notifications. Creates MIDI client and
  /// input/output ports.
  ///
  /// - Throws: Any error encountered creating the MIDI client or MIDI ports.
  private func setup() throws {
    // Observe `didReset` notifications posted by the primary transport.
    receptionist.observe(name: .didReset,
                         from: Sequencer.shared.primaryTransport,
                         callback: weakCapture(of: self, block: InstrumentTrack.didReset))

    // Observe program and sound font changes posted by the track's instrument
    receptionist.observe(name: .programDidChange,
                         from: instrument,
                         callback: weakCapture(of: self,
                                               block: InstrumentTrack.didChangePreset))
    receptionist.observe(name: .soundFontDidChange,
                         from: instrument,
                         callback: weakCapture(of: self,
                                               block: InstrumentTrack.didChangePreset))

    // Create the MIDI client for the track.
    try require(MIDIClientCreateWithBlock("track \(instrument.bus)" as CFString,
                                          &client, nil),
                "Failed to create MIDI client.")

    // Create the track's MIDI output port.
    try require(MIDIOutputPortCreate(client, "Output" as CFString, &outPort),
                "Failed to create MIDI output port.")

    // Create the track's MIDI input port.
    try require(MIDIInputPortCreateWithBlock(client, name as CFString,
                                             &inputPort, read),
                "Failed to create MIDI input port.")
  }
}

// MARK: Hashable

extension InstrumentTrack: Hashable {
  public func hash(into hasher: inout Hasher) {
    ObjectIdentifier(self).hash(into: &hasher)
  }

  /// Returns `true` iff `lhs` and `rhs` are the same instance.
  public static func ==(lhs: InstrumentTrack, rhs: InstrumentTrack) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
  }
}
