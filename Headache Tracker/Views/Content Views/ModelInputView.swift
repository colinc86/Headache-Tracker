//
//  ModelInputView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/16/22.
//

import SwiftUI

struct ModelInputView: View {
  
  /// The application's measurement system.
  @AppStorage(AppSettings.measurementSystem) var measurementSystem: MeasurementSystem = NSLocale.system.usesMetricSystem ? .metric : .imperial
  
  let input: ModelInput
  
  var body: some View {
    List {
      if let weather = input.weatherStatistics {
        if let pressure = weather.pressureMeasurement {
          Section {
            TitleCaptionView(title: "Barometric Pressure", systemImage: "barometer", foregroundColor: .accentColor) {
              Text(Formatters.formatMeasurement(pressure))
                .font(.title)
            }
          } header: {
            SectionTitleView(title: "Weather")
          }
        }
        
        if let temperature = weather.temperatureMeasurement {
          Section {
            TitleCaptionView(title: "Temperature", systemImage: "thermometer", foregroundColor: .accentColor) {
              Text(Formatters.formatMeasurement(temperature))
                .font(.title)
            }
          }
        }
        
        if let humidity = weather.humidityMeasurement {
          Section {
            TitleCaptionView(title: "Humidity", systemImage: "humidity", foregroundColor: .accentColor) {
              Text(Formatters.formatMeasurement(humidity))
                .font(.title)
            }
          }
        }
      }
    }
    .navigationTitle("Predictors")
  }
  
}

struct ModelInputView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      ModelInputView(input: ModelInput(date: Date(), location: Previewing.location, weatherStatistics: WeatherStatistics(barometricPressure: 1020.0, currentPressure: 1020.0, currentHumidity: 0.8, currentTemperature: 50.0, sigmaPressure: 0.1, sigmaHumidity: 0.1, sigmaTemperature: 5.0), healthKitData: [:], timeIntervalUntilNextHeadacheStart: nil, timeIntervalUntilNextHeadacheEnd: nil, outlook: .noHeadache, severity: .mild))
    }
  }
}
