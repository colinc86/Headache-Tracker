//
//  Outlook.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/20/22.
//

import Foundation

/// A headache outlook.
enum Outlook: String {
  
  /// A headache is forseen.
  case headache = "Headache"
  
  /// No headache is forseeen.
  case noHeadache = "No Headache"
  
  var title: String {
    switch self {
    case .headache: return "Possible Headache"
    case .noHeadache: return "No Headache"
    }
  }
}
