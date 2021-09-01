//
//  UndoRedoApp.swift
//  Shared
//
//  Created by Mike on 31.08.21.
//

import SwiftUI

@main
struct UndoRedoApp: App {
    @State var viewModel = ContentViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
