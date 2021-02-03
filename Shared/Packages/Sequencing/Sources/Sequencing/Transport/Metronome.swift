//
//  Metronome.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 8/28/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//
import class AVFoundation.AVAudioUnitSampler
import Foundation
import MIDI
import MoonDev

/// A class that plays a note at the start of each beat.
@available(iOS 14.0, *)
public final class Metronome: ObservableObject
{
  /// The instrument used to produce the metronome's sound.
  let sampler: AVAudioUnitSampler
  
  /// The MIDI channel over which the metronome's note events are sent.
  public var channel: UInt8 = 0
  
  /// Whether the metronome is currently producing note events. Changing the
  /// value of this property causes a callback to be registered with or removed
  /// from the current instance of `Time` according to whether the new value is
  /// `true` or `false`.
  @Published public var isOn = false
  {
    didSet
    {
      guard oldValue != isOn else { return }
      
      switch isOn
      {
        case true:
          Sequencer.shared.time.register(
            callback: weakCapture(of: self, block: Metronome.click),
            predicate: Metronome.isAudibleTick,
            identifier: callbackIdentifier
          )
        case false:
          Sequencer.shared.time.removePredicatedCallback(with: callbackIdentifier)
      }
    }
  }
  
  /// Initializing with an audio unit.
  /// - Throws: Any error encountered while attempting to load the metronome's audio file.
  public init(sampler: AVAudioUnitSampler)
  {
    /// Initialize the metronome's sampler.
    self.sampler = sampler
    
    /// Get the url for file to load into the sampler.
    let url = unwrapOrDie(
      message: "Failed to get url for 'Woodblock.wav'",
      Bundle.module.url(forResource: "Woodblock", withExtension: "wav")
    )
    
    /// Load the file into the sampler.
    tryOrDie { try sampler.loadAudioFiles(at: [url]) }
  }
  
  /// Identifier used when registering and removing callbacks.
  private let callbackIdentifier = UUID()
  
  /// Callback registered with the current instance of `Time`. The predicate with
  /// which this callback is registered ensures that the subbeat of `time` is always
  /// `1`. When the current transport is playing, a note is played using `sampler`
  /// with a velocity equal to `64`. If the beat is equal to `1` then a C4 note is
  /// played; otherwise, a G3 note is played.
  private func click(_ time: BarBeatTime)
  {
    // Check that the transport is playing.
    guard Sequencer.shared.transport.isPlaying else { return }
    
    // Play a C4 or G3 over `channel` according to whether this is the first beat
    // of the bar.
    sampler.startNote(time.beat == 1 ? 0x3C : 0x37, withVelocity: 64, onChannel: channel)
  }
  
  /// Returns whether the `subbeat` property of `time` has a value equal to `1`.
  /// This method is supplied when registering callbacks with an instance of `Time`
  /// so that the callback is only invoked at the start of a beat.
  private static func isAudibleTick(_ time: BarBeatTime) -> Bool
  {
    time.subbeat == 1
  }
}