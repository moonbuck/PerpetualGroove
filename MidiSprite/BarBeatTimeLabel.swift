//
//  BarBeatTimeLabel.swift
//  MidiSprite
//
//  Created by Jason Cardwell on 9/18/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import Foundation
import MoonKit
import struct AudioToolbox.CABarBeatTime

@IBDesignable final class BarBeatTimeLabel: UIView {

  @IBInspectable var font: UIFont = .largeDisplayFont { didSet { updateFont() } }
  private var _font: UIFont = .largeDisplayFont { didSet { setNeedsDisplay() } }

  @IBInspectable var fontColor: UIColor = .primaryColor

  @IBInspectable var bar: Int = 1 {
    didSet {
      guard bar != oldValue else { return }
      barString = String(bar, radix: 10, pad: 3)
    }
  }

  @IBInspectable var beat: Int = 1 {
    didSet {
      guard beat != oldValue else { return }
      beatString = String(beat)
    }
  }

  @IBInspectable var subbeat: Int = 1 {
    didSet {
      guard subbeat != oldValue else { return }
      subbeatString = String(subbeat, radix: 10, pad: 3)
    }
  }

  private var barString: NSString = "001" { didSet { setNeedsDisplayInRect(barFrame) } }
  private var beatString: NSString = "1" { didSet { setNeedsDisplayInRect(beatFrame) } }
  private var subbeatString: NSString = "001" { didSet { setNeedsDisplayInRect(subbeatFrame) } }
  private let barBeatDividerString: NSString = ":"
  private let beatSubbeatDividerString: NSString = "."

  private var barFrame: CGRect = .zero
  private var barBeatDividerFrame: CGRect = .zero
  private var beatFrame: CGRect = .zero
  private var beatSubbeatDividerFrame: CGRect = .zero
  private var subbeatFrame: CGRect = .zero

  override var bounds: CGRect { didSet { calculateFrames() } }

  /** calculateFrames */
  private func calculateFrames() {
    guard !bounds.isEmpty else {
      barFrame = .zero
      barBeatDividerFrame = .zero
      beatFrame = .zero
      beatSubbeatDividerFrame = .zero
      subbeatFrame = .zero
      return
    }
    let characterWidth = bounds.width / 9
    let height = bounds.height
    barFrame                = CGRect(x: 0,                  y: 0, width: characterWidth * 3, height: height)
    barBeatDividerFrame     = CGRect(x: characterWidth * 3, y: 0, width: characterWidth,     height: height)
    beatFrame               = CGRect(x: characterWidth * 4, y: 0, width: characterWidth,     height: height)
    beatSubbeatDividerFrame = CGRect(x: characterWidth * 5, y: 0, width: characterWidth,     height: height)
    subbeatFrame            = CGRect(x: characterWidth * 6, y: 0, width: characterWidth * 3, height: height)
    setNeedsDisplay()
  }

  /**
  drawRect:

  - parameter rect: CGRect
  */
  override func drawRect(rect: CGRect) {
    let attributes: [String:AnyObject] = [NSFontAttributeName: _font, NSForegroundColorAttributeName: fontColor]
    switch rect {
    case barFrame:                  barString.drawInRect(rect, withAttributes: attributes)
      case barBeatDividerFrame:     barBeatDividerString.drawInRect(rect, withAttributes: attributes)
      case beatFrame:               beatString.drawInRect(rect, withAttributes: attributes)
      case beatSubbeatDividerFrame: beatSubbeatDividerString.drawInRect(rect, withAttributes: attributes)
      case subbeatFrame:            subbeatString.drawInRect(rect, withAttributes: attributes)
      default: 
        barString.drawInRect(barFrame, withAttributes: attributes)
        barBeatDividerString.drawInRect(barBeatDividerFrame, withAttributes: attributes)
        beatString.drawInRect(beatFrame, withAttributes: attributes)
        beatSubbeatDividerString.drawInRect(beatSubbeatDividerFrame, withAttributes: attributes)
        subbeatString.drawInRect(subbeatFrame, withAttributes: attributes)      
    }
  }

  private var currentTime: CABarBeatTime = .start {
    didSet {
      guard currentTime != oldValue else { return }
      dispatchToMain {
        [unowned self, newValue = currentTime] in

        if oldValue.bar != newValue.bar         { self.bar = Int(newValue.bar)         }
        if oldValue.beat != newValue.beat       { self.beat = Int(newValue.beat)       }
        if oldValue.subbeat != newValue.subbeat { self.subbeat = Int(newValue.subbeat) }
      }
    }
  }
  private var barBeatTimeCallbackKey: String { return String(ObjectIdentifier(self).uintValue) }

  private var receptionist: NotificationReceptionist!

  private var characterSize: CGSize {
    return "0123456789:.".characters.reduce(.zero) {[attributes = [NSFontAttributeName: font]] in
      let s = (String($1) as NSString).sizeWithAttributes(attributes)
      return CGSize(width: max($0.width, s.width), height: max($0.height, s.height))
    }
  }

  /** updateFont */
  private func updateFont() { _font = font.fontWithSize((characterSize.width / (bounds.width / 9)) * font.pointSize) }

  /**
  intrinsicContentSize

  - returns: CGSize
  */
  override func intrinsicContentSize() -> CGSize {
    return CGSize(width: characterSize.width * 9, height: characterSize.height).integralSize
  }

  /**
  didUpdateBarBeatTime:

  - parameter time: CABarBeatTime
  */
  private func didUpdateBarBeatTime(time: CABarBeatTime) { currentTime = time }

  /**
  didJog:

  - parameter notification: NSNotification
  */
  private func didJog(notification: NSNotification) {
    guard let time = (notification.userInfo?[Sequencer.Notification.Key.JogTime.rawValue] as? NSValue)?.barBeatTimeValue else {
      logError("notification does not contain a time for updating")
      return
    }
    didUpdateBarBeatTime(time)
  }

  /**
  didReset:

  - parameter notification: NSNotification
  */
  private func didReset(notification: NSNotification) {
    guard let time = (notification.userInfo?[Sequencer.Notification.Key.Time.rawValue] as? NSValue)?.barBeatTimeValue else {
      logError("notification does not contain a time for updating")
      return
    }
    didUpdateBarBeatTime(time)
  }

  /** setup */
  private func setup() {

    calculateFrames()

    #if !TARGET_INTERFACE_BUILDER
      Sequencer.time.registerCallback(didUpdateBarBeatTime,
                                   predicate: {_ in true},
                                      forKey: barBeatTimeCallbackKey)

      let queue = NSOperationQueue.mainQueue()
      let object = Sequencer.self
      typealias Notification = Sequencer.Notification
      receptionist = NotificationReceptionist()
      receptionist?.observe(Notification.DidJog, from: object, queue: queue, callback: didJog)
      receptionist?.observe(Notification.DidReset, from: object, queue: queue, callback: didReset)
    #endif

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