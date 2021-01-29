//
//  TriumpFont.swift
//  Common
//
//  Created by Jason Cardwell on 1/13/21.
//  Copyright © 2021 Moondeer Studios. All rights reserved.
//
import Foundation
import SwiftUI
import MoonDev

// MARK: - TriumpFont

/// A structure describing fonts available from the Triump font family.
public struct TriumpFont
{
  /// The family designation the font carries in its postscript name.
  public let family: Family

  /// The volume designation the font carries in its postscript name.
  public let volume: Volume

  /// An enumeration of possible family designations.
  public enum Family: String
  {
    case blur = "Blur"
    case rock = "Rock"
    case extras = "Extras"
    case ornaments = "Ornaments"
  }

  /// An enumeration of possible weight designations.
  public enum Volume: String
  {
    case unspecified = ""
    case one = "01"
    case two = "02"
    case three = "03"
    case four = "04"
    case five = "05"
    case six = "06"
    case seven = "07"
    case eight = "08"
    case nine = "09"
    case ten = "10"
    case eleven = "11"
    case twelve = "12"
  }

  /// Declare a private initializer to prevent the creation of invalid
  /// family/volume combinations.
  ///
  /// - Parameters:
  ///   - family: The family designation.
  ///   - volume: The volume designation.
  public init(_ family: Family, _ volume: Volume)
  {
    self.family = family
    self.volume = volume
  }

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Blur-01.otf"
  public static let blur01 = TriumpFont(.blur, .one)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Blur-02.otf"
  public static let blur02 = TriumpFont(.blur, .two)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Blur-03.otf"
  public static let blur03 = TriumpFont(.blur, .three)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Blur-04.otf"
  public static let blur04 = TriumpFont(.blur, .four)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Blur-05.otf"
  public static let blur05 = TriumpFont(.blur, .five)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Blur-06.otf"
  public static let blur06 = TriumpFont(.blur, .six)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Blur-07.otf"
  public static let blur07 = TriumpFont(.blur, .seven)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Blur-08.otf"
  public static let blur08 = TriumpFont(.blur, .eight)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Blur-09.otf"
  public static let blur09 = TriumpFont(.blur, .nine)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Blur-10.otf"
  public static let blur10 = TriumpFont(.blur, .ten)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Blur-11.otf"
  public static let blur11 = TriumpFont(.blur, .eleven)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Blur-12.otf"
  public static let blur12 = TriumpFont(.blur, .twelve)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Extras.otf"
  public static let extras = TriumpFont(.extras, .unspecified)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Ornaments.otf"
  public static let ornaments = TriumpFont(.ornaments, .unspecified)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Rock-01.otf"
  public static let rock01 = TriumpFont(.rock, .one)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Rock-02.otf"
  public static let rock02 = TriumpFont(.rock, .two)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Rock-03.otf"
  public static let rock03 = TriumpFont(.rock, .three)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Rock-04.otf"
  public static let rock04 = TriumpFont(.rock, .four)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Rock-05.otf"
  public static let rock05 = TriumpFont(.rock, .five)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Rock-06.otf"
  public static let rock06 = TriumpFont(.rock, .six)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Rock-07.otf"
  public static let rock07 = TriumpFont(.rock, .seven)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Rock-08.otf"
  public static let rock08 = TriumpFont(.rock, .eight)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Rock-09.otf"
  public static let rock09 = TriumpFont(.rock, .nine)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Rock-10.otf"
  public static let rock10 = TriumpFont(.rock, .ten)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Rock-11.otf"
  public static let rock11 = TriumpFont(.rock, .eleven)

  /// `TriumpFont` instance for file "Latinotype - Triump-Rg-Rock-12.otf"
  public static let rock12 = TriumpFont(.rock, .twelve)
}

// MARK: PostscriptFont

extension TriumpFont: PostscriptFont
{
  public var postscriptName: String
  {
    "Triump-Rg-\(family.rawValue)\(volume == .unspecified ? "" : "-\(volume.rawValue)")"
  }
}

public struct TriumpFontStyle: ViewModifier
{
  public var font: TriumpFont
  public var size: CGFloat
  public func body(content: Content) -> some View {
    content
      .font(Font.custom(font.postscriptName, size: size))
  }
}

extension View
{
  public func triumpFont(family: TriumpFont.Family,
                          volume: TriumpFont.Volume,
                          size: CGFloat) -> some View
  {
    modifier(TriumpFontStyle(font: TriumpFont(family, volume), size: size))
  }
}