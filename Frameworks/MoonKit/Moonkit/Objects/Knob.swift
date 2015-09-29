//
//  Knob.swift
//  MoonKit
//
//  Created by Jason Cardwell on 8/31/15.
//  Copyright © 2015 Jason Cardwell. All rights reserved.
//

import Foundation
import UIKit

@IBDesignable public class Knob: UIControl {

  @IBInspectable public var value: Float = 0.5 {
    didSet {
      guard oldValue != value else { return }
      value = valueInterval.clampValue(value)
      setNeedsDisplay()
    }
  }

  @IBInspectable public var minimumValue: Float {
    get { return valueInterval.start }
    set {
      guard valueInterval.start != newValue || newValue > valueInterval.end else { return }
      valueInterval = newValue ... valueInterval.end
    }
  }

  @IBInspectable public var maximumValue: Float {
    get { return valueInterval.end }
    set {
      guard valueInterval.end != newValue || newValue < valueInterval.start else { return }
      valueInterval = valueInterval.start ... newValue
    }
  }

  @IBInspectable public var knobBase: UIImage? {
    didSet {
      guard oldValue != value else { return }
      if let knobBase = knobBase { self.knobBase = knobBase.imageWithColor(knobColor) }
      setNeedsDisplay()
    }
  }

  @IBInspectable public var indicatorImage: UIImage? {
    didSet {
      guard indicatorImage != oldValue && !indicatorColorModified else { return }
      indicatorImage = indicatorImage?.imageWithColor(indicatorColor)
      setNeedsDisplay()
    }
  }
  @IBInspectable public var indicatorFillImage: UIImage? {
    didSet {
      guard indicatorFillImage != oldValue && !indicatorColorModified else { return }
      indicatorFillImage = indicatorFillImage?.imageWithColor(indicatorColor)
      setNeedsDisplay()
    }
  }

  private var previousRotation: CGFloat = 0
  private weak var rotationGesture: UIRotationGestureRecognizer?
  private let rotationInterval: ClosedInterval<CGFloat> = -π / 2 ... π / 2

  /**
  intrinsicContentSize

  - returns: CGSize
  */
  public override func intrinsicContentSize() -> CGSize {
    return knobBase?.size ?? CGSize(square: 44)
  }

  /**
  addTarget:action:forControlEvents:

  - parameter target: AnyObject?
  - parameter action: Selector
  - parameter controlEvents: UIControlEvents
  */
  override public func addTarget(target: AnyObject?, action: Selector, forControlEvents controlEvents: UIControlEvents) {
    super.addTarget(target, action: action, forControlEvents: controlEvents)
    guard self.rotationGesture == nil else { return }
    let rotationGesture = UIRotationGestureRecognizer(target: self, action: "didRotate")
    addGestureRecognizer(rotationGesture)
    self.rotationGesture = rotationGesture
  }

  /**
  didRotate:

  - parameter gesture: UIRotationGestureRecognizer
  */
  @objc private func didRotate() {
    guard let rotationGesture = rotationGesture else { return }
    let currentRotation = rotationInterval.clampValue(rotationGesture.rotation)
    guard currentRotation != previousRotation else { return }
    value = valueInterval.valueForNormalizedValue(Float(rotationInterval.normalizeValue(currentRotation)))
    previousRotation = currentRotation
  }

  @IBInspectable public var knobColor: UIColor = .darkGrayColor() {
    didSet {
      knobBase = knobBase?.imageWithColor(knobColor)
      setNeedsDisplay()
    }
  }

  private var indicatorColorModified = false
  @IBInspectable public var indicatorColor: UIColor = .lightGrayColor() {
    didSet {
      guard indicatorColor != oldValue else { return }
      indicatorColorModified = true
      indicatorImage = indicatorImage?.imageWithColor(indicatorColor)
      indicatorFillImage = indicatorFillImage?.imageWithColor(indicatorColor)
      indicatorColorModified = false
      setNeedsDisplay()
    }
  }

  private var valueInterval: ClosedInterval<Float> = 0 ... 1 { didSet { value = valueInterval.clampValue(value) } }

  // MARK: - Styles

  public var indicatorStyle: CGBlendMode = .Normal {
    didSet {
      guard indicatorStyle != oldValue else { return }
      setNeedsDisplay()
    }
  }

  public var indicatorFillStyle: CGBlendMode = .Normal {
    didSet {
      guard indicatorFillStyle != oldValue else { return }
      setNeedsDisplay()
    }
  }

  @IBInspectable public var indicatorStyleString: String {
    get { return indicatorStyle.stringValue }
    set { indicatorStyle = CGBlendMode(stringValue: newValue) }
  }

  @IBInspectable public var indicatorFillStyleString: String {
    get { return indicatorFillStyle.stringValue }
    set { indicatorFillStyle = CGBlendMode(stringValue: newValue) }
  }

  /**
  drawRect:

  - parameter rect: CGRect
  */
  public override func drawRect(rect: CGRect) {

    let context = UIGraphicsGetCurrentContext()
    CGContextSaveGState(context)
    CGContextTranslateCTM(context, half(rect.width), half(rect.height))
    CGContextRotateCTM(context, π * CGFloat(valueInterval.normalizeValue(value)) + π)
    CGContextTranslateCTM(context, -half(rect.width), -half(rect.height))

    let baseFrame = rect.centerInscribedSquare

    if let knobBase = knobBase {
      knobBase.drawInRect(baseFrame)
    } else {
      knobColor.setFill()
      UIBezierPath(ovalInRect: baseFrame).fill()
    }

    if let indicator = indicatorImage, indicatorFill = indicatorFillImage {
      indicator.drawInRect(baseFrame, blendMode: indicatorStyle, alpha: 1)
      indicatorFill.drawInRect(baseFrame, blendMode: indicatorFillStyle, alpha: 1)

    } else {
      let indicatorPath = UIBezierPath()
      indicatorPath.addArcWithCenter(baseFrame.center,
                              radius: half(baseFrame.width),
                          startAngle: π / 20,
                            endAngle: -π / 20,
                           clockwise: false)
      indicatorPath.addLineToPoint(baseFrame.center)
      indicatorPath.closePath()

      indicatorColor.setFill()
      indicatorPath.fillWithBlendMode(indicatorFillStyle, alpha: 1)
      indicatorPath.lineWidth = 2
      indicatorPath.lineJoinStyle = .Bevel
      indicatorColor.setStroke()
      indicatorPath.strokeWithBlendMode(indicatorStyle, alpha: 1)
    }

    CGContextRestoreGState(context)
  }

}