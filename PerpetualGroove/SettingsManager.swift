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

  fileprivate static let defaults = UserDefaults.standard

  fileprivate static var settingsCache: [Setting:Any] = [:]
  fileprivate(set) static var initialized = false {
    didSet {
      guard initialized else { return }
      Notification(nil).post()
    }
  }

  /** updateCache */
  static fileprivate func updateCache() {
    logDebug("")
    let changedSettings: [Setting] = Setting.allCases.filter {
      switch ($0.currentValue, $0.cachedValue) {
        case let (current as NSNumber, previous as NSNumber) where current != previous: return true
        case let (current as Data, previous as Data)     where current != previous: return true
        case (.some, .none), (.none, .some):                                            return true
        default:                                                                        return false
      }
    }

    guard changedSettings.count > 0 else { logDebug("no changes detected"); return }

    logDebug("changed settings: \(changedSettings.map({$0.rawValue}))")

    for setting in changedSettings {
      settingsCache[setting] = setting.currentValue
      logDebug("posting notification for setting '\(setting.rawValue)'")
      Notification(setting).post()
    }
  }

  static var iCloudStorage: Bool {
    get { 
      if let cachedValue = Setting.iCloudStorage.cachedValue as? Bool {
         assert(Setting.iCloudStorage.currentValue as? Bool == cachedValue,
                "cached value is not up to date")
         return cachedValue
      } else {
        guard let defaultValue = Setting.iCloudStorage.defaultValue as? Bool else {
          fatalError("unable to retrieve default value for 'iCloudStorage'")
        }
        return defaultValue
      }
    }
    set { logDebug(""); defaults.set(newValue, forKey: Setting.iCloudStorage.key) }
  }

  static var confirmDeleteDocument: Bool {
    get { 
      if let cachedValue = Setting.ConfirmDeleteDocument.cachedValue as? Bool {
         assert(Setting.ConfirmDeleteDocument.currentValue as? Bool == cachedValue,
                "cached value is not up to date")
         return cachedValue
      } else {
        guard let defaultValue = Setting.ConfirmDeleteDocument.defaultValue as? Bool else {
          fatalError("unable to retrieve default value for 'ConfirmDeleteDocument'")
        }
        return defaultValue
      }
    }
    set { logDebug(""); defaults.set(newValue, forKey: Setting.ConfirmDeleteDocument.key) }
  }

  static var confirmDeleteTrack: Bool {
    get { 
      if let cachedValue = Setting.ConfirmDeleteTrack.cachedValue as? Bool {
         assert(Setting.ConfirmDeleteTrack.currentValue as? Bool == cachedValue,
                "cached value is not up to date")
         return cachedValue
      } else {
        guard let defaultValue = Setting.ConfirmDeleteTrack.defaultValue as? Bool else {
          fatalError("unable to retrieve default value for 'ConfirmDeleteTrack'")
        }
        return defaultValue
      }
    }
    set { logDebug(""); defaults.set(newValue, forKey: Setting.ConfirmDeleteTrack.key) }
  }

  static var scrollTrackLabels: Bool {
    get { 
      if let cachedValue = Setting.ScrollTrackLabels.cachedValue as? Bool {
         assert(Setting.ScrollTrackLabels.currentValue as? Bool == cachedValue,
                "cached value is not up to date")
         return cachedValue
      } else {
        guard let defaultValue = Setting.ScrollTrackLabels.defaultValue as? Bool else {
          fatalError("unable to retrieve default value for 'ScrollTrackLabels'")
        }
        return defaultValue
      }
    }
    set { logDebug(""); defaults.set(newValue, forKey: Setting.ScrollTrackLabels.key) }
  }

  static var currentDocumentLocal: Data? {
    get { 
      if let cachedValue = Setting.CurrentDocumentLocal.cachedValue as? Data {
         assert(Setting.CurrentDocumentLocal.currentValue as? Data == cachedValue,
               "cached value is not up to date")
         return cachedValue
      } else {
        guard let defaultValue = Setting.CurrentDocumentLocal.defaultValue as? Data else { return nil }
        return defaultValue
      }
    }
    set { logDebug(""); defaults.set(newValue, forKey: Setting.CurrentDocumentLocal.key) }
  }

  static var currentDocumentiCloud: Data? {
    get {
      if let cachedValue = Setting.CurrentDocumentiCloud.cachedValue as? Data {
        assert(Setting.CurrentDocumentiCloud.currentValue as? Data == cachedValue,
              "cached value is not up to date")
        return cachedValue
      } else {
        guard let defaultValue = Setting.CurrentDocumentiCloud.defaultValue as? Data else {
          return nil
        }
        return defaultValue
      }
    }
    set { logDebug(""); defaults.set(newValue, forKey: Setting.CurrentDocumentiCloud.key) }
  }

  static var makeNewTrackCurrent: Bool {
    get { 
      if let cachedValue = Setting.MakeNewTrackCurrent.cachedValue as? Bool {
         assert(Setting.MakeNewTrackCurrent.currentValue as? Bool == cachedValue,
                "cached value is not up to date")
         return cachedValue
      } else {
        guard let defaultValue = Setting.MakeNewTrackCurrent.defaultValue as? Bool else {
          fatalError("unable to retrieve default value for 'MakeNewTrackCurrent'")
        }
        return defaultValue
      }
    }
    set { logDebug(""); defaults.set(newValue, forKey: Setting.MakeNewTrackCurrent.key) }
  }

  fileprivate static let receptionist: NotificationReceptionist = {
    let receptionist = NotificationReceptionist()

    receptionist.observe(name: UserDefaults.didChangeNotification.rawValue,
                    from: defaults,
                   queue: OperationQueue.main)
    {
      _ in

      logDebug("observed notification that user defaults have changed")
      SettingsManager.updateCache()
    }

    return receptionist
    }()

  /** initialize */
  static func initialize() {
    guard !initialized else { return }

    defaults.register(defaults: Setting.boolSettings.reduce([String:AnyObject]()) {
      (dict: [String:AnyObject], setting: Setting) in
      var dict = dict
      dict[setting.key] = setting.defaultValue as? AnyObject
      return dict

      })

    Setting.allCases.forEach { SettingsManager.settingsCache[$0] = $0.currentValue }

    let _ = receptionist

    initialized = true
  }
  
}

// MARK: - Notification
extension SettingsManager: NotificationDispatchType {

  struct Notification: NotificationType {

    enum Name: String, NotificationNameType {
      case iCloudStorageChanged
      case ConfirmDeleteDocumentChanged, ConfirmDeleteTrackChanged
      case ScrollTrackLabelsChanged
      case CurrentDocumentLocalChanged, CurrentDocumentiCloudChanged
      case MakeNewTrackCurrentChanged
      case DidInitializeSettings
    }

    enum Key: String, KeyType { case SettingValue }

    static let iCloudStorageChanged         = Notification(name: .iCloudStorageChanged)
    static let ConfirmDeleteDocumentChanged = Notification(name: .ConfirmDeleteDocumentChanged)
    static let ConfirmDeleteTrackChanged    = Notification(name: .ConfirmDeleteTrackChanged)
    static let ScrollTrackLabelsChanged     = Notification(name: .ScrollTrackLabelsChanged)
    static let CurrentDocumentLocalChanged  = Notification(name: .CurrentDocumentLocalChanged)
    static let CurrentDocumentiCloudChanged = Notification(name: .CurrentDocumentiCloudChanged)
    static let MakeNewTrackCurrentChanged   = Notification(name: .MakeNewTrackCurrentChanged)
    static let DidInitializeSettings        = Notification(name: .DidInitializeSettings)

    var object: AnyObject? { return SettingsManager.self }
    let name: Name
    var setting: Setting? {
      switch name {
        case .iCloudStorageChanged:         return .iCloudStorage
        case .ConfirmDeleteDocumentChanged: return .ConfirmDeleteDocument
        case .ConfirmDeleteTrackChanged:    return .ConfirmDeleteTrack
        case .ScrollTrackLabelsChanged:     return .ScrollTrackLabels
        case .CurrentDocumentLocalChanged:  return .CurrentDocumentLocal
        case .CurrentDocumentiCloudChanged: return .CurrentDocumentiCloud
        case .MakeNewTrackCurrentChanged:   return .MakeNewTrackCurrent
        case .DidInitializeSettings:        return nil
      }
    }
    var userInfo: [Key:AnyObject?]? {
      guard let setting = setting else { return nil }
      return [.SettingValue: SettingsManager.settingsCache[setting] as? AnyObject]
    }

    fileprivate init(name: Name) { self.name = name }

    /**
    init:

    - parameter setting: Setting
    */
    fileprivate init(_ setting: Setting?) {
      guard let setting = setting  else { self = Notification.DidInitializeSettings; return }
      switch setting {
        case .iCloudStorage:         self = Notification.iCloudStorageChanged
        case .ConfirmDeleteDocument: self = Notification.ConfirmDeleteDocumentChanged
        case .ConfirmDeleteTrack:    self = Notification.ConfirmDeleteTrackChanged
        case .ScrollTrackLabels:     self = Notification.ScrollTrackLabelsChanged
        case .CurrentDocumentLocal:  self = Notification.CurrentDocumentLocalChanged
        case .CurrentDocumentiCloud: self = Notification.CurrentDocumentiCloudChanged
        case .MakeNewTrackCurrent:   self = Notification.MakeNewTrackCurrentChanged
      }
    }

  }

}

extension Notification {
  typealias  Key = SettingsManager.Notification.Key
  var iCloudStorageSetting: Bool? {
    return (userInfo?[Key.SettingValue.key] as? NSNumber)?.boolValue
  }
  var confirmDeleteDocumentSetting: Bool? {
    return (userInfo?[Key.SettingValue.key] as? NSNumber)?.boolValue
  }
  var confirmDeleteTrackSetting: Bool? {
    return (userInfo?[Key.SettingValue.key] as? NSNumber)?.boolValue
  }
  var scrollTrackLabelsSetting: Bool? {
    return (userInfo?[Key.SettingValue.key] as? NSNumber)?.boolValue
  }
  var makeNewTrackCurrentSetting: Bool? {
    return (userInfo?[Key.SettingValue.key] as? NSNumber)?.boolValue
  }
  var currentDocumentSetting: Data? {
    return  userInfo?[Key.SettingValue.key] as? Data
  }
}

// MARK: - Setting
extension SettingsManager {

  enum Setting: String, KeyType, EnumerableType {
    case iCloudStorage         = "iCloudStorage"
    case ConfirmDeleteDocument = "confirmDeleteDocument"
    case ConfirmDeleteTrack    = "confirmDeleteTrack"
    case ScrollTrackLabels     = "scrollTrackLabels"
    case CurrentDocumentLocal  = "currentDocumentLocal"
    case CurrentDocumentiCloud = "currentDocumentiCloud"
    case MakeNewTrackCurrent   = "makeNewTrackCurrent"

    var currentValue: Any? {
      guard let value = defaults.object(forKey: rawValue) else { return nil }

           if let number = value as? NSNumber { return number }
      else if let data   = value as? Data   { return data   }
      else                                    { return nil    }
    }

    var cachedValue: Any? { return SettingsManager.settingsCache[self] }

    var defaultValue: Any? {
      switch self {
        case .CurrentDocumentLocal, .CurrentDocumentiCloud: return nil
        case .iCloudStorage, .ConfirmDeleteDocument, .ConfirmDeleteTrack,
             .ScrollTrackLabels, .MakeNewTrackCurrent: return true
      }
    }

    static var boolSettings: [Setting] {
      return [.iCloudStorage, .ConfirmDeleteDocument, .ConfirmDeleteTrack,
              .ScrollTrackLabels, .MakeNewTrackCurrent]
    }
    static var allCases: [Setting] {
      return boolSettings + [.CurrentDocumentLocal, .CurrentDocumentiCloud]
    }
  }

}
