//
//  CommandManagerTests.swift
//  CommandManagerTests
//
//  Created by Mike on 01.09.21.
//

import XCTest
import Combine
import CommandManager

extension XCTestCase {
    
    public func verifyDeallocation<T: AnyObject>(of instanceGenerator: () -> (T)) {
       weak var weakInstance: T?
       var instance: T?

       autoreleasepool {
           instance = instanceGenerator()
           // then
           weakInstance = instance
           XCTAssertNotNil(weakInstance)
           // when
           instance = nil
       }

       XCTAssertNil(instance)
       XCTAssertNil(weakInstance)
   }
    
    func provision<C>(commandManager: C
                      , with values: [C.Content]
                      , setAction: @escaping (C.Content) -> ()
                      , whenDone: @escaping () -> ()) where C: CommandManagerType {
        
        var valuesToSet = values
        
        var iteration: (() -> ())! = nil
        
        iteration = { [weak self] in
            
            let first = valuesToSet.remove(at: 0)
            
            let expectation = self!.expectation(description: "Value recorded")
            expectation.isInverted = true
            
            setAction(first)
            
            self?.waitForExpectations(timeout: 0.001) { _ in
                
                if !valuesToSet.isEmpty {
                    
                    iteration()
                }
                else {
                    
                    whenDone()
                }
            }
        }
        
        iteration()
    }
}

class CommandManagerTests: XCTestCase {

    @Published var observedValue = 42
    
}

/// Undo recording
extension CommandManagerTests {
    
    func testItIsRecordingChanges() {

        // GIVEN
        let commandManager = CommandManager(publisher: $observedValue
                                            , initialValue: observedValue
                                            , debounceFor: 0.0001)
        
        let expectation = self.expectation(description: "Value recorded")
        expectation.isInverted = true
        
        // WHEN
        
        self.provision(commandManager: commandManager
                       , with: [43]) { [weak self] value in
            
            self?.observedValue = value
        } whenDone: {
                
            // THEN
            
            XCTAssertEqual(commandManager.depth, 1)
            XCTAssertEqual(commandManager.position, 1)
        }
    }
    
    func testItIsRecordingChangesMultipleValues() {

        // GIVEN
        let commandManager = CommandManager(publisher: $observedValue
                                            , initialValue: observedValue
                                            , debounceFor: 0.0001)
        
        let expectation = self.expectation(description: "Value recorded")
        expectation.isInverted = true
        
        // WHEN
        
        self.provision(commandManager: commandManager
                       , with: [43, 44, 45, 46]) { [weak self] value in
            
            self?.observedValue = value
        } whenDone: {
                
            // THEN
            
            XCTAssertEqual(commandManager.depth, 4)
            XCTAssertEqual(commandManager.position, 4)
        }
    }
    
    func testItIsPropagatingUndoAction() {

        // GIVEN
        let commandManager = CommandManager(publisher: $observedValue
                                            , initialValue: observedValue
                                            , debounceFor: 0.0001)
        var receivedValues: [Int] = []
        
        // WHEN
        
        self.provision(commandManager: commandManager
                       , with: [43]) { [weak self] value in
            
            self?.observedValue = value
        } whenDone: {
            
            
            let cancellable = commandManager.sink { value in
                
                receivedValues.append(value)
            }
            
            // THEN
            XCTAssertEqual(commandManager.canUndo, true)
            
            // AND WHEN
            commandManager.undo()
            
            // THEN
            XCTAssertEqual(receivedValues, [42])
            
            cancellable.cancel()
        }
    }
    
    
    func testItIsPropagatingRedoAction() {

        // GIVEN
        let commandManager = CommandManager(publisher: $observedValue
                                            , initialValue: observedValue
                                            , debounceFor: 0.0001)
        var receivedValues: [Int] = []
        
        // WHEN
        
        self.provision(commandManager: commandManager
                       , with: [43]) { [weak self] value in
            
            self?.observedValue = value
        } whenDone: {
            
            let cancellable = commandManager.sink { value in
                
                receivedValues.append(value)
            }
            
            // THEN
            XCTAssertEqual(commandManager.canUndo, true)
            
            // AND WHEN
            commandManager.undo()
            
            XCTAssertEqual(commandManager.canRedo, true)
            
            commandManager.redo()
            
            // THEN
            
            XCTAssertEqual(receivedValues, [42, 43])
            
            cancellable.cancel()
        }
    }
}


/// Memory management
extension CommandManagerTests {
    
    func testCommandManagerIsDeallocated() throws {
        
        self.verifyDeallocation {
            
            return CommandManager(publisher: $observedValue, initialValue: observedValue)
        }
    }

    func testCommandManagerIsDeallocatedAfterConentChange() throws {
        
        self.verifyDeallocation { [weak self] () -> CommandManager<Int> in
            
            let commandManager = CommandManager(publisher: $observedValue, initialValue: observedValue)
            
            self?.observedValue = 43
            self?.observedValue = 44
            
            return commandManager
        }
    }
    
}
