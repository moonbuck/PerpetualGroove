//
//  InstrumentTrack.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 8/14/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import Foundation
import UIKit
import MoonKit
import CoreMIDI
import SpriteKit

/// A `Track` subclass able to handle MIDI node events.
///
/// - TODO: Replace the class description in this comment.
final class InstrumentTrack: Track, MIDINodeDispatch, Hashable {

  /// The currently selected track in the current sequence or `nil`.
  static var current: InstrumentTrack? { return Sequence.current?.currentTrack }

  /// A manager for the MIDI nodes dispatched by the track.
  private(set) var nodeManager: MIDINodeManager!

  /// Handles registration/reception for various notifications from the track's instrument
  /// and the current transport.
  ///
  /// - TODO: Shouldn't we be more specific on which transport is observed?
  private let receptionist = NotificationReceptionist(callbackQueue: OperationQueue.main)

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

    Log.debug("posting 'DidUpdate'")

    // Post notification that the track has been updated.
    postNotification(name: .didUpdate, object: self)

    // Clear the flag.
    isModified = false

  }

  /// Overridden to refresh the values of `instrumentEvent` and `programEvent` before
  /// invoking `super`'s implementation.
  override func validate(events container: inout MIDIEventContainer) {

    // Create the text for the instrument event.
    let instrumentText = "instrument:\(instrument.soundFont.url.lastPathComponent)"

    // Update `instrumentEvent` with a new meta event containging `instrumentText`.
    instrumentEvent = MIDIEvent.MetaEvent(data: .text(text: instrumentText))

    // Update `programEvent` with a new program change channel event that uses 
    // the instrument's channel and program values.
    programEvent = MIDIEvent.ChannelEvent(type: .programChange,
                                          channel: instrument.channel,
                                          data1: instrument.program)

    // Invoke `super`.
    super.validate(events: &container)

  }

  /// Adds the MIDI events in `events` to the track. Instrument events and program change
  /// events are used to update the `instrumentEvent` and `programEvent` properties before
  /// passing the remaining events to `super` for the default implementation provided by
  /// the `MIDIEventDispatch` protocol.
  ///
  /// - Parameter events: The sequence containing the MIDI events to add to the track.
  func add<Source>(events: Source)
    where Source:Swift.Sequence, Source.Iterator.Element == MIDIEvent
  {

    // Create an array for accumulating events to provide the default implementation.
    var filteredEvents: [MIDIEvent] = []

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
    // `MIDIEventDispatch` protocol.
    super.add(events: filteredEvents)

  }

  /// The MIDI event that specifies the instrument used by the track.
  private var instrumentEvent: MIDIEvent.MetaEvent!

  /// The MIDI event that specifies the program used by the track.
  private var programEvent: MIDIEvent.ChannelEvent!

  /// The track's initial MIDI events. Overridden to append `instrumentEvent` and 
  /// `programEvent` to the array returned by the inherited implementation.
  override var headEvents: [MIDIEvent] {
    return super.headEvents + [.meta(instrumentEvent), .channel(programEvent)]
  }

  /// The instrument used by the track.
  private(set) var instrument: Instrument!

  var color: TrackColor = .muddyWaters

  /// Flag indicating whether new events should be persisted. This is `true` iff the 
  /// sequencer is in it's default mode and the track is the current dispatch for the
  /// MIDI node player.
  var isRecording: Bool {
    return Sequencer.mode == .default && MIDINodePlayer.currentDispatch === self
  }

  /// The name to give the next node dispatched. The derived value of this property
  /// consists of the track's display name followed by a space and the node count
  /// incremented for the node being dispatched.
  var nextNodeName: String { return "\(displayName) \(nodeManager.nodes.count + 1)" }

  /// A name for the track suitable for display in the user interface. The value of this
  /// property is derived via the following checks:
  /// 1. If the track's name is not empty, return the track's name.
  /// 2. If the track has initialized such that the instrument is available, return program
  ///    name for the instrument's current preset.
  /// 3. Return the empty string.
  override var displayName: String {

    // Check that track's name is empty.
    guard name.isEmpty else { return name }

    // Return the program name for the preset or the empty string if `instrument` is `nil`.
    return instrument?.preset.programName ?? ""

  }

  /// Flag indicating whether the track is in a muted state, whether from a user request or
  /// as the result of another track being soloed. Changing the value of this property 
  /// triggers a `muteStatusDidChange` notification to be posted for the track. When set to
  /// `true`, the current value of `volume` is cached and `volume` is set to `0`. When set 
  /// to `false`, the cached value is restored. The default value of this property is 
  /// `false`.
  private(set) var isMuted = false {

    didSet {

      // Check that the value has actually changed.
      guard isMuted != oldValue else { return }

      // Swap the values of `volume` and `cachedVolume`.
      swap(&volume, &cachedVolume)

      // Post notification that the track's mute status has changed.
      postNotification(name: .muteStatusDidChange, object: self)

    }

  }

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

  /// Flag indicating whether the track should be silenced because one or more of the other
  /// tracks in the sequence are soloing. Changing the value of this property triggers the
  /// track to post a `forceMuteStatusDidChange` notification and to update the value of 
  /// it's `isMuted` flag. The default value of this property is `false`.
  var forceMute = false {

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
  var mute = false {

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
  var solo = false {

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

  /// Derived property wrapping `instrument.volume`.
  var volume: Float {
    get { return instrument.volume }
    set { instrument.volume = newValue }
  }

  /// Derived property wrapping `instrument.pan`.
  var pan: Float {
    get { return instrument.pan }
    set { instrument.pan = newValue }
  }

  /// Indicates whether new events have been added to the track without posting a 
  /// `didUpdate` notification.
  private var isModified = false

  /// The MIDI endpoints connected to the track's `inputPort`.
  private var connectedEndPoints: Set<MIDIEndpointRef> = []

  /// Connects the node's `endPoint` with the track's MIDI input so that MIDI events
  /// dispatched by the node may be sent to the track's instrument.
  ///
  /// - Parameter node: The MIDI node whose output should be connected to the track's input.
  /// - Precondition: The node's `endPoint` has not already been connected by the track.
  /// - Throws: `MIDINodeDispatchError.nodeAlreadyConnected` when the track has already
  ///           connected the node's `endPoint`. Any error encountered connecting the
  ///           node's `endPoint` with the track's `inputPort`.
  func connect(node: MIDINode) throws {

    // Check that the node's `endPoint` has not already been connected by the track.
    guard connectedEndPoints ∌ node.endPoint else {
      throw MIDINodeDispatchError.nodeAlreadyConnected
    }

    // Connect the node's `endPoint` to the track's `inputPort`.
    try MIDIPortConnectSource(inputPort, node.endPoint, nil)
      ➤ "Failed to connect to node \(node.name!)"

    // Insert the node's `endPoint` into the collection of endpoints connected to the track.
    connectedEndPoints.insert(node.endPoint)

  }

  /// Disconnects the node's `endPoint` from the track's MIDI input.
  ///
  /// - Parameter node: The MIDI node to disconnect as an input source for the track.
  /// - Precondition: The node's `endPoint` has been connected by the track to the track's
  ///                 `inputPort`.
  /// - Throws: `MIDINodeDispatchError.nodeNotFound` when the node has not been connected 
  ///            to the track. Any error encountered disconnecting the node's `endPoint`
  ///            from the track's `inputPort`.
  func disconnect(node: MIDINode) throws {

    // Check that the node's endpoint was previously connected by the track.
    guard connectedEndPoints ∋ node.endPoint else {
      throw MIDINodeDispatchError.nodeNotFound
    }

    // Disconnect the node's endpoint from the track's input.
    try MIDIPortDisconnectSource(inputPort, node.endPoint)
      ➤ "Failed to disconnect to node \(node.name!)"

    // Remove the node's endpoint from the set of connected endpoints.
    connectedEndPoints.remove(node.endPoint)

  }

  /// Adds the specified loop to the track by storing it in `loops` and adding the loop's
  /// MIDI events.
  ///
  /// - Parameter loop: The loop to add to the track.
  /// - Precondition: The loop has not already been added to the track.
  func add(loop: Loop) {

    // Check that the loop has not already been added to the track.
    guard loops[loop.identifier] == nil else { return }

    Log.debug("adding loop: \(loop)")

    // Store the loop by it's identifier.
    loops[loop.identifier] = loop

    // Add the loop's MIDI events.
    add(events: loop)

  }

  /// An index of the loops that have been added to the track keyed by their identifiers.
  private var loops: [UUID:Loop] = [:]

  /// The track's MIDI client.
  private var client  = MIDIClientRef()

  /// The track's MIDI input port.
  private var inputPort  = MIDIPortRef()

  /// The track's MIDI output port.
  private var outPort = MIDIPortRef()


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
      try MIDISend(outPort, instrument.endPoint, packetList)
        ➤ "Failed to forward packet list to instrument"

    } catch {

      // Just log the error.
      Log.error(error)

    }

    // Check whether events need to be processed for MIDI file creation purposes.
    guard isRecording else { return }

    // Process the packet asynchronously on the queue designated for MIDI event operations.
    // Note that the capture list includes the current bar beat time so it is accurate for 
    // the time when the closure is created and not the time when the closure is executed.
    eventQueue.async {
      [weak self, time = Time.current.barBeatTime] in

      // Grab the packet from the list.
      guard let packet = Packet(packetList: packetList) else { return }

      // Create a variable to hold the MIDI event generated from the packet.
      let event: MIDIEvent?

      // Consider the packet's `status` value.
      switch MIDIEvent.ChannelEvent.Status.Kind(rawValue: packet.status) {

        case .noteOn?:
          // The packet contains a 'note on' event.

          // Initialize `event` with the corresponding channel event.
          event = .channel(MIDIEvent.ChannelEvent(type: .noteOn,
                                                  channel: packet.channel,
                                                  data1: packet.note,
                                                  data2: packet.velocity,
                                                  time: time))
        case .noteOff?:
          // The packet contains a 'note off' event.

          // Initialize `event` with the corresponding channel event.
          event = .channel(MIDIEvent.ChannelEvent(type: .noteOff,
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
  override func dispatch(event: MIDIEvent) {

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
  override func registrationTimes<Source>(forAdding events: Source) -> [BarBeatTime]
    where Source:Swift.Sequence, Source.Iterator.Element == MIDIEvent
  {

    // Get the times for the MIDI node events in `events`.
    let nodeTimes = events.filter({
      if case .node(_) = $0 { return true }
      else { return false }
    }).map({$0.time})

    // Return the node times along with the times returned by `super`.
    return nodeTimes + super.registrationTimes(forAdding: events)

  }

  /// The track's position in the ordered list of instrument tracks belonging to `sequence`.
  var index: Int {

    // Get the track's index.
    guard let index = sequence.instrumentTracks.index(of: self) else {
      fatalError("Failed to locate track among the sequence's instrument tracks")
    }

    return index

  }

  /// Registers for transport and instrument notifications. Creates MIDI client and
  /// input/output ports.
  ///
  /// - Throws: Any error encountered creating the MIDI client or MIDI ports.
  private func setup() throws {

    // Observe `didReset` notifications posted by the primary transport.
    receptionist.observe(name: .didReset, from: Sequencer.primaryTransport.transport,
                         callback: weakMethod(self, InstrumentTrack.didReset))

    // Observe program and sound font changes posted by the track's instrument
    receptionist.observe(name: .programDidChange, from: instrument,
                         callback: weakMethod(self, InstrumentTrack.didChangePreset))
    receptionist.observe(name: .soundFontDidChange, from: instrument,
                         callback: weakMethod(self, InstrumentTrack.didChangePreset))

    // Create the MIDI client for the track.
    try MIDIClientCreateWithBlock("track \(instrument.bus)" as CFString, &client, nil)
      ➤ "Failed to create MIDI client."

    // Create the track's MIDI output port.
    try MIDIOutputPortCreate(client, "Output" as CFString, &outPort)
      ➤ "Failed to create MIDI output port."

    // Create the track's MIDI input port.
    try MIDIInputPortCreateWithBlock(client, name as CFString, &inputPort,
                                     weakMethod(self, InstrumentTrack.read))
      ➤ "Failed to create MIDI input port."

  }


  /// Initializing with a sequence and an instrument. Initializes an empty track owned
  /// by the specified sequence that uses the specified instrument, assigning itself as
  /// the instrument's track.
  ///
  /// - Parameters:
  ///   - sequence: The `Sequence` that owns the created track.
  ///   - instrument: The `Instrument` to couple with the created track.
  /// - Throws: Any error encountered creating the MIDI client or MIDI ports for the track.
  init(sequence: Sequence, instrument: Instrument) throws {

    // Initialize using the specified sequence.
    super.init(sequence: sequence)

    // Create a new node manager for the track.
    nodeManager = MIDINodeManager(owner: self)

    // Initialize `instrument` using the specified instrument.
    self.instrument = instrument

    // Assign the track to the instrument.
    instrument.track = self

    // Initialize `instrumentEvent` using file name of the instrument's sound font.
    let instrumentText = "instrument:\(instrument.soundFont.url.lastPathComponent)"
    instrumentEvent = MIDIEvent.MetaEvent(data: .text(text: instrumentText))

    // Initialize `programEvent` with the instrument's channel and program values.
    programEvent = MIDIEvent.ChannelEvent(type: .programChange,
                                          channel: instrument.channel,
                                          data1: instrument.program)

    // Initialize `color` with the next available track color.
    color = TrackColor.nextColor

    // Register for notifications and create MIDI client/ports. Must be called after
    // instrument initialization because notification registration requires the track's
    // instrument.
    try setup()

  }

  /// Initializing with a sequence and track data from a Groove file. An instrument is 
  /// created for the track using the preset data specified by `grooveTrack`, any loop
  /// data provided by `grooveTrack` is used to add loops to the track, and any node data
  /// provided by `grooveTrack` is used to generate MIDI node events for the track.
  ///
  /// - Parameters:
  ///   - sequence: The `Sequence` that owns the created track.
  ///   - grooveTrack: The instrument and event data used to initialize the track.
  /// - Throws: Any error encountered creating the track's instrument, any error 
  ///           encountered creating the MIDI client/ports.
  init(sequence: Sequence, grooveTrack: GrooveFile.Track) throws {

    // Initialize with the specified sequence.
    super.init(sequence: sequence)

    // Create a node manager for the track.
    nodeManager = MIDINodeManager(owner: self)

    // Create the instrument preset from the track data provided, using the preset for
    // the sequencer's audition instrument if necessary.
    let preset = Instrument.Preset(grooveTrack.instrument.jsonValue)
                   ?? Sequencer.auditionInstrument.preset

    // Create a new instrument that uses `preset` and that is assigned to the track.
    instrument = try Instrument(track: self, preset: preset)

    // Initialize `color` using the color provided by `grooveTrack`.
    color = grooveTrack.color

    // Initialize `name` using the name provided by `grooveTrack`.
    name = grooveTrack.name

    // Create an array for accumulating MIDI events.
    var events: [MIDIEvent] = []

    // Iterate the node data provided by `grooveTrack`.
    for nodeData in grooveTrack.nodes.values {

      // Append an event adding a MIDI node using `nodeData` to the array of events.
      events.append(.node(MIDIEvent.MIDINodeEvent(forAdding: nodeData)))

      // Check whether a remove time is specified by attempting to create an event that
      // removes the MIDI node created using `nodeData`.
      if let event = MIDIEvent.MIDINodeEvent(forRemoving: nodeData) {

        // Append the successfully created event to the array of events.
        events.append(.node(event))

      }

    }

    // Add the MIDI events generated from the node data to the track.
    add(events: events)


    // Iterate the loop data provided by `grooveTrack`.
    for loopData in grooveTrack.loops.values {

      // Create a loop using `loopData`.
      let loop = Loop(grooveLoop: loopData, track: self)

      // Add the loop to the track.
      add(loop: loop)

    }

    // Register for notifications and create MIDI client/ports. Must be called after
    // instrument initialization because notification registration requires the track's
    // instrument.
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
  init(sequence: Sequence, trackChunk: MIDIFile.TrackChunk) throws {

    // Initialize with the specified sequence.
    super.init(sequence: sequence)

    // Create a node manager for the track.
    nodeManager = MIDINodeManager(owner: self)

    // Add the MIDI events provided by the chunk to the track.
    add(events: trackChunk.events)

    // Helper function that attempts to create a new `Instrument` using the MIDI events
    // provided by the chunk.
    func createInstrumentUsingMIDIEvents() -> Instrument? {

      // Check that a suitable instrument event was provided by the track chunk and extract
      // the name of the instrument from the event's data.
      guard let instrumentEvent = instrumentEvent,
            case .text(var instrumentName) = instrumentEvent.data else
      {
        return nil
      }

      // Get an index for the first character in the actual instrument name.
      let index = instrumentName.index(instrumentName.startIndex, offsetBy:11)

      // Trim the leading 'instrument:' from the extracted text.
      instrumentName = instrumentName.substring(from: index)

      // Locate the matching sound font file within the application's main bundle.
      guard let url = Bundle.main.url(forResource: instrumentName,
                                      withExtension: nil)
        else
      {
        return nil
      }

      // Create a sound font using the bundle resource url.
      guard let soundFont: SoundFont = (   try? EmaxSoundFont(url: url))
                                        ?? (try? AnySoundFont(url: url))
        else
      {
        return nil
      }

      // Check that a program change event was provided by the track chunk.
      guard let programEvent = programEvent else {
        return nil
      }

      // Get the channel and program values from the program event.
      let channel = programEvent.status.channel, program = programEvent.data1

      // Incorrectly, just assume a bank value of `0`.
      let bank: UInt8 = 0

      Log.warning("\(#function) not yet fully implemented. The bank value needs handling")

      // Retrieve the preset header from the sound font for (`program`, `bank`).
      guard let presetHeader = soundFont[program: program, bank: bank] else {
        return nil
      }

      // Create a preset using the derived values.
      let preset = Instrument.Preset(soundFont: soundFont,
                                     presetHeader: presetHeader,
                                     channel: channel)

      // Return an instrument initialized with the track and the preset.
      return try? Instrument(track: self, preset: preset)

    }

    // Try generating an instrument from the MIDI events provided by the track chunk.
    if let instrument = createInstrumentUsingMIDIEvents() {

      // Initialize `instrument` with the generated instrument.
      self.instrument = instrument

    }

    // Otherwise, try initializing `instrument` with a new instrument copied from the
    // sequencer's audition instrument.
    else {

      instrument = try Instrument(track: self, preset: Sequencer.auditionInstrument.preset)

    }

    // Initialize `color` with the next available track color.
    color = TrackColor.nextColor

    // Register for notifications and create MIDI client/ports. Must be called after 
    // instrument initialization because notification registration requires the track's 
    // instrument.
    try setup()

  }

  override var description: String {

    return [
      "instrument: \(instrument)",
      "color: \(color)",
      super.description
      ].joined(separator: "\n")

  }

  var hashValue: Int { return ObjectIdentifier(self).hashValue }

  /// Returns `true` iff `lhs` and `rhs` are the same instance.
  static func ==(lhs: InstrumentTrack, rhs: InstrumentTrack) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
  }

}

