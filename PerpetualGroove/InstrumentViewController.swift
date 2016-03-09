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

  @IBOutlet weak var soundSetPicker: InlinePickerView!
  @IBOutlet weak var programPicker:  InlinePickerView!
  @IBOutlet weak var channelStepper: LabeledStepper!

  private let receptionist: NotificationReceptionist = {
    let receptionist = NotificationReceptionist(callbackQueue: NSOperationQueue.mainQueue())
    receptionist.logContext = LogManager.UIContext
    return receptionist
  }()

  /** awakeFromNib */
  override func awakeFromNib() {
    super.awakeFromNib()
    receptionist.observe(notification: .SoundSetSelectionTargetDidChange, from: Sequencer.self) {
      [weak self] in self?.instrument = $0.newSoundSetSelectionTarget
    }
    receptionist.observe(notification: .DidUpdateAvailableSoundSets,
                         from: Sequencer.self,
                         callback: weakMethod(self, InstrumentViewController.updateSoundSets))
  }

  /**
  updateSoundSets:

  - parameter notification: NSNotification
  */
  private func updateSoundSets(notification: NSNotification) { updateSoundSets() }

  /** updateSoundSets */
  private func updateSoundSets() {
    soundSetPicker.labels = Sequencer.soundSets.map { $0.displayName }
    instrument = Sequencer.soundSetSelectionTarget
  }


  /** didPickSoundSet */
  @IBAction func didPickSoundSet() {
    let soundSet = Sequencer.soundSets[soundSetPicker.selection]
    guard let instrument = instrument else { return }
    do {
      try instrument.loadSoundSet(soundSet, preset: soundSet.presets[0])
      programPicker.selection = 0
      programPicker.labels = soundSet.presets.map({$0.name})
      audition()
    } catch {
      logError(error)
    }
  }

  /** didPickProgram */
  @IBAction func didPickProgram() {
    guard let instrument = instrument else { return }
    do {
      try instrument.loadPreset(instrument.soundSet.presets[programPicker.selection])
      audition()
    } catch {
      logError(error)
    }
  }

  /** didChangeChannel */
  @IBAction func didChangeChannel() { instrument?.channel = UInt8(channelStepper.value) }


  func rollBackInstrument() {
    guard let instrument = instrument, initialSoundSet = initialSoundSet, initialPreset = initialPreset else {
      return
    }
    do { try instrument.loadSoundSet(initialSoundSet, preset: initialPreset) } catch { logError(error) }
  }

  private(set) var initialSoundSet: SoundSetType?
  private(set) var initialPreset: Instrument.Preset?

  private weak var instrument: Instrument? {
    didSet {
      guard let instrument = instrument,
             soundSetIndex = instrument.soundSet.index,
               presetIndex = instrument.soundSet.presets.indexOf(instrument.preset) where isViewLoaded()
      else { return }
      initialSoundSet = instrument.soundSet
      initialPreset = instrument.preset
      soundSetPicker.selectItem(soundSetIndex, animated: true)
      programPicker.labels = instrument.soundSet.presets.map({$0.name})
      programPicker.selectItem(presetIndex, animated: true)
      channelStepper.value = Double(instrument.channel)
    }
  }

  /** audition */
  private func audition() {
    guard let instrument = instrument else { return }
    instrument.playNote(MIDIGenerator(NoteGenerator()))
  }

  /** viewDidLoad */
  override func viewDidLoad() {
    super.viewDidLoad()
    guard Sequencer.initialized else { return }
    updateSoundSets()
  }

}
