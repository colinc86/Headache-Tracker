//
//  DataController+Extensions.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/3/22.
//

import ApplicationKey
import CoreData
import DataController
import Foundation

extension DataController {
  
  /// The shared data controller.
  /// The store file names.
  ///
  /// The original combined store becomes the Local (device-only) store when
  /// sync is enabled — it holds the bulky training history in place. User
  /// data migrates once into the new cloud store (see `CloudMigrator`).
  static let localStoreFileName = "\(Constants.CoreData.sqliteContainerName).sqlite"
  static let cloudStoreFileName = "\(Constants.CoreData.sqliteContainerName)-cloud.sqlite"

  static let shared: DataController = {
    let syncEnabled = Preferences.Sync().enabled
    let isExtension = Bundle.main.bundleURL.pathExtension == "appex"

    guard syncEnabled else {
      // Single combined store, exactly as before sync existed. History
      // tracking stays off until the user opts in.
      return DataController(containerName: Constants.CoreData.sqliteContainerName, appGroup: Constants.appGroupIdentifier)
    }

    // Split stores: user data mirrors to CloudKit (app process only — the
    // widget reads the same files but never runs the mirroring), device
    // data stays local.
    return DataController(
      containerName: Constants.CoreData.sqliteContainerName,
      appGroup: Constants.appGroupIdentifier,
      cloudKit: isExtension ? nil : CloudKitConfiguration(containerIdentifier: Constants.cloudKitContainerIdentifier),
      storeConfigurations: [
        StoreConfiguration(modelConfiguration: "Local", fileName: localStoreFileName),
        StoreConfiguration(modelConfiguration: "Cloud", fileName: cloudStoreFileName, syncsToCloudKit: true)
      ],
      historyTracking: true,
      transactionAuthor: isExtension ? "widget" : "app")
  }()
  
  private var backupURL: URL {
    let backUpFolderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    return backUpFolderURL.appendingPathComponent("\(Constants.CoreData.sqliteBackupContainerName).sqlite")
  }
  
  /// Backs up the core data store to a backup file.
  func backupDatabase() async throws -> URL {
    let backupURL = backupURL

    // Make sure the backup location is clear
    if FileManager.default.fileExists(atPath: backupURL.path) {
      try FileManager.default.removeItem(at: backupURL)
    }

    // Quiesce writes while the copy runs by performing the backup inside the
    // serialized write block; the second container opens the store read-only.
    try await DataController.shared.performInBackground { _ in
      logInfo("Backing up core data store...")

      let container = NSPersistentContainer(name: Constants.CoreData.sqliteContainerName)
      guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier) else {
        throw NSError(domain: ApplicationKey("backup"), code: NSFileNoSuchFileError)
      }

      let storeURL = fileContainer.appendingPathComponent("\(Constants.CoreData.sqliteContainerName).sqlite")
      let storeDescription = NSPersistentStoreDescription(url: storeURL)
      storeDescription.isReadOnly = true
      storeDescription.shouldAddStoreAsynchronously = false
      container.persistentStoreDescriptions = [storeDescription]

      var loadError: Error?
      container.loadPersistentStores { _, error in
        loadError = error
      }
      if let loadError = loadError {
        throw loadError
      }

      guard let store = container.persistentStoreCoordinator.persistentStores.last else {
        throw NSError(domain: ApplicationKey("backup"), code: NSFileNoSuchFileError)
      }

      try container.persistentStoreCoordinator.migratePersistentStore(store, to: backupURL, options: nil, withType: NSSQLiteStoreType)
    }

    return backupURL
  }
  
  /// Restores the core data database.
  ///
  /// Requires views to be refreshed.
  /// - Parameter url: The url of the database file to restore from.
  func restoreDatabase(from url: URL) async throws {
    // Copy the file in to the app container
    let backupURL = backupURL
    _ = try FileManager.default.replaceItemAt(backupURL, withItemAt: url)
    
    // Perform the restore
    return try await withCheckedThrowingContinuation({ continuation in
      DispatchQueue(label: ApplicationKey(from: "restoreDatabaseQueue")).async {
        logInfo("Restoring core data store from \(backupURL)...")
        
        let container = NSPersistentContainer(name: Constants.CoreData.sqliteContainerName)
        guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier) else {
          continuation.resume(throwing: NSError(domain: ApplicationKey("backup"), code: NSFileNoSuchFileError))
          return
        }
        
        let storeURL = fileContainer.appendingPathComponent("\(Constants.CoreData.sqliteContainerName).sqlite")
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        container.persistentStoreDescriptions = [storeDescription]
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
          if let error = error {
            continuation.resume(throwing: error)
          }
          else {
            do{
              try container.persistentStoreCoordinator.replacePersistentStore(at: storeURL, destinationOptions: nil, withPersistentStoreFrom: backupURL, sourceOptions: nil, ofType: NSSQLiteStoreType)
              continuation.resume()
            } catch {
              continuation.resume(throwing: error)
            }
          }
        })
      }
    })
  }
  
}
