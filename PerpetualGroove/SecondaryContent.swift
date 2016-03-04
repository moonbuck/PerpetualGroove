//
//  SecondaryContent.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 2/18/16.
//  Copyright © 2016 Moondeer Studios. All rights reserved.
//

import Foundation
import MoonKit

class SecondaryContent: UIViewController, SecondaryControllerContent {

  var anyAction: (() -> Void)? = nil
  var cancelAction: (() -> Void)? = nil
  var confirmAction: (() -> Void)? = nil
  var nextAction: (() -> Void)? = nil
  var previousAction: (() -> Void)? = nil

  var supportedActions: SecondaryControllerContainer.SupportedActions = [.Cancel, .Confirm]
  var disabledActions: SecondaryControllerContainer.SupportedActions = .None
}