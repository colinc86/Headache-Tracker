//
//  MapView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/20/22.
//

import Contacts
import HealthKit
import MapKit
import SwiftUI

/// A location annotation.
fileprivate class LocationAnnotation: NSObject, MKAnnotation {
  
  static let reuseIdentifier = "locationAnnotation"
  let severity: HKCategoryValueSeverity
  let coordinate: CLLocationCoordinate2D
  
  /// The annotation's map item.
  var mapItem: MKMapItem? {
    let placemark = MKPlacemark(coordinate: coordinate, addressDictionary: nil)
    let mapItem = MKMapItem(placemark: placemark)
    mapItem.name = severity.title
    return mapItem
  }
  
  init(severity: HKCategoryValueSeverity, coordinate: CLLocationCoordinate2D) {
    self.severity = severity
    self.coordinate = coordinate
    super.init()
  }
  
  var title: String? {
    return severity.title
  }
  
  var subtitle: String? {
    return "(\(coordinate.latitude), \(coordinate.longitude)"
  }
}

/// A map view for displaying a location with horizontal accuracy.
struct MapView: UIViewRepresentable {
  
  // MARK: Public properties
  
  /// The location to plot.
  let location: CLLocation
  
  // MARK: Private properties
  
  /// The map view's delegate.
  private let mapViewDelegate = MapViewDelegate()
  
  // MARK: UIViewRepresentable methods
  
  func makeUIView(context: Context) -> MKMapView {
    MKMapView(frame: .zero)
  }
  
  func updateUIView(_ view: MKMapView, context: Context) {
    view.delegate = mapViewDelegate
    view.translatesAutoresizingMaskIntoConstraints = false
    
    if !view.overlays.isEmpty {
      view.removeOverlays(view.overlays)
    }
    
    if !view.annotations.isEmpty {
      view.removeAnnotations(view.annotations)
    }
    
    let circle = MKCircle(center: location.coordinate, radius: location.horizontalAccuracy)
    view.addOverlay(circle)
    
    let annotation = LocationAnnotation(severity: .mild, coordinate: location.coordinate)
    view.addAnnotation(annotation)
    
    let mapRect = circle.boundingMapRect
    view.setVisibleMapRect(mapRect, edgePadding: UIEdgeInsets(top: 36, left: 36, bottom: 36, right: 36), animated: true)
  }
  
}

// MARK: MKMapViewDelegate methods

class MapViewDelegate: NSObject, MKMapViewDelegate {
  
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    let renderer = MKCircleRenderer(overlay: overlay)
    renderer.fillColor = UIColor.tintColor.withAlphaComponent(0.25)
    renderer.strokeColor = UIColor.tintColor.withAlphaComponent(0.5)
    renderer.lineWidth = 4.0
    return renderer
  }
  
  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    guard let annotation = annotation as? LocationAnnotation else {
      return nil
    }

    var view: MKMarkerAnnotationView
    if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: LocationAnnotation.reuseIdentifier) as? MKMarkerAnnotationView {
      dequeuedView.annotation = annotation
      view = dequeuedView
    } else {
      view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: LocationAnnotation.reuseIdentifier)
      view.canShowCallout = true
      view.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
    }
    
    view.markerTintColor = .tintColor
    view.tintColor = UIColor(Color.accentColor)
    return view
  }
  
  func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
    guard let location = view.annotation as? LocationAnnotation else {
      return
    }
    
    let launchOptions = [
      MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsMapCenterKey
    ]
    location.mapItem?.openInMaps(launchOptions: launchOptions)
  }
}

struct MapView_Previews: PreviewProvider {
  static var previews: some View {
    MapView(location: Previewing.location)
  }
}
