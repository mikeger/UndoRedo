//
//  Command.swift
//  UndoRedoApp
//
//  Created by Mike on 31.08.21.
//

import Foundation

public protocol CommandType {

    associatedtype Content
    
    func `do`(on toModify: Content) -> Content?
    func undo(on toModify: Content) -> Content?
}

public struct Command<Content>: CommandType {
    
    typealias Action = (Content) -> Content?
    
    var doAction: Action
    var undoAction: Action
    
    public func `do`(on toModify: Content) -> Content? {
        
        return self.doAction(toModify)
    }
    
    public func undo(on toModify: Content) -> Content? {
        
        return self.undoAction(toModify)
    }
    
    init(doAction: @escaping Action, undoAction: @escaping Action) {
        
        self.doAction = doAction
        self.undoAction = undoAction
    }
}
