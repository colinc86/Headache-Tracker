//
//  TrainingInput.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 3/10/22.
//

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
    // Set the training tags
    trainingData.setVolitileVariables()
    
    // Get the data tables
    outlookTable = try MLDataTable(dictionary: TrainingInput.balanceTrainingData(trainingData, forModelType: .outlookClassifier).outlookDataTable())
    severityTable = try MLDataTable(dictionary: TrainingInput.balanceTrainingData(trainingData, forModelType: .severityClassifier).severityDataTable())
    onsetTable = try MLDataTable(dictionary: TrainingInput.balanceTrainingData(trainingData, forModelType: .onsetRegressor).onsetTableData())
    durationTable = try MLDataTable(dictionary: TrainingInput.balanceTrainingData(trainingData, forModelType: .durationRegressor).durationTableData())
  }
  
  /// Balances the training data for the given model type.
  ///
  /// - Parameters:
  ///   - trainingData: The training data to balance.
  ///   - modelType: The model type intended to train.
  /// - Returns: The training data.
  private static func balanceTrainingData(_ trainingData: [TrainingData], forModelType modelType: Predictor.ModelType) -> [TrainingData] {
    switch modelType {
    case .durationRegressor:
      return trainingData.filter({ $0.timeIntervalUntilNextHeadacheEnd != nil })
    case .onsetRegressor:
      return trainingData.filter({ $0.timeIntervalUntilNextHeadacheStart != nil })
    case .severityClassifier:
      var headacheData = trainingData.filter({ $0.severity?.headache != nil })
      var nonHeadacheData = trainingData.filter({ $0.severity?.headache == nil })
      
      // Min count
      let minCount = min(headacheData.count, nonHeadacheData.count)
      
      // Shuffle
      headacheData.shuffle()
      nonHeadacheData.shuffle()
      
      // Trim
      if headacheData.count > minCount {
        headacheData = [TrainingData](headacheData[0 ..< minCount])
      }
      if nonHeadacheData.count > minCount {
        nonHeadacheData = [TrainingData](nonHeadacheData[0 ..< minCount])
      }
      
      return headacheData + nonHeadacheData
    case .outlookClassifier:
      var headacheData = trainingData.filter({ $0.outlook == .headache })
      var possibleHeadacheData = trainingData.filter({ $0.outlook == .possibleHeadache })
      var noHeadacheData = trainingData.filter({ $0.outlook == .noHeadache })
      
      // Min count
      let minCount = min(headacheData.count, possibleHeadacheData.count, noHeadacheData.count)
      
      // Shuffle
      headacheData.shuffle()
      possibleHeadacheData.shuffle()
      noHeadacheData.shuffle()
      
      // Trim
      if headacheData.count > minCount {
        headacheData = [TrainingData](headacheData[0 ..< minCount])
      }
      if possibleHeadacheData.count > minCount {
        possibleHeadacheData = [TrainingData](possibleHeadacheData[0 ..< minCount])
      }
      if noHeadacheData.count > minCount {
        noHeadacheData = [TrainingData](noHeadacheData[0 ..< minCount])
      }
      
      return headacheData + possibleHeadacheData + noHeadacheData
    }
  }
}
#endif
