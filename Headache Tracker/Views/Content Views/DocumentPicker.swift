//
//  DocumentPicker.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 4/2/22.
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
  
  typealias UIViewControllerType = UIDocumentPickerViewController
  typealias Context = UIViewControllerRepresentableContext<DocumentPicker>
  typealias Coordinator = DocumentPickerCoordinator
  
  enum PickerType {
    case open
    case export
  }
  
  let action: ([URL]) -> Void
  
  private let type: PickerType
  private let contentTypes: [UTType]
  private let exportURLs: [URL]
  private let asCopy: Bool
  
  private init(type: PickerType, contentTypes: [UTType] = [], exportURLs: [URL] = [], asCopy: Bool = false, action: @escaping ([URL]) -> Void) {
    self.type = type
    self.contentTypes = contentTypes
    self.exportURLs = exportURLs
    self.asCopy = asCopy
    self.action = action
  }
  
  init(forOpeningContentTypes contentTypes: [UTType], asCopy: Bool = false, action: @escaping ([URL]) -> Void) {
    self.init(type: .open, contentTypes: contentTypes, asCopy: asCopy, action: action)
  }
  
  init(forExporting exportURLs: [URL], asCopy: Bool = false, action: @escaping ([URL]) -> Void) {
    self.init(type: .export, exportURLs: exportURLs, asCopy: asCopy, action: action)
  }
  
  func makeCoordinator() -> DocumentPickerCoordinator {
    DocumentPickerCoordinator(action: action)
  }
  
  func makeUIViewController(context: UIViewControllerRepresentableContext<DocumentPicker>) -> UIDocumentPickerViewController {
    switch type {
    case .open: return UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: asCopy)
    case .export: return UIDocumentPickerViewController(forExporting: exportURLs, asCopy: asCopy)
    }
  }
  
  func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: UIViewControllerRepresentableContext<DocumentPicker>) {
    
  }
  
}

class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate, UINavigationControllerDelegate {
  
  let action: ([URL]) -> Void
  
  init(action: @escaping ([URL]) -> Void) {
    self.action = action
  }
  
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    action(urls)
  }
  
}
