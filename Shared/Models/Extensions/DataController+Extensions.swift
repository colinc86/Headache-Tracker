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
  static let shared = DataController(containerName: Constants.CoreData.sqliteContainerName, appGroup: Constants.appGroupIdentifier)
  
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
