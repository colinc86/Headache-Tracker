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
  
  /// Backs up the core data store to a backup file.
  func backupDatabase() async throws {
    return try await withCheckedThrowingContinuation({ continuation in
      DispatchQueue(label: ApplicationKey(from: "backupDatabaseQueue")).async {
        logInfo("Backing up core data store...")
        
        let backUpFolderUrl = FileManager.default.urls(for: .documentDirectory, in:.userDomainMask).first!
        let backupUrl = backUpFolderUrl.appendingPathComponent("\(Constants.CoreData.sqliteBackupContainerName).sqlite")
        let container = NSPersistentContainer(name: Constants.CoreData.sqliteContainerName)
        
        guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier) else {
          continuation.resume()
          return
        }
        
        let storeURL = fileContainer.appendingPathComponent("\(Constants.CoreData.sqliteContainerName).sqlite")
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        container.persistentStoreDescriptions = [storeDescription]
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in })
        
        let store:NSPersistentStore
        store = container.persistentStoreCoordinator.persistentStores.last!
        do {
          try container.persistentStoreCoordinator.migratePersistentStore(store,to: backupUrl,options: nil,withType: NSSQLiteStoreType)
          continuation.resume()
        } catch {
          continuation.resume(throwing: error)
        }
      }
    })
  }
  
  /// Restores the core data database.
  /// Requires views to be refreshed.
  func restoreDatabase() async throws {
    return try await withCheckedThrowingContinuation({ continuation in
      DispatchQueue(label: ApplicationKey(from: "restoreDatabaseQueue")).async {
        logInfo("Restoring core data store...")
        
        let backUpFolderUrl = FileManager.default.urls(for: .documentDirectory, in:.userDomainMask).first!
        let backupUrl = backUpFolderUrl.appendingPathComponent("\(Constants.CoreData.sqliteBackupContainerName).sqlite")
        
        let container = NSPersistentContainer(name: Constants.CoreData.sqliteContainerName)
        guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier) else {
          continuation.resume()
          return
        }
        
        let storeURL = fileContainer.appendingPathComponent("\(Constants.CoreData.sqliteContainerName).sqlite")
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        container.persistentStoreDescriptions = [storeDescription]
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
          let stores = container.persistentStoreCoordinator.persistentStores
          
          for store in stores {
            print(store)
            print(container)
          }
          do{
            try container.persistentStoreCoordinator.replacePersistentStore(at: storeURL,destinationOptions: nil,withPersistentStoreFrom: backupUrl,sourceOptions: nil,ofType: NSSQLiteStoreType)
            continuation.resume()
          } catch {
            continuation.resume(throwing: error)
          }
        })
      }
    })
  }
  
}
