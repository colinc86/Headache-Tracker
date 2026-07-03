//
//  ModelInputView.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/16/22.
//

import SwiftUI

struct ModelInputView: View {
  
  /// The model input to display.
  let input: ModelInput
  
  // MARK: Private properties
  
  /// The application's custom color theme.
  @AppStorage(Preferences.General.Keys.colorTheme) private var colorTheme = Preferences.General.Defaults.colorTheme
  
  var body: some View {
    ScrollView {
      if let weather = input.weatherStatistics {
        Section {
          Card(title: "Barometric Pressure", systemImage: "barometer", foregroundColor: colorTheme.baseColor) {
            Text(Formatters.formatMeasurement(weather.pressureMeasurement))
              .font(.title)
          } caption: {
            Text("Δ \(weather.sigmaPressure) kPa")
          }
        } header: {
          SectionTitleView(title: "Weather")
        }
        
        Section {
          Card(title: "Temperature", systemImage: "thermometer", foregroundColor: colorTheme.baseColor) {
            Text(Formatters.formatMeasurement(weather.temperatureMeasurement))
              .font(.title)
          } caption: {
            Text("Δ \(weather.sigmaTemperature) ℃")
          }
        }
        
        Section {
          Card(title: "Humidity", systemImage: "humidity", foregroundColor: colorTheme.baseColor) {
            Text(Formatters.formatMeasurement(weather.humidityMeasurement))
              .font(.title)
          } caption: {
            Text("Δ \(weather.sigmaHumidity) %")
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
