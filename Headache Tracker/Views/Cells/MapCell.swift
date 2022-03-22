//
//  MapCell.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/18/22.
//

import CoreLocation
import MapKit
import SwiftUI

extension MKCoordinateRegion: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.center.latitude == rhs.center.latitude &&
    lhs.center.longitude == rhs.center.longitude &&
    lhs.span.latitudeDelta == rhs.span.latitudeDelta &&
    lhs.span.longitudeDelta == rhs.span.longitudeDelta
  }
}

struct MapCell: View {
  
  struct Annotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let accuracy: CLLocationAccuracy
  }
  
  let location: CLLocation
  let annotation: Annotation
  var region: Binding<MKCoordinateRegion> {
    Binding<MKCoordinateRegion> {
      MKCoordinateRegion(center: location.coordinate, latitudinalMeters: location.horizontalAccuracy * 1.5, longitudinalMeters: location.horizontalAccuracy * 1.5)
    } set: { _ in
    }
  }
    
  var body: some View {
    MapView(location: location)
      .frame(height: 200.0)
  }
  
  init(location: CLLocation) {
    self.location = location
    self.annotation = Annotation(coordinate: location.coordinate, accuracy: location.horizontalAccuracy)
  }
}

struct MapCell_Previews: PreviewProvider {
  static var previews: some View {
    MapCell(location: Previewing.location)
  }
}
