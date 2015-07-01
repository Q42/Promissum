//
//  PromiseSource.swift
//  Promissum
//
//  Created by Tom Lokhorst on 2014-10-11.
//  Copyright (c) 2014 Tom Lokhorst. All rights reserved.
//

import Foundation

// This Notifier is used to implement Promise.map
protocol OriginalSource {
  func registerHandler(handler: () -> Void)
}

public class PromiseSource<T> : OriginalSource {
  typealias ResultHandler = Result<T> -> Void
  public var state: State<T>
  public var warnUnresolvedDeinit: Bool

  private var handlers: [Result<T> -> Void] = []

  private let originalSource: OriginalSource?

  public convenience init(warnUnresolvedDeinit: Bool = true) {
    self.init(state: .Unresolved, originalSource: nil, warnUnresolvedDeinit: warnUnresolvedDeinit)
  }

  public convenience init(value: T, warnUnresolvedDeinit: Bool = true) {
    self.init(state: .Resolved(Box(value)), originalSource: nil, warnUnresolvedDeinit: warnUnresolvedDeinit)
  }

  public convenience init(error: NSError, warnUnresolvedDeinit: Bool = true) {
    self.init(state: .Rejected(error), originalSource: nil, warnUnresolvedDeinit: warnUnresolvedDeinit)
  }

  internal init(state: State<T>, originalSource: OriginalSource?, warnUnresolvedDeinit: Bool) {
    self.originalSource = originalSource
    self.warnUnresolvedDeinit = warnUnresolvedDeinit

    self.state = state
  }

  deinit {
    if warnUnresolvedDeinit {
      switch state {
      case .Unresolved:
        println("PromiseSource.deinit: WARNING: Unresolved PromiseSource deallocated, maybe retain this object?")
      default:
        break
      }
    }
  }

  public var promise: Promise<T> {
    return Promise(source: self)
  }

  public func resolve(value: T) {

    switch state {
    case .Unresolved:
      state = State<T>.Resolved(Box(value))

      executeResultHandlers(.Value(Box(value)))
    default:
      break
    }
  }

  public func reject(error: NSError) {

    switch state {
    case .Unresolved:
      state = State<T>.Rejected(error)

      executeResultHandlers(.Error(error))
    default:
      break
    }
  }

  internal func registerHandler(handler: () -> Void) {
    addOrCallResultHandler({ _ in handler() })
  }

  internal func addOrCallResultHandler(handler: Result<T> -> Void) {

    switch state {
    case State<T>.Unresolved(let source):
      // Save handler for later
      addHander(handler)

    case State<T>.Resolved(let boxed):
      // Value is already available, call handler immediately
      callHandlers(Result.Value(boxed), [handler])

    case State<T>.Rejected(let error):
      // Error is already available, call handler immediately
      callHandlers(Result.Error(error), [handler])
    }
  }

  internal func addHander(handler: Result<T> -> Void) {

    if let originalSource = originalSource {
      originalSource.registerHandler {
        self.addOrCallResultHandler(handler)
      }
    }
    else {
      handlers.append(handler)
    }
  }

  private func executeResultHandlers(result: Result<T>) {

    // Call all previously scheduled handlers
    callHandlers(result, handlers)

    // Cleanup
    handlers = []
  }
}

internal func callHandlers<T>(arg: T, handlers: [T -> Void]) {
  for handler in handlers {
    handler(arg)
  }
}
