//
//  CapacityApp.swift
//  Capacity
//
//  Created by George Babichev on 11/21/25.
//

import SwiftUI

@main
struct CapacityApp: App {
    @State private var showAbout = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(isPresented: $showAbout) {
                    AboutView()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button {
                    showAbout = true
                } label: {
                    Label("About Capacity", systemImage: "info.circle")
                }
            }
        }
    }
}
