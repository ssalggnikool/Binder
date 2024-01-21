//
//  ContentView.swift
//  Binder
//
//  Created by samara on 1/19/24.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @State private var selectedImageIndex: Int?
    @State private var refreshCollectionView = false // Add this state variable
    let path = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    var imageFiles: [URL] {
        return path?.getAllImageFiles() ?? []
    }

    var body: some View {
        NavigationView {
            FileTree(url: path)
            CollectionView(images: imageFiles, selectedImageIndex: $selectedImageIndex, refresh: $refreshCollectionView)
                .frame(minWidth: Preferences.thumbnailSize!)
                .navigationTitle(imageFiles.first?.deletingLastPathComponent().lastPathComponent ?? "Binder")
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar, label: {
                    Image(systemName: "sidebar.leading")
                })
            }
            ToolbarItem(placement: .automatic) {
                Slider(value: .init(get: {
                    Preferences.thumbnailSize!
                }, set: { newValue in
                    Preferences.thumbnailSize = newValue
                    updateThumbnailSize()
                }), in: 50...500, step: 50)
                .frame(width: 150)
            }
        }
        .navigationViewStyle(.columns)
        .background(VisualEffectView().ignoresSafeArea())
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }

    private func updateThumbnailSize() {
        refreshCollectionView.toggle()
    }
}

struct CollectionView: View {
    var images: [URL]
    @Binding var selectedImageIndex: Int?
    @State private var thumbnails: [Int: Image] = [:]
    @Binding var refresh: Bool // Add this binding

    var body: some View {
        if images.isEmpty {
            Text("No Images")
                .foregroundColor(.secondary)
                .font(.title)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: Preferences.thumbnailSize!))], spacing: 20) {
                    ForEach(0..<images.count, id: \.self) { index in
                        VStack {
                            if let thumbnail = thumbnails[index] {
                                thumbnail
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: Preferences.thumbnailSize!, height: Preferences.thumbnailSize ?? 150)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.accentColor, lineWidth: selectedImageIndex == index ? 2 : 0)
                                            .opacity(selectedImageIndex == index ? 1 : 0)
                                    )
                            } else {
                                ProgressView()
                                    .frame(width: Preferences.thumbnailSize!, height: Preferences.thumbnailSize!)
                                    .cornerRadius(10)
                                    .onAppear {
                                        loadThumbnail(for: index)
                                    }
                            }

                            Text(images[index].lastPathComponent)
                                .lineLimit(1)
                                .background(selectedImageIndex == index ? Color.accentColor : Color.clear)
                                .padding(.top, 4)
                        }
                        .shadow(radius: 15)
                        .onTapGesture(count: 2, perform: { openDefaultApp(index: index) })
                        .onHover {_ in
                            selectImage(index: index)
                        }
                        .contextMenu {
                            Section {
                                Button("Open") {
                                    openDefaultApp(index: index)
                                }
                                Button("Open with Preview") {
                                    openWithPreview(index: index)
                                }
                            }
                            
                            Section {
                                Button("Reveal in Finder") {
                                    openInFinder(index: index)
                                }
                            }
                            
                            Section {
                                Button("Copy Image") {
                                    copyImage(index: index)
                                }
                            }
                            
                        }

                    }
                }
                .id(refresh)
                .padding()
            }
        }
    }

    private func loadThumbnail(for index: Int) {
        guard images.indices.contains(index) else {
            return
        }

        DispatchQueue.global(qos: .background).async {
            if let nsImage = NSImage(contentsOf: images[index]),
               let thumbnailImage = nsImage.thumbnailImage() {
                let thumbnail = Image(nsImage: thumbnailImage)
                DispatchQueue.main.async {
                    thumbnails[index] = thumbnail
                }
            }
        }
    }

    private func selectImage(index: Int) {
        selectedImageIndex = index
    }
}

// MARK: - Context Menu actions

extension CollectionView {
    
    private func openInFinder(index: Int) {
        let url = images[index]
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func copyImage(index: Int) {

        if let nsImage = NSImage(contentsOf: images[index]),
           let imageData = nsImage.tiffRepresentation {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setData(imageData, forType: .tiff)
        }
    }

    private func openWithPreview(index: Int) {
        let url = images[index]
        NSWorkspace.shared.open([url], withAppBundleIdentifier: "com.apple.Preview", options: [], additionalEventParamDescriptor: nil, launchIdentifiers: nil)
    }
    
    private func openDefaultApp(index: Int) {
        let url = images[index]
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Blur in background

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        effectView.material = .hudWindow
        return effectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}