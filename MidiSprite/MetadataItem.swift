//
//  MetadataItem.swift
//  MidiSprite
//
//  Created by Jason Cardwell on 9/29/15.
//  Copyright © 2015 Moondeer Studios. All rights reserved.
//

import Foundation
import MoonKit

extension NSMetadataItem {

  enum ItemKey: String, EnumerableType {
    case FSName                 = "kMDItemFSName"                           // NSString
    case DisplayName            = "kMDItemDisplayName"                      // NSString
    case URL                    = "kMDItemURL"                              // NSURL
    case Path                   = "kMDItemPath"                             // NSString
    case FSSize                 = "kMDItemFSSize"                           // NSNumber
    case FSCreationDate         = "kMDItemFSCreationDate"                   // NSDate
    case FSContentChangeDate    = "kMDItemFSContentChangeDate"              // NSDate
    case IsUbiquitous           = "NSMetadataItemIsUbiquitousKey"                     // NSNumber: Bool
    case HasUnresolvedConflicts = "NSMetadataUbiquitousItemHasUnresolvedConflictsKey" // NSNumber: Bool
    case IsDownloading          = "NSMetadataUbiquitousItemIsDownloadingKey"          // NSNumber: Bool
    case IsUploaded             = "NSMetadataUbiquitousItemIsUploadedKey"             // NSNumber: Bool
    case IsUploading            = "NSMetadataUbiquitousItemIsUploadingKey"            // NSNumber: Bool
    case PercentDownloaded      = "NSMetadataUbiquitousItemPercentDownloadedKey"      // NSNumber: Double
    case PercentUploaded        = "NSMetadataUbiquitousItemPercentUploadedKey"        // NSNumber: Double
    case DownloadingStatus      = "NSMetadataUbiquitousItemDownloadingStatusKey"      // NSString
    case DownloadingError       = "NSMetadataUbiquitousItemDownloadingErrorKey"       // NSError
    case UploadingError         = "NSMetadataUbiquitousItemUploadingErrorKey"         // NSError
    static var allCases: [ItemKey] { 
      return [FSName, DisplayName, URL, Path, FSSize, FSCreationDate, FSContentChangeDate, IsUbiquitous,
              HasUnresolvedConflicts, IsDownloading, IsUploaded, IsUploading, PercentDownloaded,
              PercentUploaded, DownloadingStatus, DownloadingError, UploadingError]
    }
  }

  subscript(itemKey: ItemKey) -> AnyObject? { return valueForAttribute(itemKey.rawValue) }

  var fileSystemName: String?       { return self[.FSName]                  as? String                  }
  var displayName: String?          { return self[.DisplayName]             as? String                  }
  var URL: NSURL?                   { return self[.URL]                     as? NSURL                   }
  var path: String?                 { return self[.Path]                    as? String                  }
  var size: Int?                    { return (self[.FSSize]                 as? NSNumber)?.integerValue }
  var creationDate: NSDate?         { return self[.FSCreationDate]          as? NSDate                  }
  var modifiedDate: NSDate?         { return self[.FSContentChangeDate]     as? NSDate                  }
  var isUbiquitous: Bool?           { return (self[.IsUbiquitous]           as? NSNumber)?.boolValue    }
  var hasUnresolvedConflicts: Bool? { return (self[.HasUnresolvedConflicts] as? NSNumber)?.boolValue    }
  var downloading: Bool?            { return (self[.IsDownloading]          as? NSNumber)?.boolValue    }
  var uploaded: Bool?               { return (self[.IsUploaded]             as? NSNumber)?.boolValue    }
  var uploading: Bool?              { return (self[.IsUploading]            as? NSNumber)?.boolValue    }
  var percentDownloaded: Double?    { return (self[.PercentDownloaded]      as? NSNumber)?.doubleValue  }
  var percentUploaded: Double?      { return (self[.PercentUploaded]        as? NSNumber)?.doubleValue  }
  var downloadingStatus: String?    { return self[.DownloadingStatus]       as? String                  }
  var downloadingError: NSError?    { return self[.DownloadingError]        as? NSError                 }
  var uploadingError: NSError?      { return self[.UploadingError]          as? NSError                 }

  var attributesDescription: String {
    var result = "NSMetadataItem {\n\t"
    result += "\n\t".join(ItemKey.allCases.flatMap({
      guard let value = self[$0] else { return nil }
      let key = $0.rawValue
      let name: String?
      switch key {
        case ~/"^kMDItem[a-zA-Z]+$":
          name = $0.rawValue[key.startIndex.advancedBy(7)..<]
        case ~/"^NSMetadataItem[a-zA-Z]+Key$":
          name = $0.rawValue[key.startIndex.advancedBy(14) ..< key.endIndex.advancedBy(-3)]
        case ~/"^NSMetadataUbiquitousItem[a-zA-Z]+Key$":
          name = $0.rawValue[key.startIndex.advancedBy(24) ..< key.endIndex.advancedBy(-3)]
        default:
          name = nil
      }
      guard name != nil else { return nil }
      return "\(name!): \(value)"
      }))
    result += "\n}"
    return result
  }

}