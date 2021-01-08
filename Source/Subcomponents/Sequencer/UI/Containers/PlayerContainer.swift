//
//  PlayerContainer.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 1/7/16.
//  Copyright © 2016 Moondeer Studios. All rights reserved.
//
import Common
import Foundation
import MoonKit
import UIKit

// MARK: - PlayerContainer

/// `SecondaryControllerContainer` subclass whose primary controller is an instance of
/// `ViewController`. Any secondary content presented is provided by the various tools
/// owned by `NodePlayer`.
public final class PlayerContainer: SecondaryControllerContainer
{
  /// The primary controller.
  public private(set) weak var playerViewController: PlayerViewController!

  /// Overridden to update `playerViewController`.
  override public func prepare(for segue: UIStoryboardSegue, sender: Any?)
  {
    super.prepare(for: segue, sender: sender)

    playerViewController = segue.destination as? PlayerViewController
  }

  /// Overridden to stretch the blur across the player view when available.
  override public var blurFrame: CGRect
  {
    guard playerViewController?.isViewLoaded == true else { return super.blurFrame }
    return playerViewController!.playerView.frame
  }
}
