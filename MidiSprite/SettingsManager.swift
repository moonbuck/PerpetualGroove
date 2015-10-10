//
//  SettingsManager.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 10/9/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import Foundation
import MoonKit


final class SettingsManager {

  enum Setting: String, KeyType, EnumerableType {
    case iCloudStorage = "iCloudStorage"
    case ConfirmDelete = "confirmDelete"
    case ScrollTrackLabels = "scrollTrackLabels"
    case CurrentDocument = "currentDocument"

    var currentValue: Any? {
      guard let value = NSUserDefaults.standardUserDefaults().objectForKey(rawValue) else { return nil }

           if let number = value as? NSNumber { return number }
      else if let data   = value as? NSData   { return data   }
      else                                    { return nil    }
    }

    static var boolSettings: [Setting] { return [.iCloudStorage, .ConfirmDelete, .ScrollTrackLabels] }
    static var allCases: [Setting] {
      return [.iCloudStorage, .ConfirmDelete, .ScrollTrackLabels, .CurrentDocument]
    }
  }

  private static var settingsCache: [Setting:Any] = [:]
  private static var initialized = false


  struct Notification: NotificationType {

    enum Name: String, NotificationNameType {
      case iCloudStorageChanged, ConfirmDeleteChanged, ScrollTrackLabelsChanged, CurrentDocumentChanged
    }

    enum Key: String, KeyType { case OldValue, NewValue }

    var object: AnyObject? { return SettingsManager.self }
    let name: Name
    let userInfo: [Key:AnyObject?]?

    /**
    init:

    - parameter setting: Setting
    */
    init(_ setting: Setting) {
      userInfo = [.OldValue: SettingsManager.settingsCache[setting] as? AnyObject,
                  .NewValue: setting.currentValue as? AnyObject]
      switch setting {
        case .iCloudStorage:     name = .iCloudStorageChanged
        case .ConfirmDelete:     name = .ConfirmDeleteChanged
        case .ScrollTrackLabels: name = .ScrollTrackLabelsChanged
        case .CurrentDocument:   name = .CurrentDocumentChanged
      }
    }

  }

  /**
  userDefaultsDidChange:

  - parameter notification: NSNotification
  */
  private static func userDefaultsDidChange(notification: NSNotification) {
    let changedSettings: [Setting] = Setting.allCases.filter {
      switch ($0.currentValue, SettingsManager.settingsCache[$0]) {
        case let (current?, previous?):
          if let currentNumber = current as? NSNumber, previousNumber = previous as? NSNumber {
            return currentNumber == previousNumber
          } else if let currentData = current as? NSData, previousData = previous as? NSData {
            return currentData == previousData
          } else {
            return false
          }
        case (.Some, .None), (.None, .Some): return true
        default: return false
      }
    }

    for setting in changedSettings {
      Notification(setting).post()
      settingsCache[setting] = setting.currentValue
    }
  }

  static var iCloudStorage: Bool {
    get { return settingsCache[Setting.iCloudStorage] as! Bool }
    set { NSUserDefaults.standardUserDefaults().setBool(newValue, forKey: Setting.iCloudStorage.key) }
  }

  static var confirmDelete: Bool {
    get { return settingsCache[Setting.ConfirmDelete] as! Bool }
    set { NSUserDefaults.standardUserDefaults().setBool(newValue, forKey: Setting.ConfirmDelete.key) }
  }

  static var scrollTrackLabels: Bool {
    get { return settingsCache[Setting.ScrollTrackLabels] as! Bool }
    set { NSUserDefaults.standardUserDefaults().setBool(newValue, forKey: Setting.ScrollTrackLabels.key) }
  }

  static var currentDocument: NSData? {
    get { return settingsCache[Setting.CurrentDocument] as? NSData }
    set { NSUserDefaults.standardUserDefaults().setObject(newValue, forKey: Setting.CurrentDocument.key) }
  }

  private static let notificationReceptionist: NotificationReceptionist = {
    let receptionist = NotificationReceptionist()
    receptionist.observe(NSUserDefaultsDidChangeNotification,
                    from: NSUserDefaults.standardUserDefaults(),
                   queue: NSOperationQueue.mainQueue(),
                callback: SettingsManager.userDefaultsDidChange)
    return receptionist
    }()

  /** initialize */
  static func initialize() {
    guard !initialized else { return }

    NSUserDefaults.standardUserDefaults().registerDefaults(Setting.boolSettings.reduce([String:AnyObject]()) {
      (var dict: [String:AnyObject], setting: Setting) in

      dict[setting.key] = true
      return dict

      })

    Setting.allCases.forEach { SettingsManager.settingsCache[$0] = $0.currentValue }

    let _ = notificationReceptionist
    initialized = true
  }
  
}