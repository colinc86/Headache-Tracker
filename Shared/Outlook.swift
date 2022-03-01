//
//  Outlook.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/28/22.
//

import Foundation

/// A headache outlook.
enum Outlook: String {
  
  /// A headache is in progress.
  case headache = "Headache"
  
  /// A headache is possible within the next timeframe.
  case possibleHeadache = "Possible Headache"
  
  /// No headache is forseeen within the next timeframe.
  case noHeadache = "No Headache"
}
