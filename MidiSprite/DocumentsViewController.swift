//
//  DocumentsViewController.swift
//  MidiSprite
//
//  Created by Jason Cardwell on 10/24/14.
//  Copyright (c) 2014 Moondeer Studios. All rights reserved.
//

import Foundation
import UIKit
import MoonKit
import Eveleth

final class DocumentsViewController: UICollectionViewController {

  // MARK: - Properties

  var dismiss: (() -> Void)?

  private let constraintID = Identifier("DocumentsViewController", "CollectionView")

  private var widthConstraint: NSLayoutConstraint?
  private var heightConstraint: NSLayoutConstraint?

  private let receptionist: NotificationReceptionist = {
    let receptionist = NotificationReceptionist(callbackQueue: NSOperationQueue.mainQueue())
    receptionist.logContext = LogManager.UIContext
    return receptionist
  }()

  @IBOutlet weak var documentsViewLayout: DocumentsViewLayout! { didSet { documentsViewLayout.controller = self } }

  private(set) var itemSize: CGSize = .zero {
    didSet {
      guard itemSize != oldValue else { return }
      collectionView?.collectionViewLayout.invalidateLayout()
      let (w, h) = itemSize.unpack
      collectionViewSize = CGSize(width: w, height: h * CGFloat(items.count + 1))
    }
  }

  private var collectionViewSize: CGSize = .zero {
    didSet {
      guard collectionViewSize != oldValue else { return }
      let (w, h) = collectionViewSize.unpack
      widthConstraint?.constant = w
      heightConstraint?.constant = h
      collectionViewLayout.invalidateLayout()
   }
  }

  /**
  prefersStatusBarHidden

  - returns: Bool
  */
  override func prefersStatusBarHidden() -> Bool { return true }

  // MARK: - Initialization

  /** setup */
  override func awakeFromNib() {

    super.awakeFromNib()

    (collectionViewLayout as? DocumentsViewLayout)?.controller = self

    receptionist.observe(MIDIDocumentManager.Notification.DidUpdateMetadataItems,
                    from: MIDIDocumentManager.self,
                callback: weakMethod(self, method: DocumentsViewController.updateItems))
    receptionist.observe(MIDIDocumentManager.Notification.DidCreateDocument,
                   from: MIDIDocumentManager.self,
               callback: weakMethod(self, method: DocumentsViewController.updateItems))
    receptionist.observe(SettingsManager.Notification.Name.iCloudStorageChanged, from: SettingsManager.self) {
      [weak self] in
      guard let value = $0.iCloudStorageSetting else { return }
      self?.iCloudStorage = value
    }
  }

  // MARK: - Document items

  private var iCloudStorage = SettingsManager.iCloudStorage { didSet { collectionView?.reloadData() } }

  private var iCloudItems: [NSMetadataItem] = []
  private var localItems: [LocalDocumentItem] = []

  private var items: [DocumentItemType] { return iCloudStorage ? iCloudItems : localItems }

  // MARK: - View lifecycle

  /** viewDidLoad */
  override func viewDidLoad() {
    super.viewDidLoad()

    collectionView?.translatesAutoresizingMaskIntoConstraints = false
    view.translatesAutoresizingMaskIntoConstraints = false
  }

  /**
  viewWillAppear:

  - parameter animated: Bool
  */
  override func viewWillAppear(animated: Bool) { guard !MIDIDocumentManager.gatheringMetadataItems else { return }; updateItems() }

  /** updateViewConstraints */
  override func updateViewConstraints() {
    guard let collectionView = collectionView else { super.updateViewConstraints(); return }

    if view.constraintsWithIdentifier(constraintID).count == 0 {
      view.constrain([𝗩|-collectionView-|𝗩, 𝗛|-collectionView-|𝗛] --> constraintID)
    }

    guard case (.None, .None) = (widthConstraint, heightConstraint) else { super.updateViewConstraints(); return }

    let (w, h) = collectionViewSize.unpack
    widthConstraint = (collectionView.width => w --> Identifier(self, "Content", "Width")).constraint
    widthConstraint?.active = true
    heightConstraint = (collectionView.height => h --> Identifier(self, "Content", "Height")).constraint
    heightConstraint?.active = true

    super.updateViewConstraints()
  }

  private var cellShowingDelete: DocumentCell? {
    return collectionView?.visibleCells().first({($0 as? DocumentCell)?.showingDelete == true}) as? DocumentCell
  }

  // MARK: - Notifications

  /**
  updateItems:

  - parameter notification: NSNotification? = nil
  */
  private func updateItems(notification: NSNotification? = nil) {
    // TODO: Add cell for newly created document
    guard isViewLoaded() else { return }

    iCloudItems = MIDIDocumentManager.metadataItems.array
    do {
      localItems = try documentsDirectoryContents().filter({
        guard let ext = $0.pathExtension else { return false}
        return ext ~= ~/"^[mM][iI][dD][iI]?$"}
      ).map({LocalDocumentItem($0)})
    } catch {
      logError(error, message: "Failed to obtain local items")
    }
    let font = UIFont.controlFont
    let characterCount = max(CGFloat(items.map({$0.displayName.characters.count ?? 0}).maxElement() ?? 0), 15)
    itemSize = CGSize(width: characterCount * font.characterWidth, height: font.pointSize * 2).integralSize
    collectionView?.reloadData()
    logDebug("items updated and data reloaded")
  }

  // MARK: UICollectionViewDataSource

  /**
  numberOfSectionsInCollectionView:

  - parameter collectionView: UICollectionView

  - returns: Int
  */
  override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int { return 2 }

  /**
  collectionView:numberOfItemsInSection:

  - parameter collectionView: UICollectionView
  - parameter section: Int

  - returns: Int
  */
  override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return section == 1 ? items.count : 1
  }

  /**
  collectionView:cellForItemAtIndexPath:

  - parameter collectionView: UICollectionView
  - parameter indexPath: NSIndexPath

  - returns: UICollectionViewCell
  */
  override func collectionView(collectionView: UICollectionView,
        cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell
  {
    let cell: UICollectionViewCell
    switch indexPath.section {
      case 0:
        cell = collectionView.dequeueReusableCellWithReuseIdentifier(CreateDocumentCell.Identifier, forIndexPath: indexPath)
      default:
        cell = collectionView.dequeueReusableCellWithReuseIdentifier(DocumentCell.Identifier, forIndexPath: indexPath)
        (cell as? DocumentCell)?.item = items[indexPath.row]
    }
    
    return cell
  }

  // MARK: - UICollectionViewDelegate

  /**
  collectionView:shouldHighlightItemAtIndexPath:

  - parameter collectionView: UICollectionView
  - parameter indexPath: NSIndexPath

  - returns: Bool
  */
  override func     collectionView(collectionView: UICollectionView,
    shouldHighlightItemAtIndexPath indexPath: NSIndexPath) -> Bool
  {
    guard let cell = cellShowingDelete else { return true }
    cell.hideDelete()
    return false
  }

  /**
  collectionView:shouldSelectItemAtIndexPath:

  - parameter collectionView: UICollectionView
  - parameter indexPath: NSIndexPath

  - returns: Bool
  */
  override func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
    guard let cell = cellShowingDelete else { return true }
    cell.hideDelete()
    return false
  }

  /**
  collectionView:didSelectItemAtIndexPath:

  - parameter collectionView: UICollectionView
  - parameter indexPath: NSIndexPath
  */
  override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
    switch indexPath.section {
      case 0:  MIDIDocumentManager.createNewDocument()
      default: MIDIDocumentManager.openItem(items[indexPath.row])
    }
    dismiss?()
  }
}
