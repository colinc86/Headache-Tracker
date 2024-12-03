//
//  UUID+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/1/22.
//

import Foundation

/// Adds conformance to `RawRepresentable` to the `UUID` structure.
extension UUID: @retroactive RawRepresentable {
  
  public var rawValue: String {
    return uuidString
  }
  
  public init?(rawValue: String) {
    if let uuid = UUID(uuidString: rawValue) {
      self = uuid
    }
    else {
      return nil
    }
  }
  
}
