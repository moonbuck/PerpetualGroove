//
//  MIDIPlayerView.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 9/24/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import UIKit
import SpriteKit
import MoonKit

final class MIDIPlayerView: SKView {

  var playerScene: MIDIPlayerScene? { return scene as? MIDIPlayerScene }

  /** setup */
  fileprivate func setup() {
    ignoresSiblingOrder = true
    shouldCullNonVisibleNodes = false
    showsFPS = true
    showsNodeCount = true
    presentScene(MIDIPlayerScene(size: bounds.size))
  }

  /**
  initWithFrame:

  - parameter frame: CGRect
  */
  override init(frame: CGRect) { super.init(frame: frame); setup() }

  /**
  init:

  - parameter aDecoder: NSCoder
  */
  required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder); setup() }
}
