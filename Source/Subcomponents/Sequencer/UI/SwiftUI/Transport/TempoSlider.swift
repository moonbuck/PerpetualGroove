//
//  TempoSlider.swift
//  Sequencer
//
//  Created by Jason Cardwell on 1/11/21.
//  Copyright © 2021 Moondeer Studios. All rights reserved.
//
import Combine
import MoonKit
import SwiftUI

// MARK: - TempoSlider

/// A view wrapping a hosted instance of `MoonKit.Slider` for controlling the
/// transport's tempo setting.
struct TempoSlider: View
{
  /// The tempo value kept in sync with `transport.tempo`.
  @State private var tempo: UInt16 = transport.tempo

  /// The view's body is composed of the slider host constrained to 330w x 44h.
  var body: some View
  {
    SliderHost(value: $tempo, valueChangedAction: UIAction
    {
      transport.tempo = UInt16(($0.sender as! MoonKit.Slider).value)
    })
      .frame(width: 300, height: 44)
  }

  /// Holds the subscription for tempo changes.
  private var tempoSubscription: Cancellable?

  /// Initializer configures the tempo value change subscription.
  init()
  {
    tempoSubscription = transport.$tempo.assign(to: \.tempo, on: self)
  }
}

// MARK: - SliderHost

/// A wrapper for an instance of `MoonKit.Slider` configured for use as a tempo slider.
private struct SliderHost: UIViewRepresentable
{
  /// The backing value for the slider.
  @Binding var value: UInt16

  /// The value change action for the hosted slider.
  let valueChangedAction: UIAction

  /// Builds and returns the hosted slider.
  ///
  /// - Parameter context: This parameter is ignored.
  /// - Returns: The hosted slider.
  func makeUIView(context: Context) -> MoonKit.Slider
  {
    let thumbImage = UIImage(named: "horizontal_thumb", in: bundle, with: nil)!
    let height = thumbImage.size.height
    let slider = MoonKit.Slider(frame: CGRect(size: CGSize(width: 300, height: height)))
    slider.backgroundColor = .clear
    slider.addAction(valueChangedAction, for: .valueChanged)
    slider.thumbImage = thumbImage
    slider.trackMinImage = UIImage(named: "horizontal_track", in: bundle, with: nil)
    slider.trackMaxImage = UIImage(named: "horizontal_track", in: bundle, with: nil)
    slider.thumbColor = UIColor(named: "thumbColor", in: bundle, compatibleWith: nil)!
    slider.trackMinColor = UIColor(named: "trackMinColor",
                                   in: bundle,
                                   compatibleWith: nil)!
    slider.trackMaxColor = UIColor(named: "trackMaxColor",
                                   in: bundle,
                                   compatibleWith: nil)!
    slider.minimumValue = 24
    slider.maximumValue = 400
    slider.value = Float(value)
    slider.valueLabelTextColor = UIColor(named: "valueLabelTextColor",
                                         in: bundle,
                                         compatibleWith: nil)!
    slider.showsValueLabel = true
    slider.valueLabelPrecision = 0
    slider.valueLabelFontName = "EvelethRegular"
    slider.valueLabelFontSize = 12
    slider.continuous = false
    slider.trackLabelText = "Tempo"
    slider.trackLabelFontName = "EvelethLight"
    slider.trackLabelFontSize = 13
    slider.showsTrackLabel = true
    slider.identifier = "TempoSlider"
    slider.trackAlignment = .bottomOrRight
    slider.thumbAlignment = .center
    slider.valueLabelAlignment = .top
    slider.valueLabelVerticalOffset = 6
    slider.trackLabelVerticalOffset = 1

    return slider
  }

  /// Updates the hosted slider with the current value of `value`.
  /// - Parameters:
  ///   - uiView: The hosted slider.
  ///   - context: This parameter is ignored.
  func updateUIView(_ uiView: MoonKit.Slider, context: Context)
  {
    uiView.value = Float(value)
  }
}

// MARK: - TempoSlider_Previews

struct TempoSlider_Previews: PreviewProvider
{
  static var previews: some View
  {
    TempoSlider()
      .previewLayout(.sizeThatFits)
      .preferredColorScheme(.dark)
      .padding()
  }
}
