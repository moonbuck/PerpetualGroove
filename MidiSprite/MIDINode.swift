//
//  MIDINode.swift
//  MidiSprite
//
//  Created by Jason Cardwell on 8/12/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import UIKit
import SpriteKit
import MoonKit
import CoreMIDI
import struct AudioToolbox.MIDINoteMessage

final class MIDINode: SKSpriteNode {

  // MARK: - Properties relating to the node's appearance

  static var defaultSize = CGSize(square: 32)

  // MARK: -  Properties affecting what is played by the node

  var note: NoteAttributes

  struct Placement: ByteArrayConvertible {
    let position: CGPoint
    let vector: CGVector
    static let zero = Placement(position: .zero, vector: .zero)
    var bytes: [Byte] {
      let positionString = NSStringFromCGPoint(position)
      let vectorString = NSStringFromCGVector(vector)
      let string = "{\(positionString), \(vectorString)}"
      return Array(string.utf8)
    }
    init(position p: CGPoint, vector v: CGVector) { position = p; vector = v }
    init(_ bytes: [Byte]) {
      let castBytes = bytes.map({CChar($0)})
      guard let string = String.fromCString(castBytes) else { self = .zero; return }

      let float = "-?[0-9]+(?:\\.[0-9]+)?"
      let value = "\\{\(float), \(float)\\}"
      guard let match = (~/"\\{(\(value)), (\(value))\\}").firstMatch(string, anchored: true),
                positionCapture = match.captures[1],
                vectorCapture = match.captures[2] else { self = .zero; return }

      position = CGPointFromString(positionCapture.string)
      vector = CGVectorFromString(vectorCapture.string)
    }
  }

  var placement: Placement

  static let useVelocityForOff = true

  // MARK: - Methods for playing/erasing the node

  enum Actions: String { case Play }

  /** play */
  func play() {
    let halfDuration = note.duration.seconds
    let scaleUp = SKAction.scaleTo(2, duration: halfDuration)
    let noteOn = SKAction.runBlock({ [weak self] in self?.sendNoteOn() })
    let scaleDown = SKAction.scaleTo(1, duration: halfDuration)
    let noteOff = SKAction.runBlock({ [weak self] in self?.sendNoteOff() })
    let sequence = SKAction.sequence([SKAction.group([scaleUp, noteOn]), scaleDown, noteOff])
    runAction(sequence, withKey: Actions.Play.rawValue)
  }

  /** erase */
  private func erase() { logWarning("erase() not yet implemented") }

  typealias Identifier = UInt64

  private var _sourceID: Identifier = 0
  var sourceID: Identifier { return _sourceID }

  private enum PlayState { case Off, On }

  private var playState = PlayState.Off

  /** sendNoteOn */
  func sendNoteOn() {
    var packetList = MIDIPacketList()
    let packet = MIDIPacketListInit(&packetList)
    let size = sizeof(UInt32.self) + sizeof(MIDIPacket.self)
    let data: [Byte] = [0x90 | note.channel, note.note.MIDIValue, note.velocity.MIDIValue] + _sourceID.bytes
    let timeStamp = time.timeStamp
    MIDIPacketListAdd(&packetList, size, packet, timeStamp, 11, data)
    do {
      try withUnsafePointer(&packetList) { MIDIReceived(endPoint, $0) } ➤ "Unable to send note on event"
      playState = .On
    } catch { logError(error) }
  }

  /** sendNoteOff */
  func sendNoteOff() {
    guard playState == .On else { return }
    var packetList = MIDIPacketList()
    let packet = MIDIPacketListInit(&packetList)
    let size = sizeof(UInt32.self) + sizeof(MIDIPacket.self)
    let data: [UInt8] = MIDINode.useVelocityForOff
                ? [0x90 | note.channel, note.note.MIDIValue, 0] + _sourceID.bytes
                : [0x80 | note.channel, note.note.MIDIValue, 0] + _sourceID.bytes
    let timeStamp = time.timeStamp
    MIDIPacketListAdd(&packetList, size, packet, timeStamp, 11, data)
    do {
      try withUnsafePointer(&packetList) { MIDIReceived(endPoint, $0) } ➤ "Unable to send note off event"
      playState = .Off
    } catch { logError(error) }
  }

  /** removeFromParent */
  override func removeFromParent() { erase(); super.removeFromParent() }
  override func removeActionForKey(key: String) {
    if actionForKey(key) != nil && Actions.Play.rawValue == key { sendNoteOff() }
    super.removeActionForKey(key)
  }
  private var client = MIDIClientRef()
  private let time = Sequencer.barBeatTime
  private(set) var endPoint = MIDIEndpointRef()

  /**
  init:placement:instrument:note:

  - parameter t: TextureType
  - parameter p: Placement
  - parameter tr: Track
  - parameter n: Note
  */
  init(placement p: Placement, name: String, track: InstrumentTrack, attributes: NoteAttributes) throws {
    placement = p
    note = attributes

    super.init(texture: SKTexture(image: UIImage(named: "ball")!),
               color: track.color.value,
               size: MIDINode.defaultSize)

    _sourceID = Identifier(ObjectIdentifier(self).uintValue)

    try MIDIClientCreateWithBlock(name, &client, nil) ➤ "Failed to create midi client"
    try MIDISourceCreate(client, "\(name)", &endPoint) ➤ "Failed to create end point for node \(name)"

    self.name = name
    colorBlendFactor = 1

    position = placement.position
    physicsBody = SKPhysicsBody(circleOfRadius: size.width * 0.5)
    physicsBody?.affectedByGravity = false
    physicsBody?.usesPreciseCollisionDetection = true
    physicsBody?.velocity = placement.vector
    physicsBody?.linearDamping = 0.0
    physicsBody?.angularDamping = 0.0
    physicsBody?.friction = 0.0
    physicsBody?.restitution = 1.0
    physicsBody?.contactTestBitMask = 0xFFFFFFFF
    physicsBody?.categoryBitMask = 0
    physicsBody?.collisionBitMask = 1
  }

  deinit {
    do {
      try MIDIEndpointDispose(endPoint) ➤ "Failed to dispose of end point"
      try MIDIClientDispose(client) ➤ "Failed to dispose of midi client"
    } catch { logError(error) }
  }

  /**
  init:

  - parameter aDecoder: NSCoder
  */
  required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

}
