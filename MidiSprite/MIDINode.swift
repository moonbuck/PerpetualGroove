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

  // MARK: - Type to specify the node's texture
  enum TextureType: String, EnumerableType {
    case Brick, Cobblestone, Concrete, Crusty, DiamondPlate, Dirt, Fur,
         Mountains, OceanBasin, Parchment, Sand, Stucco
    var image: UIImage { return UIImage(named: "\(rawValue.lowercaseString)-button")! }
    var texture: SKTexture { return TextureType.atlas.textureNamed(rawValue.lowercaseString) }
    static let atlas = SKTextureAtlas(named: "balls")
    static let allCases: [TextureType] = [.Brick, .Cobblestone, .Concrete, .Crusty, .DiamondPlate, .Dirt, .Fur,
                                          .Mountains, .OceanBasin, .Parchment, .Sand, .Stucco]
  }

  // MARK: - Properties used to initialize a new `MIDINode`
  static var currentNote = Note(channel: 0, note: 60, velocity: 64, releaseVelocity: 54, duration: 0.25)
  static var currentTexture = TextureType.Cobblestone

  // MARK: - Properties relating to the node's appearance

  var textureType: TextureType

  static var defaultSize = CGSize(square: 32)

  // MARK: -  Properties affecting what is played by the node

  typealias Note = MIDINoteMessage

  var note: Note

  struct Placement: ByteArrayConvertible {
    let position: CGPoint
    let vector: CGVector
    static let zero = Placement(position: .zero, vector: .zero)
    var bytes: [Byte] {
      let positionString = NSStringFromCGPoint(position)
      let vectorString = NSStringFromCGVector(vector)
      let string = "{\(positionString), \(vectorString)}"
      return Array(string.utf8)
//      let positionX = Byte8(position.x._toBitPattern())
//      let positionY = Byte8(position.y._toBitPattern())
//      let vectorDX  = Byte8(vector.dx._toBitPattern())
//      let vectorDY  = Byte8(vector.dy._toBitPattern())
//      return positionX.bytes + positionY.bytes + vectorDX.bytes + vectorDY.bytes
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
//      guard bytes.count == 32 else { self = Placement(position: .zero, vector: .zero); return }
//      let positionX = CGFloat._fromBitPattern(UInt(Byte8(bytes[0 ..< 8])))
//      let positionY = CGFloat._fromBitPattern(UInt(Byte8(bytes[8 ..< 16])))
//      let vectorDX  = CGFloat._fromBitPattern(UInt(Byte8(bytes[16 ..< 24])))
//      let vectorDY  = CGFloat._fromBitPattern(UInt(Byte8(bytes[24 ..< 32])))
//      position = CGPoint(x: positionX, y: positionY)
//      vector = CGVector(dx: vectorDX, dy: vectorDY)
    }
  }

  var placement: Placement

  let id = nonce()

  // MARK: - Methods for playing/erasing the node

  enum Actions: String { case Play }

  /** play */
  func play() {
    let halfDuration = Double(note.duration * 0.5)
    let scaleUp = SKAction.scaleTo(2, duration: halfDuration)
    let noteOn = SKAction.runBlock({ [weak self] in self?.sendNoteOn() })
    let scaleDown = SKAction.scaleTo(1, duration: halfDuration)
    let noteOff = SKAction.runBlock({ [weak self] in self?.sendNoteOff() })
    let sequence = SKAction.sequence([SKAction.group([scaleUp, noteOn]), scaleDown, noteOff])
    runAction(sequence, withKey: Actions.Play.rawValue)
  }

  /** erase */
  private func erase() {
  }

  private var sourceID: [Byte] = []

  /** sendNoteOn */
  func sendNoteOn() {
    var packetList = MIDIPacketList()
    let packet = MIDIPacketListInit(&packetList)
    let size = sizeof(UInt32.self) + sizeof(MIDIPacket.self)
    let data: [UInt8] = [0x90 | note.channel, note.note, note.velocity] + sourceID
    let timeStamp = time.timeStamp
    logDebug("timeStamp = \(timeStamp); barBeatTime = \(time)")
    MIDIPacketListAdd(&packetList, size, packet, timeStamp, 11, data)
    do {
      try withUnsafePointer(&packetList) {MIDIReceived(endPoint, $0) } ➤ "Unable to send note on event"
    } catch { logError(error) }
  }

  /** sendNoteOff */
  func sendNoteOff() {
    var packetList = MIDIPacketList()
    let packet = MIDIPacketListInit(&packetList)
    let size = sizeof(UInt32.self) + sizeof(MIDIPacket.self)
    let data: [UInt8] = [0x80 | note.channel, note.note, note.releaseVelocity] + sourceID
    let timeStamp = time.timeStamp
    logDebug("timeStamp = \(timeStamp); barBeatTime = \(time)")
    MIDIPacketListAdd(&packetList, size, packet, timeStamp, 11, data)
    do {
      try withUnsafePointer(&packetList) {MIDIReceived(endPoint, $0) } ➤ "Unable to send note off event"
    } catch { logError(error) }
  }

  /** removeFromParent */
  override func removeFromParent() { erase(); super.removeFromParent() }

  private var client = MIDIClientRef()
  private let time = BarBeatTime(clockSource: Sequencer.clockSource)
  private(set) var endPoint = MIDIEndpointRef()


  // MARK: - Initialization

  /**
  init:placement:instrument:note:

  - parameter t: TextureType
  - parameter p: Placement
  - parameter tr: Track
  - parameter n: Note
  */
  init(_ p: Placement, _ name: String) throws {
    placement = p
    textureType = MIDINode.currentTexture
    note = MIDINode.currentNote

    super.init(texture: MIDINode.currentTexture.texture,
               color: Sequencer.currentTrack.color.value,
               size: MIDINode.defaultSize)

    sourceID = ObjectIdentifier(self).uintValue.bytes

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
