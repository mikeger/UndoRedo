//
//  CommandManager.swift
//  UndoRedoApp
//
//  Created by Mike on 31.08.21.
//

import Foundation
import Combine

public protocol CommandManagerType: Publisher {
    
    associatedtype Content
    associatedtype Output = Content
    associatedtype Failure = Never
    
    func clearUndo()
    func clearRedo()

    var canUndo: Bool { get }
    func undo() -> Bool
    
    var canRedo: Bool { get }
    func redo() -> Bool

    var position: Int { get }
    var depth: Int { get }
    
}

public class CommandManager<Content: Equatable>: CommandManagerType {
    
    class CommandSubscription<Target: Subscriber>: Subscription
        where Target.Input == Content {
        
        var target: Target?

        func request(_ demand: Subscribers.Demand) {}

        func cancel() {
            target = nil
        }
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber
                                                , Never == S.Failure
                                                , Content == S.Input {
        
        let subscription = CommandSubscription<S>()
        subscription.target = subscriber
        subscriber.receive(subscription: subscription)
        
        self.subscriptions.append({ content in
            let _ = subscription.target?.receive(content)
        })
    }
    
    public typealias Output = Content
    public typealias Failure = Never
    
    public func clearUndo() {
        
        self.commands = []
        self.position = 0
    }
    
    public func clearRedo() {
        
        self.commands = self.commands.dropLast(self.depth - self.position)
    }
    
    public var canUndo: Bool {
        
        guard self.position > 1
              , let _ = self.currentValue else {

            return false
        }
        return true
    }
    
    @discardableResult public func undo() -> Bool {
        
        guard self.canUndo
              , let currentValue = self.currentValue else {
            return false
        }
        
        let lastCommand = self.commands[self.position - 1]
        
        let probablyValue = lastCommand.undo(on: currentValue)
        
        if let value = probablyValue {
            
            self.publish(value)
        }
        
        self.position = self.position - 1
        return true
    }
    
    public var canRedo: Bool {
        
        guard position != depth
              , self.commands.count > position
              , let _ = self.currentValue else {
            
            return false
        }
        
        return true
    }
    
    @discardableResult public func redo() -> Bool {
        
        guard self.canRedo
              , let currentValue = self.currentValue else {
            return false
        }
        
        let redoCommand = self.commands[position]
        let probablyValue = redoCommand.do(on: currentValue)
        
        if let value = probablyValue {
            self.publish(value)
        }
        
        self.position = self.position + 1
        return true
    }
    
    func publish(_ newState: Content) {
        
        self.currentValue = newState
        self.lastValue = newState
        
        self.subscriptions.forEach { subscription in
            
            subscription(newState)
        }
    }
    
    @Published public var position: Int = 0
    @Published public var depth: Int = 0
    
    private var commands: [Command<Content>] = [] {
        didSet {
            self.depth = self.commands.count
        }
    }
    
    private var cancellables: [AnyCancellable] = []
    private var subscriptions: [(Content) -> ()] = []
    
    private var lastValue: Content? = nil
    private var currentValue: Content? = nil
    
    public init<P: Publisher>(publisher: P) where P.Output == Content {
        
        cancellables.append(publisher.sink { completion in
            
        } receiveValue: { [weak self] value in
            
            self?.currentValue = value
        })
        
        cancellables.append(publisher
            .debounce(for: 1, scheduler: RunLoop.main)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    
                }, receiveValue: { [weak self] value in
                    
                    guard self?.lastValue != value else {
                        
                        return
                    }
                    
                    // Current implementation is not optimal, since it's storing every debounced state of the text over time.
                    // This approach might be memory-consuming. It might be improved with use of Apple's collection
                    // difference API @c https://developer.apple.com/documentation/swift/array/3200716-difference or other
                    // similiar algorithm that would calculate the difference between old and the new state.
                    
                    let lastValue = self?.lastValue
                    let command = Command<Content>(doAction: { _ in
                        
                        return value
                    }, undoAction: { _ in
                        
                        return lastValue
                    })
                    
                    self?.clearRedo()
                    self?.commands.append(command)
                    self?.depth = self?.commands.count ?? 0
                    self?.position = self?.commands.count ?? 0
                    
                    self?.lastValue = value
                }))
    }
}
