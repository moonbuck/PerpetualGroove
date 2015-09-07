//
//  AssetManager.swift
//  MidiSprite
//
//  Created by Jason Cardwell on 8/17/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import Foundation
import UIKit
import MoonKit
import Chameleon
import Eveleth

extension UIColor {
  static var labelTextColor: UIColor          { return Chameleon.kelleyPearlBush }
  static var controlColor: UIColor            { return Chameleon.quietLightLobLollyDark }
  static var controlSelectedColor: UIColor    { return Chameleon.quietLightLobLolly }
  static var tintColor: UIColor               { return Chameleon.quietLightLilyWhiteDark }
  static var backgroundColor: UIColor         { return rgb(51, 50, 49) }
  static var popoverBackgroundColor: UIColor  { return rgb(44, 37, 31) }
  static var strokeColor: UIColor             { return UIColor(white: 0.502, alpha: 1) }
}

extension UIFont {
  static var labelFont: UIFont              { return Eveleth.lightFontWithSize(14) }
  static var controlFont: UIFont            { return Eveleth.thinFontWithSize(14) }
  static var controlSelectedFont: UIFont    { return Eveleth.regularFontWithSize(14) }
}


extension CGFloat {
  static var popoverArrowWidth: CGFloat { return 20 }
  static var popoverArrowHeight: CGFloat { return 20 }
}