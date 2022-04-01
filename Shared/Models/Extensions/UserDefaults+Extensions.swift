//
//  UserDefaults+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/31/22.
//

import Foundation
import SwiftUI

extension UserDefaults {
  
  /// The shared user defaults container.
  static var shared: UserDefaults? {
    UserDefaults(suiteName: Constants.appGroupIdentifier)
  }
  
}

// MARK: RawRepresentable methods

extension UserDefaults {
  
  func setRawValue<R: RawRepresentable>(_ value: R?, forKey key: String) where R.RawValue == String {
    set(value?.rawValue, forKey: key)
  }
  
  func rawValue<R: RawRepresentable>(forKey key: String) -> R? where R.RawValue == String {
    guard let stringRepresentation = string(forKey: key) else {
      return nil
    }
    return R(rawValue: stringRepresentation)
  }
  
  func setRawValue<R: RawRepresentable>(_ value: R?, forKey key: String) where R.RawValue == Int {
    set(value?.rawValue, forKey: key)
  }
  
  func rawValue<R: RawRepresentable>(forKey key: String) -> R? where R.RawValue == Int {
    R(rawValue: integer(forKey: key))
  }
  
}

// MARK: Codable methods

extension UserDefaults {

  func setEncodableValue<E: Encodable>(_ value: E?, forKey key: String) throws {
    if let value = value {
      set(try JSONEncoder().encode(value), forKey: key)
    }
    else {
      set(nil, forKey: key)
    }
  }

  func decodableValue<D: Decodable>(forKey key: String) throws -> D? {
    guard let data = data(forKey: key) else {
      return nil
    }
    return try JSONDecoder().decode(D.self, from: data)
  }

}

private protocol AnyOptional {
  var isNil: Bool { get }
}

extension Optional: AnyOptional {
  var isNil: Bool { self == nil }
}

// MARK: - UserDefault

@propertyWrapper struct UserDefault<Value> {
  
  /// The default's wrapped value.
  var wrappedValue: Value {
    get {
      (store.value(forKey: key) as? Value) ?? defaultValue
    }
    
    set {
      if let optional = newValue as? AnyOptional, optional.isNil {
        store.removeObject(forKey: key)
      }
      else {
        store.setValue(newValue, forKey: key)
      }
    }
  }
  
  // MARK: Private properties
  
  /// The default's key.
  private let key: String
  
  /// The default's default value.
  private let defaultValue: Value
  
  /// The store that the default is stored.
  private let store: UserDefaults
  
  // MARK: Initializers
  
  init(wrappedValue defaultValue: Value, _ key: String, store: UserDefaults? = nil) {
    self.defaultValue = defaultValue
    self.key = key
    self.store = store ?? .standard
  }
}

extension UserDefault where Value: ExpressibleByNilLiteral {
  init(_ key: String, store: UserDefaults? = nil) {
    self.init(wrappedValue: nil, key, store: store)
  }
}

// MARK: RawUserDefault

@propertyWrapper struct RawUserDefault<Value: RawRepresentable> where Value.RawValue == String {
  
  /// The default's wrapped value.
  var wrappedValue: Value {
    get {
      store.rawValue(forKey: key) ?? defaultValue
    }
    
    set {
      if let optional = newValue as? AnyOptional, optional.isNil {
        store.removeObject(forKey: key)
      }
      else {
        store.setRawValue(newValue, forKey: key)
      }
    }
  }
  
  // MARK: Private properties
  
  /// The default's key.
  private let key: String
  
  /// The default's default value.
  private let defaultValue: Value
  
  /// The store that the default is stored.
  private let store: UserDefaults
  
  // MARK: Initializers
  
  init(wrappedValue defaultValue: Value, _ key: String, store: UserDefaults? = nil) {
    self.defaultValue = defaultValue
    self.key = key
    self.store = store ?? .standard
  }
}

extension RawUserDefault where Value: ExpressibleByNilLiteral {
  init(_ key: String, store: UserDefaults? = nil) {
    self.init(wrappedValue: nil, key, store: store)
  }
}

// MARK: CodableUserDefault

@propertyWrapper struct CodableUserDefault<Value: Codable> {
  
  /// The default's wrapped value.
  var wrappedValue: Value {
    get {
      do {
        return try store.decodableValue(forKey: key) ?? defaultValue
      }
      catch {
        logError("Error getting wrapped codable user default: \(error)")
        return defaultValue
      }
    }
    
    set {
      if let optional = newValue as? AnyOptional, optional.isNil {
        store.removeObject(forKey: key)
      }
      else {
        do {
          try store.setEncodableValue(newValue, forKey: key)
        }
        catch {
          logError("Error setting wrapped codable user default: \(error)")
        }
      }
    }
  }
  
  // MARK: Private properties
  
  /// The default's key.
  private let key: String
  
  /// The default's default value.
  private let defaultValue: Value
  
  /// The store that the default is stored.
  private let store: UserDefaults
  
  // MARK: Initializers
  
  init(wrappedValue defaultValue: Value, _ key: String, store: UserDefaults? = nil) {
    self.defaultValue = defaultValue
    self.key = key
    self.store = store ?? .standard
  }
}

extension CodableUserDefault where Value: ExpressibleByNilLiteral {
  init(_ key: String, store: UserDefaults? = nil) {
    self.init(wrappedValue: nil, key, store: store)
  }
}
