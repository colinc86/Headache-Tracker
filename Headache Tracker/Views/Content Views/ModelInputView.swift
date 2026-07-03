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
  @AppStorage(Preferences.General.Keys.colorTheme, store: .shared) private var colorTheme = Preferences.General.Defaults.colorTheme
  
  var body: some View {
    List {
      if let weather = input.weatherStatistics {
        Section {
          Card(title: "Barometric Pressure", systemImage: "barometer", foregroundColor: colorTheme.baseColor) {
            Text(Formatters.formatMeasurement(weather.pressureMeasurement))
              .font(.title)
          } caption: {
            Text("Δ \(Formatters.formatMeasurementDelta(weather.sigmaPressureMeasurement))")
          }
          .cardListRow()
        } header: {
          SectionTitleView(title: "Weather")
        }

        Section {
          Card(title: "Temperature", systemImage: "thermometer", foregroundColor: colorTheme.baseColor) {
            Text(Formatters.formatMeasurement(weather.temperatureMeasurement))
              .font(.title)
          } caption: {
            Text("Δ \(Formatters.formatMeasurementDelta(weather.sigmaTemperatureMeasurement))")
          }
          .cardListRow()
        }

        Section {
          Card(title: "Humidity", systemImage: "humidity", foregroundColor: colorTheme.baseColor) {
            Text(Formatters.formatMeasurement(weather.humidityMeasurement))
              .font(.title)
          } caption: {
            Text("Δ \(Formatters.formatMeasurementDelta(weather.sigmaHumidityMeasurement))")
          }
          .cardListRow()
        }
      }
    }
    .navigationTitle("Predictors")
  }
  
}

struct ModelInputView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      ModelInputView(input: ModelInput(date: Date(), location: Previewing.location, weatherStatistics: WeatherStatistics(barometricPressure: 1020.0, currentPressure: 1020.0, currentHumidity: 0.8, currentTemperature: 50.0, sigmaPressure: 0.1, sigmaHumidity: 0.1, sigmaTemperature: 5.0), healthKitData: [:], timeIntervalUntilNextHeadacheStart: nil, timeIntervalUntilNextHeadacheEnd: nil, outlook: .noHeadache, severity: .mild))
    }
  }
}
