//
//  InstrumentViewController.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 8/19/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import UIKit
import MoonKit

final class InstrumentViewController: UIViewController, SecondaryControllerContent {

  @IBOutlet weak var soundSetPicker: SoundFontSelector!
  @IBOutlet weak var programPicker:  ProgramSelector!
  @IBOutlet weak var channelStepper: LabeledStepper!

  fileprivate let receptionist: NotificationReceptionist = {
    let receptionist = NotificationReceptionist(callbackQueue: OperationQueue.main)
    receptionist.logContext = LogManager.UIContext
    return receptionist
  }()

  override func awakeFromNib() {
    super.awakeFromNib()
    receptionist.observe(name: Sequencer.NotificationName.didUpdateAvailableSoundSets.rawValue,
                         from: Sequencer.self,
                         callback: weakMethod(self, InstrumentViewController.updateSoundSets))
  }

  fileprivate func updateSoundSets(_ notification: Notification) { updateSoundSets() }

  fileprivate func updateSoundSets() {
    soundSetPicker.refresh()
  }


  @IBAction func didPickSoundSet() {
    guard let instrument = instrument else { return }
    let soundFont = Sequencer.soundSets[soundSetPicker.selection]
    let preset = Instrument.Preset(soundFont: soundFont, presetHeader: soundFont[0], channel: 0)

    do {
      try instrument.loadPreset(preset)
      programPicker.selection = 0
      programPicker.soundFont = soundFont
      audition()
    } catch {
      Log.error(error)
    }
  }

  @IBAction func didPickProgram() {
    guard let instrument = instrument else { return }
    let soundSet = instrument.soundFont
    let presetHeader = soundSet.presetHeaders[programPicker.selection]
    let preset = Instrument.Preset(soundFont: soundSet, presetHeader: presetHeader, channel: 0)
    do {
      try instrument.loadPreset(preset)
      audition()
    } catch {
      Log.error(error)
    }
  }

  @IBAction func didChangeChannel() { instrument?.channel = UInt8(channelStepper.value) }


  func rollBackInstrument() {
    guard let instrument = instrument, let initialPreset = initialPreset else {
      return
    }
    do { try instrument.loadPreset(initialPreset) } catch { Log.error(error) }
  }

  fileprivate(set) var initialPreset: Instrument.Preset?

  weak var instrument: Instrument? {
    didSet {
      guard let instrument = instrument,
        let soundSetIndex = instrument.soundFont.index,
        let presetIndex = instrument.soundFont.presetHeaders.index(of: instrument.preset.presetHeader),
        isViewLoaded
      else { return }

      initialPreset = instrument.preset
      soundSetPicker.selectItem(soundSetIndex, animated: true)
      programPicker.soundFont = instrument.soundFont
      programPicker.selectItem(presetIndex, animated: true)
      channelStepper.value = Double(instrument.channel)
    }
  }

  fileprivate func audition() {
    guard let instrument = instrument else { return }
    instrument.playNote(AnyMIDIGenerator())
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    guard Sequencer.initialized else { return }
    updateSoundSets()
  }

}

final class SoundFontSelector: InlinePickerContainer {

  override func refresh(picker: InlinePickerView) {
    items = Sequencer.soundSets.map { $0.displayName }
  }

  override class var contentForInterfaceBuilder: [Any] {
    return [
      "Emax Volume 1",
      "Emax Volume 2",
      "Emax Volume 3",
      "Emax Volume 4",
      "Emax Volume 5",
      "Emax Volume 6",
      "SPYRO's Pure Oscillators"
    ]
  }
  
}

final class ProgramSelector: InlinePickerContainer {

  override class var contentForInterfaceBuilder: [Any] {
    return [
      "Pop Brass",
      "Trombone",
      "TromSection",
      "C Trumpet",
      "D Trumpet",
      "Trumpet"
    ]
  }

  override func refresh(picker: InlinePickerView) {
    items = soundFont?.presetHeaders.map { $0.name } ?? []
  }

  var soundFont: SoundFont? {
    didSet {
      refresh()
    }
  }
  
}
