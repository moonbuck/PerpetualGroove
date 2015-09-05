//
//  LabeledStepper.swift
//  MoonKit
//
//  Created by Jason Cardwell on 5/20/15.
//  Copyright (c) 2015 Jason Cardwell. All rights reserved.
//

import UIKit

@IBDesignable public class LabeledStepper: UIControl {

  /**
  initWithFrame:

  - parameter frame: CGRect
  */
  public override init(frame: CGRect) { super.init(frame: frame); initializeIVARs() }

  /**
  init:

  - parameter aDecoder: NSCoder
  */
  public required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder); initializeIVARs() }

  /** initializeIVARs */
  private func initializeIVARs() {
    addSubview(label); addSubview(stepper)

    label.textColor = textColor
    label.font = font
    label.textAlignment = .Right
    label.highlightedTextColor = highlightedTextColor
    updateLabel()

    stepper.setContentHuggingPriority(UILayoutPriorityRequired, forAxis: .Horizontal)
    stepper.addTarget(self, action: "updateLabel", forControlEvents: .ValueChanged)
  }

  /**
  requiresConstraintBasedLayout

  - returns: Bool
  */
  public override class func requiresConstraintBasedLayout() -> Bool { return true }

  /** updateConstraints */
  public override func updateConstraints() {
    super.updateConstraints()
    let id = Identifier(self, "Internal")
    guard constraintsWithIdentifier(id).count == 0 else { return }
    constrain([𝗛|label--8--stepper|𝗛, 𝗩|label|𝗩, [stepper.centerY => label.centerY]] --> id)
  }

  /**
  intrinsicContentSize

  - returns: CGSize
  */
  public override func intrinsicContentSize() -> CGSize {
    let lsize = label.intrinsicContentSize()
    let ssize = stepper.intrinsicContentSize()
    return CGSize(width: lsize.width + 8 + ssize.width, height: max(lsize.height, ssize.height))
  }


  // MARK: - Label

  private let label = UILabel(autolayout: true)

  /** updateLabel */
  @objc private func updateLabel() { label.text = String(stepper.value, precision: precision) }

  /** The number of characters from the fractional part of `stepper.value` to display, defaults to `0` */
  public var precision = 0 { didSet { updateLabel() } }

  // MARK: Properties bounced to/from `UILabel` subview

  public static let DefaultFont: UIFont = .preferredFontForTextStyle(UIFontTextStyleHeadline)
  public var font: UIFont = LabeledStepper.DefaultFont  { didSet { label.font = font } }

  @IBInspectable public var fontName: String  {
    get { return font.fontName }
    set { if let font = UIFont(name: newValue, size: self.font.pointSize) { self.font = font } }
  }

  @IBInspectable public var fontSize: CGFloat  {
    get { return font.pointSize }
    set { font = font.fontWithSize(newValue) }
  }

  @IBInspectable public var highlightedTextColor: UIColor? { didSet { label.highlightedTextColor = highlightedTextColor } }

  @IBInspectable public var textColor: UIColor = .blackColor() { didSet { label.textColor = textColor } }

  @IBInspectable public var shadowColor: UIColor? { didSet { label.shadowColor = shadowColor } }

  @IBInspectable public var shadowOffset: CGSize = .zero { didSet { label.shadowOffset = shadowOffset } }

  @IBInspectable public var adjustsFontSizeToFitWidth: Bool {
    get { return label.adjustsFontSizeToFitWidth }
    set { label.adjustsFontSizeToFitWidth = newValue }
  }

  @IBInspectable public var baselineAdjustment: UIBaselineAdjustment {
    get { return label.baselineAdjustment }
    set { label.baselineAdjustment = newValue }
  }

  @IBInspectable public var minimumScaleFactor: CGFloat { get { return label.minimumScaleFactor } set { label.minimumScaleFactor = newValue } }

  @IBInspectable public var preferredMaxLayoutWidth: CGFloat {
    get { return label.preferredMaxLayoutWidth }
    set { label.preferredMaxLayoutWidth = newValue }
  }

  // MARK: - Stepper

  private let stepper = UIStepper(autolayout: true)

  // MARK: Properties bounced to/from the `UIStepper` subview

  @IBInspectable public var continuous: Bool { get { return stepper.continuous } set { stepper.continuous = newValue } }
  @IBInspectable public var autorepeat: Bool { get { return stepper.autorepeat } set { stepper.autorepeat = newValue } }
  @IBInspectable public var wraps: Bool { get { return stepper.wraps } set { stepper.wraps = newValue } }

  @IBInspectable public var value: Double { get { return stepper.value } set { stepper.value = newValue; updateLabel() } }
  @IBInspectable public var minimumValue: Double { get { return stepper.minimumValue } set { stepper.minimumValue = newValue } }
  @IBInspectable public var maximumValue: Double { get { return stepper.maximumValue } set { stepper.maximumValue = newValue } }
  @IBInspectable public var stepValue: Double { get { return stepper.stepValue } set { stepper.stepValue = newValue } }

  @IBInspectable public override var enabled: Bool { get { return stepper.enabled } set { stepper.enabled = newValue } }
  @IBInspectable public override var selected: Bool { get { return stepper.selected } set { stepper.selected = newValue } }
  @IBInspectable public override var highlighted: Bool { get { return stepper.highlighted } set { stepper.highlighted = newValue } }

  public override var state: UIControlState { return stepper.state }

  @IBInspectable public override var contentVerticalAlignment: UIControlContentVerticalAlignment {
    get { return stepper.contentVerticalAlignment }
    set { stepper.contentVerticalAlignment = newValue }
  }

  @IBInspectable public override var contentHorizontalAlignment: UIControlContentHorizontalAlignment {
    get { return stepper.contentHorizontalAlignment }
    set { stepper.contentHorizontalAlignment = newValue }
  }

  // MARK: Methods bounced to the `UIStepper` subview

  public func setBackgroundImage(image: UIImage?, forState state: UIControlState) {
    stepper.setBackgroundImage(image, forState: state)
  }

  public func backgroundImageForState(state: UIControlState) -> UIImage? { return stepper.backgroundImageForState(state) }

  public func setDividerImage(image: UIImage?,
          forLeftSegmentState leftState: UIControlState,
            rightSegmentState rightState: UIControlState)
  {
    stepper.setDividerImage(image, forLeftSegmentState: leftState, rightSegmentState: rightState)
  }

  public func dividerImageForLeftSegmentState(lstate: UIControlState, rightSegmentState rstate: UIControlState) -> UIImage! {
    return stepper.dividerImageForLeftSegmentState(lstate, rightSegmentState: rstate)
  }

  public func setIncrementImage(image: UIImage?, forState state: UIControlState) {
    stepper.setIncrementImage(image, forState: state)
  }

  public func incrementImageForState(state: UIControlState) -> UIImage? { return stepper.incrementImageForState(state) }

  public func setDecrementImage(image: UIImage?, forState state: UIControlState) {
    stepper.setDecrementImage(image, forState: state)
  }

  public func decrementImageForState(state: UIControlState) -> UIImage? { return stepper.decrementImageForState(state) }

  public override var tracking: Bool { return stepper.tracking }
  public override var touchInside: Bool { return stepper.touchInside }

  public override func beginTrackingWithTouch(touch: UITouch, withEvent event: UIEvent?) -> Bool {
    return stepper.beginTrackingWithTouch(touch, withEvent: event)
  }
  public override func continueTrackingWithTouch(touch: UITouch, withEvent event: UIEvent?) -> Bool {
    return stepper.continueTrackingWithTouch(touch, withEvent: event)
  }
  public override func endTrackingWithTouch(touch: UITouch?, withEvent event: UIEvent?) {
    stepper.endTrackingWithTouch(touch, withEvent: event)
  }
  public override func cancelTrackingWithEvent(event: UIEvent?) {
    stepper.cancelTrackingWithEvent(event)
  }

  public override func addTarget(target: AnyObject?,
                          action: Selector,
                forControlEvents controlEvents: UIControlEvents)
  {
    stepper.addTarget(target, action: action, forControlEvents: controlEvents)
  }

  public override func removeTarget(target: AnyObject?,
                             action: Selector,
                   forControlEvents controlEvents: UIControlEvents)
  {
    stepper.removeTarget(target, action: action, forControlEvents: controlEvents)
  }

  public override func allTargets() -> Set<NSObject> { return stepper.allTargets() }
  public override func allControlEvents() -> UIControlEvents { return stepper.allControlEvents() }

  public override func actionsForTarget(target: AnyObject?,
                        forControlEvent controlEvent: UIControlEvents) -> [String]?
  {
    return stepper.actionsForTarget(target, forControlEvent: controlEvent)
  }

  public override func sendAction(action: Selector, to target: AnyObject?, forEvent event: UIEvent?) {
    stepper.sendAction(action, to: target, forEvent: event)
  }

  public override func sendActionsForControlEvents(controlEvents: UIControlEvents) {
    stepper.sendActionsForControlEvents(controlEvents)
  }

}
