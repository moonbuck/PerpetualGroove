//
//  Document.swift
//  PerpetualGroove
//
//  Created by Jason Cardwell on 9/28/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//
import UIKit
import MoonKit
import MIDI
import AudioEngine

/// A `UIDocument` subclass for presenting a document interface usable by the application.
public final class Document: UIDocument, Named, NotificationDispatching {

  /// Whether the document is backed by an iCloud file.
  public var isUbiquitous: Bool {
    return FileManager.default.isUbiquitousItem(at: fileURL)
  }

  /// The size of the document's file on disk or `0` if no file exists on disk.
  public var fileSize: UInt64 {
    return (try? FileManager.default .attributesOfItem(atPath: fileURL.path)[FileAttributeKey.size])
      as? UInt64 ?? 0
  }

  /// The date the document's file was created or `nil`.
  public var fileCreationDate: Date? {
    return (try? FileManager.default .attributesOfItem(atPath: fileURL.path)[FileAttributeKey.creationDate])
      as? Date
  }

  /// Whether the source for the document is a midi file or a groove file.
  public var sourceType: SourceType? { return SourceType(fileType) }

  /// Identical to `localizedName` unless `localizedName.isEmpty`, in which case 'unnamed` is used.
  public var name: String { return localizedName.isEmpty ? "unnamed" : localizedName }

  /// The location as determined by the ubiquity of the item at `fileURL`.
  public var storageLocation: DocumentManager.StorageLocation {
    return DocumentManager.StorageLocation(url: fileURL)
  }

  /// The sequence constituting the actual content for the document.
  public private(set) var sequence: Sequence? {

    didSet {

      guard oldValue !== sequence else { return }

      if let oldSequence = oldValue {
        receptionist.stopObserving(name: .didUpdate, from: oldSequence)
      }

      if let sequence = sequence {
        receptionist.observe(name: .didUpdate, from: sequence,
                             callback: weakCapture(of: self, block:Document.didUpdate))
      }

    }

  }

  /// Flag indicating whether current save operation is creating or overwriting the document file.
  private var isCreating = false

  /// Derived property for obtaining current bookmark data for the document.
  public var bookmarkData: Data {

    guard let data = try? fileURL.bookmarkData(options: .suitableForBookmarkFile) else {
      fatalError("Failed to generate bookmark for `fileURL`.")
    }

    return data

  }

  /// Overridden to utilize `DocumentManager.operationQueue`.
  public override var presentedItemOperationQueue: OperationQueue { return DocumentManager.operationQueue }

  /// Handler for notifications posted by `sequence`.
  private func didUpdate(_ notification: Foundation.Notification) {
    logv("")
    updateChangeCount(.done)
  }

  /// Handles the document's state change notifications
  /// - TODO: Implement conflict resolution.
  private func didChangeState(_ notification: Foundation.Notification) {
    
    guard documentState ∋ .inConflict,
          let versions = NSFileVersion.unresolvedConflictVersionsOfItem(at: fileURL)
      else
    {
      return
    }

    logw("Conflicting versions detected: \(versions)")

  }

  /// Overridden to register `receptionist` for the document's state change notifications.
  public override init(fileURL url: URL) {
    super.init(fileURL: url)

    receptionist.observe(name: .didChangeState, from: self,
                         callback: weakCapture(of: self, block:Document.didChangeState))

  }

  /// Observes sequence notifications and the document's own state change notifications.
  private let receptionist = NotificationReceptionist(callbackQueue: DocumentManager.operationQueue)

  /// Initializes `sequence` using `contents`.
  ///
  /// - throws: Error.invalidContent when `!contents is Data`.
  /// - throws: Error.invalidContentType when `SourceType(typeName) == nil`.
  public override func load(fromContents contents: Any, ofType typeName: String?) throws {
    
    guard let data = contents as? Data else { throw Error.invalidContent }
    guard let type = SourceType(typeName) else { throw Error.invalidContentType }

    guard data.count > 0 else { sequence = Sequence(); return }

    switch type {

      case .midi:
        sequence = Sequence(file: try MIDIFile(data: data))

      case .groove:
        guard let file = GrooveFile(data: data) else { throw Error.invalidContent }
        sequence = Sequence(file: file)

    }

  }

  /// Returns the data generated by `sequence` as encoded by the determined source type.
  /// If `isCreating == true`, then a new empty sequence is assigned to `sequence` before encoding.
  /// 
  /// - throws: Error.missingSequence when `isCreating == false && sequence == nil`.
  /// - throws: Error.invalidContentType when `SourceType(typeName) == nil`.
  public override func contents(forType typeName: String) throws -> Any {

    if sequence == nil && isCreating {
      sequence = Sequence()
      isCreating = false
    }

    guard let sequence = sequence else { throw Error.missingSequence }
    guard let type = SourceType(typeName) else { throw Error.invalidContentType }

    let file: DataConvertible
    switch type {
      case .midi:   file = MIDIFile(sequence: sequence)
      case .groove: file = GrooveFile(sequence: sequence, source: fileURL)
    }

    logi("file contents:\n\(file)")

    return file.data

  }

  /// Overridden to log the error before `super` handles it.
  public override func handleError(_ error: Swift.Error, userInteractionPermitted: Bool) {

    loge("\(error)")
    super.handleError(error, userInteractionPermitted: userInteractionPermitted)

  }

  /// Attempts to coordinate the renaming of the document to `newName`.
  func rename(to newName: String) {

    DocumentManager.queue.async {
      [weak self] in

      guard let weakself = self else { return }

      guard newName != weakself.localizedName else { return }

      let directoryURL = weakself.fileURL.deletingLastPathComponent()
      let oldName = weakself.localizedName
      let oldURL = weakself.fileURL
      let newURL = directoryURL + "\(newName).groove"

      logi("renaming document '\(oldName)' ⟹ '\(newName)'")

      let fileCoordinator = NSFileCoordinator(filePresenter: nil)
      var error: NSError?
      fileCoordinator.coordinate(writingItemAt: oldURL,
                                 options: .forMoving,
                                 writingItemAt: newURL,
                                 options: .forReplacing,
                                 error: &error)
      {
        oldURL, newURL in

        fileCoordinator.item(at: oldURL, willMoveTo: newURL)
        do {
          try FileManager.default.moveItem(at: oldURL, to: newURL)
          fileCoordinator.item(at: oldURL, didMoveTo: newURL)
        } catch {
          loge("\(error)")
        }
      }

      if let error = error { loge("\(error)") }

    }

  }

  /// Overridden to capture whether the document is being created or overwritten.
  public override func save(to url: URL,
                     for saveOperation: UIDocument.SaveOperation,
                     completionHandler: ((Bool) -> Void)?)
  {
    isCreating = saveOperation == .forCreating
    logi("(\(isCreating ? "saving" : "overwriting"))  '\(url.path)'")
    super.save(to: url, for: saveOperation, completionHandler: completionHandler)
  }

  /// Overridden to post notification of the document's new name.
  public override func presentedItemDidMove(to newURL: URL) {

    super.presentedItemDidMove(to: newURL)

    guard let newName = newURL.pathBaseName else { fatalError("Failed to get base name from new url") }
    postNotification(name: .didRenameDocument, object: self, userInfo: ["newName": newName])

  }

  /// Enumeration for specifying one of the supported document file types.
  public enum SourceType: String {
    case midi = "midi", groove = "groove"

    public init?(_ string: String?) {

      switch string?.lowercased() {

        case "midi", "mid", "public.midi-audio":
          self = .midi

        case "groove", "com.moondeerstudios.groove-document":
          self = .groove

        default:
          return nil

      }

    }

  }

  /// Enumeration of possible errors thrown by an instance of `Document`.
  public enum Error: String, Swift.Error {
    case invalidContentType, invalidContent, missingSequence
  }

  /// Enumeration of the names of the notifications dispatched by an instance of `Document`.
  public enum NotificationName: String, LosslessStringConvertible {

    case didRenameDocument  /// Posted when an existing document has been renamed.
    case didChangeState     /// Shadow for NSNotification.Name.UIDocumentStateChanged

    public var description: String {
      switch self {
        case .didRenameDocument: return rawValue
        case .didChangeState:    return UIDocument.stateChangedNotification.rawValue
      }
    }

    public init?(_ description: String) {
      switch description {
        case UIDocument.stateChangedNotification.rawValue:
          self = .didChangeState
        default:
          guard let name = NotificationName(rawValue: description) else { return nil }
          self = name
      }
    }

  }

}

extension Notification {

  /// The new file name of a renamed `Document` instance or `nil`.
  public var newDocumentName: String? { return userInfo?["newName"] as? String }

}
