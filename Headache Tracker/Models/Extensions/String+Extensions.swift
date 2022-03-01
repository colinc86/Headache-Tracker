//
//  String+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/1/22.
//

import Foundation

extension String {
  
  /// Initializes a string from a static string.
  public init(_ staticString: StaticString) {
    self = staticString.withUTF8Buffer {
      String(decoding: $0, as: UTF8.self)
    }
  }
  
}
