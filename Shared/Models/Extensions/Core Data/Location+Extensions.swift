//
//  Location+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/17/22.
//

import CoreData
import CoreLocation
import Foundation

extension Location {
  
  /// The location's location coordinate.
  var coordinate: CLLocationCoordinate2D {
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
  
  /// The location's location.
  var location: CLLocation {
    return CLLocation(
      coordinate: coordinate,
      altitude: altitude,
      horizontalAccuracy: horizontalAccuracy,
      verticalAccuracy: verticalAccuracy,
      timestamp: timestamp ?? Date())
  }
  
  // MARK: Initializers
  
  convenience init(context: NSManagedObjectContext, location: CLLocation?) {
    self.init(context: context)
    updateWithLocation(location)
  }
  
}

// MARK: Public methods

extension Location {
  
  /// Updates the location.
  ///
  /// - Parameter location: The new core location.
  func updateWithLocation(_ location: CLLocation?) {
    if let location = location {
      timestamp = location.timestamp
      latitude = location.coordinate.latitude
      longitude = location.coordinate.longitude
      altitude = location.altitude
      horizontalAccuracy = location.horizontalAccuracy
      verticalAccuracy = location.verticalAccuracy
    }
    else {
      timestamp = nil
      latitude = 0.0
      longitude = 0.0
      altitude = 0.0
      horizontalAccuracy = 0.0
      verticalAccuracy = 0.0
    }
  }
  
}
