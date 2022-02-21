//
//  SeverityClassifier.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/11/22.
//

import CoreML
import CreateML

/// An object that can be initialized with a feature provider.
protocol MLFeatureInitializable: MLFeatureProvider {
  init(features: MLFeatureProvider)
}

protocol CoreMLModel {
  func write(to fileURL: URL, metadata: MLModelMetadata?) throws
}
extension MLBoostedTreeClassifier: CoreMLModel {}
extension MLBoostedTreeRegressor: CoreMLModel {}

/// Class for model loading and prediction
class Model<Input: MLFeatureProvider, Output: MLFeatureInitializable> {
  
  let model: MLModel
  
  /**
   Construct ClassifierProto instance with an existing MLModel object.
   
   Usually the application does not use this initializer unless it makes a subclass of ClassifierProto.
   Such application may want to use `MLModel(contentsOfURL:configuration:)` and `ClassifierProto.urlOfModelInThisBundle` to create a MLModel object to pass-in.
   
   - parameters:
   - model: MLModel object
   */
  init(model: MLModel) {
    self.model = model
  }
  
  /**
   Construct ClassifierProto instance with explicit path to mlmodelc file
   - parameters:
   - modelURL: the file url of the model
   
   - throws: an NSError object that describes the problem
   */
  convenience init(contentsOf modelURL: URL) throws {
    try self.init(model: MLModel(contentsOf: modelURL))
  }
  
  /**
   Construct ClassifierProto instance asynchronously with URL of the .mlmodelc directory with optional configuration.
   
   Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.
   
   - parameters:
   - modelURL: the URL to the model
   - configuration: the desired model configuration
   - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
   */
  class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<Model, Error>) -> Void) {
    MLModel.load(contentsOf: modelURL, configuration: configuration) { result in
      switch result {
      case .failure(let error):
        handler(.failure(error))
      case .success(let model):
        handler(.success(Model(model: model)))
      }
    }
  }
  
  /**
   Construct ClassifierProto instance asynchronously with URL of the .mlmodelc directory with optional configuration.
   
   Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.
   
   - parameters:
   - modelURL: the URL to the model
   - configuration: the desired model configuration
   */
  @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> Model {
    let model = try await MLModel.load(contentsOf: modelURL, configuration: configuration)
    return Model(model: model)
  }
  
  /**
   Make a prediction using the structured interface
   
   - parameters:
   - input: the input to the prediction as ClassifierProtoInput
   
   - throws: an NSError object that describes the problem
   
   - returns: the result of the prediction as ClassifierProtoOutput
   */
  func prediction(input: Input) throws -> Output {
    return try self.prediction(input: input, options: MLPredictionOptions())
  }
  
  /**
   Make a prediction using the structured interface
   
   - parameters:
   - input: the input to the prediction as ClassifierProtoInput
   - options: prediction options
   
   - throws: an NSError object that describes the problem
   
   - returns: the result of the prediction as ClassifierProtoOutput
   */
  func prediction(input: Input, options: MLPredictionOptions) throws -> Output {
    let outFeatures = try model.prediction(from: input, options:options)
    return Output(features: outFeatures)
  }
  
  /**
   Make a batch prediction using the structured interface
   
   - parameters:
   - inputs: the inputs to the prediction as [ClassifierProtoInput]
   - options: prediction options
   
   - throws: an NSError object that describes the problem
   
   - returns: the result of the prediction as [ClassifierProtoOutput]
   */
  func predictions(inputs: [Input], options: MLPredictionOptions = MLPredictionOptions()) throws -> [Output] {
    let batchIn = MLArrayBatchProvider(array: inputs)
    let batchOut = try model.predictions(from: batchIn, options: options)
    var results: [Output] = []
    results.reserveCapacity(inputs.count)
    for i in 0..<batchOut.count {
      let outProvider = batchOut.features(at: i)
      let result = Output(features: outProvider)
      results.append(result)
    }
    return results
  }
}

