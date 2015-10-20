//
//  LabelButton.swift
//  MoonKit
//
//  Created by Jason Cardwell on 5/23/15.
//  Copyright (c) 2015 Jason Cardwell. All rights reserved.
//

import UIKit

@IBDesignable
public class LabelButton: ToggleControl {

  public typealias Action = (LabelButton) -> Void

  /**
  intrinsicContentSize

  - returns: CGSize
  */
  public override func intrinsicContentSize() -> CGSize {
    return text?.sizeWithAttributes([NSFontAttributeName: font]) ?? CGSize(square: UIViewNoIntrinsicMetric)
  }

  public var actions: [Action] = []

  /**
  sendActionsForControlEvents:

  - parameter controlEvents: UIControlEvents
  */
  public override func sendActionsForControlEvents(controlEvents: UIControlEvents) {
    super.sendActionsForControlEvents(controlEvents)
    if controlEvents ∋ .TouchUpInside { actions.forEach({ $0(self) }) }
  }

  // MARK: - Wrapping Label

  @IBInspectable public var text: String? {
    didSet { guard text != oldValue else { return }; invalidateIntrinsicContentSize(); setNeedsDisplay() }
  }

  public var font: UIFont = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline) {
    didSet { invalidateIntrinsicContentSize(); setNeedsDisplay() }
  }

  @objc @IBInspectable private var fontName: String {
    get { return font.fontName }
    set { if let font = UIFont(name: newValue, size: font.pointSize) { self.font = font } }
  }

  @objc @IBInspectable private var fontSize: CGFloat {
    get { return font.pointSize }
    set { font = font.fontWithSize(newValue) }
  }

  /**
  drawRect:

  - parameter rect: CGRect
  */
  public override func drawRect(rect: CGRect) {
    guard let text = text else { return }
    text.drawInRect(rect, withAttributes: [NSFontAttributeName: font, NSForegroundColorAttributeName: tintColor])
  }

}
