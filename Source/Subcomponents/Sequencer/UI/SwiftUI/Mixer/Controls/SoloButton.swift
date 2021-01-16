//
//  SoloButton.swift
//  Sequencer
//
//  Created by Jason Cardwell on 1/14/21.
//  Copyright © 2021 Moondeer Studios. All rights reserved.
//
import Common
import SwiftUI

// MARK: - SoloButton

struct SoloButton: View
{

  let isEngaged: Bool

  var body: some View
  {
    Button(action: {})
    {
      Text("Solo")
        .font(.style(FontStyle(font: EvelethFont.light, size: 14, style: .title)))
    }
    .frame(width: 68, height: 14)
    .accentColor(Color(isEngaged
                        ? "engagedTintColor"
                        : "disengagedTintColor",
                       bundle: bundle))
  }
}

// MARK: - SoloButton_Previews

struct SoloButton_Previews: PreviewProvider
{
  static var previews: some View
  {
    SoloButton(isEngaged: false)
      .previewLayout(.sizeThatFits)
      .preferredColorScheme(.dark)
      .padding()
  }
}
