//
//  ContentView.swift
//  Shared
//
//  Created by Mike on 31.08.21.
//

import SwiftUI
import CommandManager

class ContentViewModel: ObservableObject {
    @Published var text: String = ""
    
    @Published var commandManager: CommandManager<String>!
    
    init() {
        commandManager = CommandManager(publisher: $text, initialValue: text)
    }
}

struct ContentView: View {
    
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        VStack {
            TextField("Some text for testing the undo-redo", text: $viewModel.text).padding([.leading, .trailing], 20).onReceive(viewModel.commandManager, perform: { value in
                viewModel.text = value
            })
            
            HStack {
                Button("Undo") {
                    viewModel.commandManager.undo()
                }.padding(10).disabled(!viewModel.commandManager.canUndo)
                
                Button("Redo") {
                    viewModel.commandManager.redo()
                }.padding(10).disabled(!viewModel.commandManager.canRedo)
            }
            
            HStack {
                Text("Undo stack size:")
                Text("\(viewModel.commandManager.depth)").bold()
                Text("Position:")
                Text("\(viewModel.commandManager.position)").bold()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {

    static var previews: some View {

        return ContentView(viewModel: ContentViewModel())
    }
}
