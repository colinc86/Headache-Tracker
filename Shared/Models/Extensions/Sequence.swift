//
//  Sequence.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/11/22.
//

import Foundation

extension Sequence where Iterator.Element: Hashable {
  
  /// Returns the unique elements of the sequence.
  func unique() -> [Iterator.Element] {
    var seen: [Iterator.Element: Bool] = [:]
    return self.filter { seen.updateValue(true, forKey: $0) == nil }
  }
  
}
