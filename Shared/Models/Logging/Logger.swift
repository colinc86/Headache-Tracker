//
//  Logger.swift
//  Logging
//
//  Created by Colin Campbell on 4/29/21.
//
import ApplicationKey
import CocoaLumberjackSwift
import Foundation
import Logging

@inlinable
public func logTrace(_ message: @autoclosure () -> String, _ file: StaticString = #file, _ function: StaticString = #function, _ line: UInt = #line) {
  _DDLogMessage(message(), level: .all, flag: .verbose, context: 0, file: file, function: function, line: line, tag: tagFromFile(file), asynchronous: true, ddlog: DDLog.sharedInstance)
}

@inlinable
public func logDebug(_ message: @autoclosure () -> String, _ file: StaticString = #file, _ function: StaticString = #function, _ line: UInt = #line) {
  _DDLogMessage(message(), level: .all, flag: .debug, context: 0, file: file, function: function, line: line, tag: tagFromFile(file), asynchronous: true, ddlog: DDLog.sharedInstance)
}

@inlinable
public func logInfo(_ message: @autoclosure () -> String, _ file: StaticString = #file, _ function: StaticString = #function, _ line: UInt = #line) {
  _DDLogMessage(message(), level: .all, flag: .info, context: 0, file: file, function: function, line: line, tag: tagFromFile(file), asynchronous: true, ddlog: DDLog.sharedInstance)
}

@inlinable
public func logWarning(_ message: @autoclosure () -> String, _ file: StaticString = #file, _ function: StaticString = #function, _ line: UInt = #line) {
  _DDLogMessage(message(), level: .all, flag: .warning, context: 0, file: file, function: function, line: line, tag: tagFromFile(file), asynchronous: true, ddlog: DDLog.sharedInstance)
}

@inlinable
public func logError(_ message: @autoclosure () -> String, _ file: StaticString = #file, _ function: StaticString = #function, _ line: UInt = #line) {
  _DDLogMessage(message(), level: .all, flag: .error, context: 0, file: file, function: function, line: line, tag: tagFromFile(file), asynchronous: true, ddlog: DDLog.sharedInstance)
}

public func tagFromFile(_ file: StaticString) -> String {
  return String(((String(file) as NSString).lastPathComponent).split(separator: ".").first ?? "")
}
