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

class MIDINode: SKSpriteNode {

  enum TextureType: String, EnumerableType {
    case Brick, Cobblestone, Concrete, Crusty, DiamondPlate, Dirt, Fur, Glass,
         Mountains, OceanBasin, Parchment, PlasticWrap, Sand, Stucco, Water
    var image: UIImage { return UIImage(named: rawValue.lowercaseString)! }
    var texture: SKTexture { return TextureType.atlas.textureNamed(rawValue.lowercaseString) }
    static let atlas = SKTextureAtlas(named: "balls")
    static let allCases: [TextureType] = [.Brick, .Cobblestone, .Concrete, .Crusty, .DiamondPlate, .Dirt, .Fur, .Glass,
                                          .Mountains, .OceanBasin, .Parchment, .PlasticWrap, .Sand, .Stucco, .Water]
  }

  var textureType: TextureType

  static var defaultSize = CGSize(square: 32)

  typealias Note = Instrument.Note

  var note: Note

  var instrument: Instrument

  struct Placement { let position: CGPoint; let vector: CGVector }

  var placement: Placement

  let id = nonce()

  /** play */
  func play() {
    let halfDuration = note.duration * 0.5
    let scaleUp = SKAction.scaleTo(2, duration: halfDuration)
    let noteOn = SKAction.runBlock({ [weak self] in do { try self?.instrument.playNoteForNode(self!) } catch { logError(error) } })
    let scaleDown = SKAction.scaleTo(1, duration: halfDuration)
    let noteOff = SKAction.runBlock({ [weak self] in do { try self?.instrument.stopNoteForNode(self!) } catch { logError(error) } },
                              queue: MIDIManager.queue)
    let sequence = SKAction.sequence([SKAction.group([scaleUp, noteOn]), scaleDown, noteOff])
    runAction(sequence)
  }



  /**
  init:placement:instrument:note:

  - parameter t: TextureType
  - parameter p: Placement
  - parameter i: Instrument
  - parameter n: Note
  */
  init(texture t: TextureType, placement p: Placement, instrument i: Instrument, note n: Note) {
    textureType = t
    placement = p
    instrument = i
    note = n
    super.init(texture: t.texture, color: .clearColor(), size: MIDINode.defaultSize)
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

  /**
  init:

  - parameter aDecoder: NSCoder
  */
  required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

}
