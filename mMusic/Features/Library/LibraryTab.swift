//
//  LibraryTab.swift
//  mMusic
//
//  Created by Vanya on 22.06.2026.
//

import SwiftUI

struct LibraryTab: View {
    @Binding var path: NavigationPath
    
    var body: some View {
        NavigationStack(path: $path) {
            LibraryView()
        }
    }
}
