//
//  HomeTab.swift
//  mMusic
//
//  Created by Vanya on 22.06.2026.
//

import SwiftUI

struct HomeTab: View {
    @Binding var path: NavigationPath
    
    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
        }
    }
}
