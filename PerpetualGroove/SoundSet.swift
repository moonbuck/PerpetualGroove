//
//  SoundSet.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 8/13/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import Foundation
import MoonKit
import AudioUnit.AudioUnitProperties

/** Wrapper for a sound font file */
struct SoundSet: SoundSetType {
  
  let url: NSURL
  var fileName: String { return (url.lastPathComponent?.baseNameExt.0)! }

  let presets: [SF2File.Preset]

  var image: UIImage { return UIImage(named: "oscillator")! }
  var selectedImage: UIImage { return UIImage(named: "oscillator-selected")! }

  /**
  Initialize a sound set using the file located by the specified url.

  - parameter u: NSURL
  */
  init(url u: NSURL) throws {
    var error: NSError?
    guard u.checkResourceIsReachableAndReturnError(&error) else { throw error! }
    presets = try SF2File(file: u).presets.sort()
    url = u
  }

}
