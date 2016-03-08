//
//  Loggable.swift
//  MoonKit
//
//  Created by Jason Cardwell on 10/21/15.
//  Copyright © 2015 Jason Cardwell. All rights reserved.
//

import Foundation

/**
nameForCurrentQueue

- returns: String?
*/
private func nameForCurrentQueue() -> String? {
  if let name = NSOperationQueue.currentQueue()?.name { return name }
  else { return NSThread.currentThread().name }
}

public protocol Loggable {
  static var defaultLogContext: LogManager.LogContext { get }
  static var defaultLogLevel: LogManager.LogLevel { get }
  var logContext: LogManager.LogContext { get }
  var logLevel: LogManager.LogLevel { get }
  var logTag: LogManager.LogMessage.Tag? { get }
}

public extension Loggable {

  public typealias MessageContent = () -> String
  public typealias LogLevel = LogManager.LogLevel
  public typealias LogContext = LogManager.LogContext
  public typealias LogFlag = LogManager.LogFlag
  public typealias LogTag = LogManager.LogMessage.Tag

  static var defaultLogContext: LogContext {
    get { return LogManager.logContextForType(self.dynamicType.self) }
    set { LogManager.setLogContext(newValue, forType: self.dynamicType.self) }
  }

  static var defaultLogLevel: LogLevel {
    get { return LogManager.logLevelForType(self) }
    set { LogManager.setLogLevel(newValue, forType: self) }
  }

  var logLevel: LogLevel { return self.dynamicType.defaultLogLevel }

  var logContext: LogContext { return self.dynamicType.defaultLogContext }
  var logTag: LogTag? { return LogTag(className: "\(self.dynamicType)", queueName: nameForCurrentQueue()) }

  /**
  log:asynchronous:flag:function:line:file:tag:

  - parameter message: String
  - parameter asynchronous: Bool = true
  - parameter flag: LogFlag
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  static func log(message: String,
     asynchronous: Bool = true,
             flag: LogFlag,
         function: String = #function,
             line: UInt = #line,
             file: String = #file)
  {
    let tag = LogTag(objectName: String(self), className: String(self), queueName: nameForCurrentQueue())
    LogManager.logMessage(message,
             asynchronous: asynchronous,
                     flag: flag,
                 function: function,
                     line: line,
                     file: file,
                  context: defaultLogContext,
                      tag: tag)
  }

  /**
  logError:asynchronous:function:line:file:

  - parameter message: String
  - parameter asynchronous: Bool = true
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  static func logError(@autoclosure message: MessageContent,
          asynchronous: Bool = true,
              function: String = #function,
                  line: UInt = #line,
                  file: String = #file)
  {
    #if LogLevelVerbose || LogLevelDebug || LogLevelInfo || LogLevelWarning || LogLevelError
    guard defaultLogLevel ∋ .Error else { return }
    log(message(), asynchronous: asynchronous, flag: .Error, function: function, line: line, file: file)
    #endif
  }

  /**
  logError:message:asynchronous:function:line:file:

  - parameter error: ErrorType
  - parameter message: String
  - parameter asynchronous: Bool = true
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  static func logError(error: ErrorType,
               message: String? = nil,
          asynchronous: Bool = true,
              function: String = #function,
                  line: UInt = #line,
                  file: String = #file)
  {
    #if LogLevelVerbose || LogLevelDebug || LogLevelInfo || LogLevelWarning || LogLevelError
    guard defaultLogLevel ∋ .Error else { return }
    var errorDescription = "\(error)"
    if let e = error as? WrappedErrorType, u = e.underlyingError {
      errorDescription += "underlying error: \(u)"
    }

    var logMessage = "-Error- "
    if let message = message { logMessage += message + "\n" }
    logMessage += errorDescription

    logError(logMessage, asynchronous: asynchronous, function: function, line: line, file: file)
    #endif
  }

  /**
   logError:asynchronous:

   - parameter e: ExtendedErrorType
   - parameter asynchronous: Bool = true
   */
  static func logError(error: ExtendedErrorType, asynchronous: Bool = true) {
    #if LogLevelVerbose || LogLevelDebug || LogLevelInfo || LogLevelWarning || LogLevelError
    guard defaultLogLevel ∋ .Error else { return }
    logError(error,
     message: error.reason,
asynchronous: asynchronous,
    function: error.function,
        line: error.line,
        file: error.file)
    #endif
  }


  /**
  logWarning:asynchronous:function:line:file:

  - parameter message: String
  - parameter asynchronous: Bool = true
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  static func logWarning(@autoclosure message: MessageContent,
   asynchronous: Bool = true,
       function: String = #function,
           line: UInt = #line,
           file: String = #file)
  {
    #if LogLevelVerbose || LogLevelDebug || LogLevelInfo || LogLevelWarning
    guard defaultLogLevel ∋ .Warning else { return }
    log(message(), asynchronous: asynchronous, flag: .Warning, function: function, line: line, file: file)
    #endif
  }

  /**
  logDebug:asynchronous:function:line:file:

  - parameter message: String
  - parameter asynchronous: Bool = true
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  static func logDebug(@autoclosure message: MessageContent,
   asynchronous: Bool = true,
       function: String = #function,
           line: UInt = #line,
           file: String = #file)
  {
    #if LogLevelVerbose || LogLevelDebug
    guard defaultLogLevel ∋ .Debug else { return }
    log(message(), asynchronous: asynchronous, flag: .Debug, function: function, line: line, file: file)
    #endif
  }

  /**
  logInfo:asynchronous:function:line:file:

  - parameter message: String
  - parameter asynchronous: Bool = true
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  static func logInfo(@autoclosure message: MessageContent,
  asynchronous: Bool = true,
      function: String = #function,
          line: UInt = #line,
          file: String = #file)
  {
    #if LogLevelVerbose || LogLevelDebug || LogLevelInfo
    guard defaultLogLevel ∋ .Info else { return }
    log(message(), asynchronous: asynchronous, flag: .Info, function: function, line: line, file: file)
    #endif
  }

  /**
  logVerbose:asynchronous:function:line:file:

  - parameter message: String
  - parameter asynchronous: Bool = true
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  static func logVerbose(@autoclosure message: MessageContent,
     asynchronous: Bool = true,
         function: String = #function,
             line: UInt = #line,
             file: String = #file)
  {
    #if LogLevelVerbose
    guard defaultLogLevel ∋ .Verbose else { return }
    log(message(), asynchronous: asynchronous, flag: .Verbose, function: function, line: line, file: file)
    #endif
  }

  
  /**
  log:asynchronous:flag:function:line:file:

  - parameter message: String
  - parameter asynchronous: Bool = true
  - parameter flag: LogFlag
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  func log(message: String,
           asynchronous: Bool = true,
           flag: LogFlag,
           function: String = #function,
           line: UInt = #line,
           file: String = #file)

  {
    LogManager.logMessage(message,
             asynchronous: asynchronous,
                     flag: flag,
                 function: function,
                     line: line,
                     file: file,
                  context: logContext,
                      tag: logTag)
  }

  /**
  logError:asynchronous:function:line:file:

  - parameter message: String
  - parameter asynchronous: Bool = true
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  func logError(@autoclosure message: MessageContent,
   asynchronous: Bool = true,
       function: String = #function,
           line: UInt = #line,
           file: String = #file)
  {
    #if LogLevelVerbose || LogLevelDebug || LogLevelInfo || LogLevelWarning || LogLevelError
    guard logLevel ∋ .Error else { return }
    log(message(), asynchronous: asynchronous, flag: .Error, function: function, line: line, file: file)
    #endif
  }

  /**
  logError:message:asynchronous:function:line:file:

  - parameter error: ErrorType
  - parameter message: String
  - parameter asynchronous: Bool = true
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  func logError(error: ErrorType,
               message: String? = nil,
          asynchronous: Bool = true,
              function: String = #function,
                  line: UInt = #line,
                  file: String = #file)
  {
    #if LogLevelVerbose || LogLevelDebug || LogLevelInfo || LogLevelWarning || LogLevelError
    guard logLevel ∋ .Error else { return }
    var errorDescription = "\(error)"
    if let e = error as? WrappedErrorType, u = e.underlyingError {
      errorDescription += "underlying error: \(u)"
    }

    var logMessage = "-Error- "
    if let message = message { logMessage += message + "\n" }
    logMessage += errorDescription

    logError(logMessage, asynchronous: asynchronous, function: function, line: line, file: file)
    #endif
  }

  /**
   logError:asynchronous:

   - parameter e: ExtendedErrorType
   - parameter asynchronous: Bool = true
   */
  func logError(error: ExtendedErrorType, asynchronous: Bool = true) {
    #if LogLevelVerbose || LogLevelDebug || LogLevelInfo || LogLevelWarning || LogLevelError
    guard logLevel ∋ .Error else { return }
    logError(error,
     message: error.reason,
asynchronous: asynchronous,
    function: error.function,
        line: error.line,
        file: error.file)
    #endif
  }


  /**
  logWarning:asynchronous:function:line:file:

  - parameter message: String
  - parameter asynchronous: Bool = true
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  func logWarning(@autoclosure message: MessageContent,
   asynchronous: Bool = true,
       function: String = #function,
           line: UInt = #line,
           file: String = #file)
  {
    #if LogLevelVerbose || LogLevelDebug || LogLevelInfo || LogLevelWarning
    guard logLevel ∋ .Warning else { return }
    log(message(), asynchronous: asynchronous, flag: .Warning, function: function, line: line, file: file)
    #endif
  }

  /**
  logDebug:asynchronous:function:line:file:

  - parameter message: String
  - parameter asynchronous: Bool = true
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  func logDebug(@autoclosure message: MessageContent,
   asynchronous: Bool = true,
       function: String = #function,
           line: UInt = #line,
           file: String = #file)
  {
    #if LogLevelVerbose || LogLevelDebug
    guard logLevel ∋ .Debug else { return }
    log(message(), asynchronous: asynchronous, flag: .Debug, function: function, line: line, file: file)
    #endif
  }

  /**
  logInfo:asynchronous:function:line:file:

  - parameter message: String
  - parameter asynchronous: Bool = true
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  func logInfo(@autoclosure message: MessageContent,
  asynchronous: Bool = true,
      function: String = #function,
          line: UInt = #line,
          file: String = #file)
  {
    #if LogLevelVerbose || LogLevelDebug || LogLevelInfo
    guard logLevel ∋ .Info else { return }
    log(message(), asynchronous: asynchronous, flag: .Info, function: function, line: line, file: file)
    #endif
  }

  /**
  logVerbose:asynchronous:function:line:file:

  - parameter message: String
  - parameter asynchronous: Bool = true
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  func logVerbose(@autoclosure message: MessageContent,
     asynchronous: Bool = true,
         function: String = #function,
             line: UInt = #line,
             file: String = #file)
  {
    #if LogLevelVerbose
    guard logLevel ∋ .Verbose else { return }
    log(message(), asynchronous: asynchronous, flag: .Verbose, function: function, line: line, file: file)
    #endif
  }

  /**
  logSyncError:function:line:file:

  - parameter message: String
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  static func logSyncError(@autoclosure message: MessageContent,
              function: String = #function,
                  line: UInt = #line,
                  file: String = #file)
  {
    #if LogLevelVerbose || LogLevelDebug || LogLevelInfo || LogLevelWarning || LogLevelError
    guard defaultLogLevel ∋ .Error else { return }
    log(message(), asynchronous: false, flag: .Error, function: function, line: line, file: file)
    #endif
  }

  /**
  logError:messageSync:function:line:file:

  - parameter error: ErrorType
  - parameter message: String
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  static func logSyncError(error: ErrorType,
               message: String? = nil,
              function: String = #function,
                  line: UInt = #line,
                  file: String = #file)
  {
    #if LogLevelVerbose || LogLevelDebug || LogLevelInfo || LogLevelWarning || LogLevelError
    guard defaultLogLevel ∋ .Error else { return }
    var errorDescription = "\(error)"
    if let e = error as? WrappedErrorType, u = e.underlyingError {
      errorDescription += "underlying error: \(u)"
    }

    var logMessage = "-Error- "
    if let message = message { logMessage += message + "\n" }
    logMessage += errorDescription

    logError(logMessage, asynchronous: false, function: function, line: line, file: file)
    #endif
  }

  /**
   logError:asynchronous:

   - parameter e: ExtendedErrorType
   */
  static func logSyncError(error: ExtendedErrorType) {
    #if LogLevelVerbose || LogLevelDebug || LogLevelInfo || LogLevelWarning || LogLevelError
    guard defaultLogLevel ∋ .Error else { return }
    logError(error,
     message: error.reason,
asynchronous: false,
    function: error.function,
        line: error.line,
        file: error.file)
    #endif
  }


  /**
  logSyncWarning:function:line:file:

  - parameter message: String
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  static func logSyncWarning(@autoclosure message: MessageContent,
       function: String = #function,
           line: UInt = #line,
           file: String = #file)
  {
    #if LogLevelVerbose || LogLevelDebug || LogLevelInfo || LogLevelWarning
    guard defaultLogLevel ∋ .Warning else { return }
    log(message(), asynchronous: false, flag: .Warning, function: function, line: line, file: file)
    #endif
  }

  /**
  logSyncDebug:function:line:file:

  - parameter message: String
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  static func logSyncDebug(@autoclosure message: MessageContent,
       function: String = #function,
           line: UInt = #line,
           file: String = #file)
  {
    #if LogLevelVerbose || LogLevelDebug
    guard defaultLogLevel ∋ .Debug else { return }
    log(message(), asynchronous: false, flag: .Debug, function: function, line: line, file: file)
    #endif
  }

  /**
  logSyncInfo:function:line:file:

  - parameter message: String
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  static func logSyncInfo(@autoclosure message: MessageContent,
      function: String = #function,
          line: UInt = #line,
          file: String = #file)
  {
    #if LogLevelVerbose || LogLevelDebug || LogLevelInfo
    guard defaultLogLevel ∋ .Info else { return }
    log(message(), asynchronous: false, flag: .Info, function: function, line: line, file: file)
    #endif
  }

  /**
  logSyncVerbose:function:line:file:

  - parameter message: String
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  static func logSyncVerbose(@autoclosure message: MessageContent,
         function: String = #function,
             line: UInt = #line,
             file: String = #file)
  {
    #if LogLevelVerbose
    guard defaultLogLevel ∋ .Verbose else { return }
    log(message(), asynchronous: false, flag: .Verbose, function: function, line: line, file: file)
    #endif
  }

  
  /**
  logSyncError:function:line:file:

  - parameter message: String
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  func logSyncError(@autoclosure message: MessageContent,
       function: String = #function,
           line: UInt = #line,
           file: String = #file)
  {
    #if LogLevelVerbose || LogLevelDebug || LogLevelInfo || LogLevelWarning || LogLevelError
    guard logLevel ∋ .Error else { return }
    log(message(), asynchronous: false, flag: .Error, function: function, line: line, file: file)
    #endif
  }

  /**
  logSyncError:messageSync:function:line:file:

  - parameter error: ErrorType
  - parameter message: String
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  func logSyncError(error: ErrorType,
               message: String? = nil,
              function: String = #function,
                  line: UInt = #line,
                  file: String = #file)
  {
    #if LogLevelVerbose || LogLevelDebug || LogLevelInfo || LogLevelWarning || LogLevelError
    guard logLevel ∋ .Error else { return }
    var errorDescription = "\(error)"
    if let e = error as? WrappedErrorType, u = e.underlyingError {
      errorDescription += "underlying error: \(u)"
    }

    var logMessage = "-Error- "
    if let message = message { logMessage += message + "\n" }
    logMessage += errorDescription

    logError(logMessage, asynchronous: false, function: function, line: line, file: file)
    #endif
  }

  /**
   logSyncError:

   - parameter e: ExtendedErrorType
   */
  func logSyncError(error: ExtendedErrorType) {
    #if LogLevelVerbose || LogLevelDebug || LogLevelInfo || LogLevelWarning || LogLevelError
    guard logLevel ∋ .Error else { return }
    logError(error,
     message: error.reason,
asynchronous: false,
    function: error.function,
        line: error.line,
        file: error.file)
    #endif
  }


  /**
  logSyncWarning:function:line:file:

  - parameter message: String
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  func logSyncWarning(@autoclosure message: MessageContent,
       function: String = #function,
           line: UInt = #line,
           file: String = #file)
  {
    #if LogLevelVerbose || LogLevelDebug || LogLevelInfo || LogLevelWarning
    guard logLevel ∋ .Warning else { return }
    log(message(), asynchronous: false, flag: .Warning, function: function, line: line, file: file)
    #endif
  }

  /**
  logSyncDebug:function:line:file:

  - parameter message: String
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  func logSyncDebug(@autoclosure message: MessageContent,
       function: String = #function,
           line: UInt = #line,
           file: String = #file)
  {
    #if LogLevelVerbose || LogLevelDebug
    guard logLevel ∋ .Debug else { return }
    log(message(), asynchronous: false, flag: .Debug, function: function, line: line, file: file)
    #endif
  }

  /**
  logSyncInfo:function:line:file:

  - parameter message: String
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  func logSyncInfo(@autoclosure message: MessageContent,
      function: String = #function,
          line: UInt = #line,
          file: String = #file)
  {
    #if LogLevelVerbose || LogLevelDebug || LogLevelInfo
    guard logLevel ∋ .Info else { return }
    log(message(), asynchronous: false, flag: .Info, function: function, line: line, file: file)
    #endif
  }

  /**
  logSyncVerbose:function:line:file:

  - parameter message: String
  - parameter function: String = #function
  - parameter line: UInt = #line
  - parameter file: String = #file
  */
  func logSyncVerbose(@autoclosure message: MessageContent,
         function: String = #function,
             line: UInt = #line,
             file: String = #file)
  {
    #if LogLevelVerbose
    guard logLevel ∋ .Verbose else { return }
    log(message(), asynchronous: false, flag: .Verbose, function: function, line: line, file: file)
    #endif
  }

}

public extension Loggable where Self:AnyObject {
  var logTag: LogTag? {
    return LogTag(className: String(self.dynamicType),
                  queueName: nameForCurrentQueue(),
                  address: String(unsafeAddressOf(self)))
  }
}

public extension Loggable where Self:Named {
  var logTag: LogTag? {
    return LogTag(objectName: name,
                  className: String(self.dynamicType),
                  queueName: nameForCurrentQueue())
  }
}

public extension Loggable where Self:Nameable {
  var logTag: LogTag? {
    return LogTag(objectName: name,
                  className: String(self.dynamicType),
                  queueName: nameForCurrentQueue())
  }
}

public extension Loggable where Self:Named, Self:AnyObject {
  var logTag: LogTag? {
    return LogTag(objectName: name,
                  className: String(self.dynamicType),
                  queueName: nameForCurrentQueue(),
                  address: String(unsafeAddressOf(self)))
  }
}

public extension Loggable where Self:Nameable, Self:AnyObject {
  var logTag: LogTag? {
    return LogTag(objectName: name,
                  className: String(self.dynamicType),
                  queueName: nameForCurrentQueue(),
                  address: String(unsafeAddressOf(self)))
  }
}
