//
//  DownloadView.swift
//  mMusic
//
//  Created by Vanya on 22.06.2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct DownloadView: View {
    @State private var isImporting = false
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            HStack(spacing: 16) {
                Button {
                    isImporting = true
                } label: {
                    VStack {
                        Text("Upload music")
                        Image(systemName: "square.and.arrow.down")
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.roundedRectangle(radius: 15))
                .tint(.orange)

                Button {

                } label: {
                    VStack {
                        Text("From YouTube")
                        Image(systemName: "video")
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.roundedRectangle(radius: 15))
                .tint(.red)
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.audio], onCompletion: handleFileLoading)
            .padding()

            Spacer()
            
            if isLoading {
                Text("File is loading...")
            }
        }
        .navigationTitle("Download")
    }
}

private func handleFileLoading(_ result: Result<URL, Error>) {
    print(result)
}
