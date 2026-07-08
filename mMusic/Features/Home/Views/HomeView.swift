//
//  HomeView.swift
//  mMusic
//
//  Created by Vanya on 22.06.2026.
//

import SwiftUI

struct HomeView: View {
    
    @State private var showSettings = false
    
    var body: some View {
        Text("Home")
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
    }
}
