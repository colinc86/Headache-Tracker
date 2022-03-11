//
//  TrainingInput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/10/22.
//

import Accelerate
import Foundation

#if NON_PREVIEW
import CreateML

struct TrainingInput {
  
  let outlookTable: MLDataTable
  let severityTable: MLDataTable
  let onsetTable: MLDataTable
  let durationTable: MLDataTable
  
  var isValid: Bool {
    return outlookTable.isValid && outlookTable.isValid && onsetTable.isValid && durationTable.isValid
  }
  
  init(trainingData: [TrainingData]) throws {
    logDebug("Creating training data.")
    
    // Set the training classes
    logDebug("Setting the training classes.")
    trainingData.setVolitileVariables()
    
    // Convert the training data to model inputs
    logDebug("Converting the training data to model inputs.")
    let inputs = trainingData.map({ $0.modelInput })
    
    // Get the data tables
    logDebug("Getting the data tables.")
    outlookTable = try MLDataTable(inputs: TrainingInput.balanceInputs(inputs, forModelType: .outlookClassifier), forModelType: .outlookClassifier)
    severityTable = try MLDataTable(inputs: TrainingInput.balanceInputs(inputs, forModelType: .severityClassifier), forModelType: .severityClassifier)
    onsetTable = try MLDataTable(inputs: TrainingInput.balanceInputs(inputs, forModelType: .onsetRegressor), forModelType: .onsetRegressor)
    durationTable = try MLDataTable(inputs: TrainingInput.balanceInputs(inputs, forModelType: .durationRegressor), forModelType: .durationRegressor)
  }
  
  /// Balances the inputs for the given model type.
  ///
  /// - Parameters:
  ///   - inputs: The inputs to balance.
  ///   - modelType: The model type intended to train.
  /// - Returns: The balanced inputs.
  private static func balanceInputs(_ inputs: [ModelInput], forModelType modelType: Predictor.ModelType) -> [ModelInput] {
    logDebug("Balance inputs (\(inputs.count)) for model type \(modelType).")
    
    switch modelType {
    case .durationRegressor:
      return inputs.filter({ $0.timeIntervalUntilNextHeadacheEnd != nil })
    case .onsetRegressor:
      return inputs.filter({ $0.timeIntervalUntilNextHeadacheStart != nil })
    case .severityClassifier, .outlookClassifier:
      return smote(inputs, forModelType: modelType)
    }
  }
  
  private static func smote(_ inputs: [ModelInput], forModelType modelType: Predictor.ModelType) -> [ModelInput] {
    logDebug("SMOTE (\(inputs.count)) inputs for model type \(modelType).")
    // Get the class names
    var targetClasses = [String]()
    switch modelType {
    case .severityClassifier:
      targetClasses = inputs.map({ $0.severity.title })
    case .outlookClassifier:
      targetClasses = inputs.map({ $0.outlook.rawValue })
    default:
      break
    }
    
    // Get the unique classes
    targetClasses = targetClasses.unique()
    
    // Get a dictionary of inputs by class names and at the same time
    // determine what the majority class count is.
    var inputsByClass = [String: [ModelInput]]()
    var majorityClassCount = 0
    for targetClass in targetClasses {
      var targetInputs: [ModelInput]
      switch modelType {
      case .severityClassifier:
        targetInputs = inputs.filter({ $0.severity.title == targetClass })
      case .outlookClassifier:
        targetInputs = inputs.filter({ $0.outlook.rawValue == targetClass })
      default:
        targetInputs = []
        break
      }
      
      inputsByClass[targetClass] = targetInputs
      if targetInputs.count > majorityClassCount {
        majorityClassCount = targetInputs.count
      }
    }
    
    // SMOTE the input data
    var syntheticInputs = [ModelInput]()
    for targetClass in targetClasses {
      guard let targetInputs = inputsByClass[targetClass], majorityClassCount > targetInputs.count else {
        continue
      }
      
      syntheticInputs.append(contentsOf: synthesize(majorityClassCount - targetInputs.count, from: targetInputs))
    }
    
    // Return all of the data
    return inputs + syntheticInputs
  }
  
  static func synthesize(_ count: Int, from inputs: [ModelInput]) -> [ModelInput] {
    logDebug("Synthesize \(count) inputs from \(inputs.count) inputs.")
    
    var syntheticInputs = [ModelInput]()
    while syntheticInputs.count < count {
      // Select an input at random
      let randomInputIndex = Int.random(in: 0 ..< inputs.count)
      let randomInput = inputs[randomInputIndex]
      
      // Get the k-nearest neighbors of the index
      let neighbors = knn(inputs, randomInputIndex, 5)
      let randomNeighbor = neighbors[Int.random(in: 0 ..< neighbors.count)]
      
      // Select a random decimal percent
      let percent = Double.random(in: 0 ... 1.0)
      
      // Synthesize an input
      let syntheticInput = synthesize(percent, input: randomInput, neighbor: randomNeighbor)
      syntheticInputs.append(syntheticInput)
    }
    
    return syntheticInputs
  }
  
  static func knn(_ inputs: [ModelInput], _ index: Int, _ k: Int) -> [ModelInput] {
    // Get the prototype buffer
    let prototype = inputs[index].buffer()
    
    // Get the remaining inputs
    var remaining = inputs
    remaining.remove(at: index)
    
    // Sort by distance
    remaining.sort(by: { dist(prototype, $0.buffer()) < dist(prototype, $1.buffer()) })
    
    // Return the k-nearest neighbors
    if remaining.count < k {
      return remaining
    }
    return [ModelInput](remaining[0 ..< k])
  }
  
  static func dist(_ bufferA: [Double], _ bufferB: [Double]) -> Double {
    guard !bufferA.isEmpty && !bufferB.isEmpty && bufferA.count == bufferB.count else {
      return 0.0
    }
    
    var c = Double.nan
    vDSP_distancesqD(bufferA, 1, bufferB, 1, &c, vDSP_Length(bufferA.count))
    return sqrt(c)
  }
  
  static func synthesize(_ percent: Double, input: ModelInput, neighbor: ModelInput) -> ModelInput {
    // Health kit data
    var synthesizedHealthKitData = [HealthKitData: Double]()
    for (key, inputValue) in input.healthKitData ?? [:] {
      guard let neighborValue = neighbor.healthKitData?[key] else {
        continue
      }
      
      synthesizedHealthKitData[key] = interpolate(percent, inputValue, neighborValue)
    }
    
    // Weather data
    let iws = input.weatherStatistics ?? .empty
    let nws = neighbor.weatherStatistics ?? .empty
    let synthesizedBarometricPressure = interpolate(percent, iws.barometricPressure, nws.barometricPressure)
    let synthesizedPressure = interpolate(percent, iws.currentPressure, nws.currentPressure)
    let synthesizedHumitidy = interpolate(percent, iws.currentHumidity, nws.currentHumidity)
    let synthesizedTemperature = interpolate(percent, iws.currentTemperature, nws.currentTemperature)
    let synthesizedSigmaPressure = interpolate(percent, iws.sigmaPressure, nws.sigmaPressure)
    let synthesizedSigmaHumidity = interpolate(percent, iws.sigmaHumidity, nws.sigmaHumidity)
    let synthesizedSigmaTemperature = interpolate(percent, iws.sigmaTemperature, nws.sigmaTemperature)
    let synthesizedWeatherStatistics = WeatherStatistics(
      barometricPressure: synthesizedBarometricPressure,
      currentPressure: synthesizedPressure,
      currentHumidity: synthesizedHumitidy,
      currentTemperature: synthesizedTemperature,
      sigmaPressure: synthesizedSigmaPressure,
      sigmaHumidity: synthesizedSigmaHumidity,
      sigmaTemperature: synthesizedSigmaTemperature)
    
    // Date
    let synthesizedSecondsSinceMidnight = interpolate(percent, Calendar.current.timeIntervalSinceMidnight(input.date), Calendar.current.timeIntervalSinceMidnight(neighbor.date))
    let middleDate = Date(timeIntervalSince1970: interpolate(percent, input.date.timeIntervalSince1970, neighbor.date.timeIntervalSince1970))
    let synthesizedDate = Calendar.current.startOfDay(for: middleDate).addingTimeInterval(synthesizedSecondsSinceMidnight)
    
    return ModelInput(date: synthesizedDate, weatherStatistics: synthesizedWeatherStatistics, healthKitData: synthesizedHealthKitData)
  }
  
  static func interpolate(_ percent: Double, _ valueA: Double, _ valueB: Double) -> Double {
    let distance = valueB - valueA
    let step = distance * percent
    return valueA + step
  }
}
#endif
