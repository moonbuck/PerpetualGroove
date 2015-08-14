//
//  MIDIPlayerNode.swift
//  MidiSprite
//
//  Created by Jason Cardwell on 8/12/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import UIKit
import SpriteKit
import MoonKit
import typealias AudioToolbox.MusicDeviceGroupID

class MIDIPlayerNode: SKShapeNode {

  // MARK: - Initialization

  /**
  initWithBezierPath:

  - parameter bezierPath: UIBezierPath
  */
  init(bezierPath: UIBezierPath) {
    super.init()
    name = "player"
    path = bezierPath.CGPath
    strokeColor = UIColor(red: 0.502, green: 0.502, blue: 0.502, alpha: 1.0)
    guard let path = path else { return }
    physicsBody = SKPhysicsBody(edgeLoopFromPath: path)
    physicsBody?.categoryBitMask = 1
    physicsBody?.contactTestBitMask = 0xFFFFFFFF
    addChild(MIDIPlayerFieldNode(bezierPath: bezierPath, delegate: self))
  }

  private var midiNodes: [MIDINode] = []

  /**
  init:

  - parameter aDecoder: NSCoder
  */
  required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }


  // MARK: - Manipulating MIDINodes

  var soundSet = SoundSet.PureOscillators
  var program: UInt8 = 0
  var channel: MusicDeviceGroupID = 0
  var note = Instrument.Note()
  var textureType = MIDINode.TextureType.PlasticWrap

  /** dropLast */
  func dropLast() {
    guard midiNodes.count > 0 else { return }

    let node = midiNodes.removeLast()
    if let _ = node.actionForKey(MIDINode.Actions.Play.rawValue) {
      node.removeActionForKey(MIDINode.Actions.Play.rawValue)
      do { try node.instrument.stopNoteForNode(node) } catch { logError(error) }
    }
    node.removeFromParent()
  }

  /** reset */
  func reset() {
    midiNodes.forEach {
      if let _ = $0.actionForKey(MIDINode.Actions.Play.rawValue) {
        $0.removeActionForKey(MIDINode.Actions.Play.rawValue)
        do { try $0.instrument.stopNoteForNode($0) } catch { logError(error) }
      }
      $0.removeFromParent()
    }
    midiNodes.removeAll()
  }

  /**
  placeNew:

  - parameter placement: MIDINode.Placement
  */
  func placeNew(placement: MIDINode.Placement) {
    guard let controller = UIApplication.sharedApplication().keyWindow?.rootViewController
                             as? MIDIPlayerSceneViewController else { return }
    if !controller.playing { controller.play() }
    var instrument = MIDIManager.connectedInstrumentWithSoundSet(soundSet, program: program, channel: channel)
    if instrument == nil {
      do { instrument = try Instrument(soundSet: soundSet, program: program, channel: channel) } catch { logError(error) }
    }

    guard instrument != nil else { return }
    let midiNode = MIDINode(texture: textureType, placement: placement, instrument: instrument!, note: note)
    midiNode.name = "midiNode\(midiNodes.count)"
    addChild(midiNode)
    midiNodes.append(midiNode)
  }

}
