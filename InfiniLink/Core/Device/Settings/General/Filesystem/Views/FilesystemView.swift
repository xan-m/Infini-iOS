//
//  FilesystemView.swift
//  InfiniLink
//
//  Created by Liam Willey on 10/7/24.
//

import SwiftUI

struct FileSystemToolbar: ViewModifier {
    @ObservedObject var fileSystemViewModel = FileSystemViewModel.shared
    @ObservedObject var bleFSHandler = BLEFSHandler.shared
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            fileSystemViewModel.showNewFolderView = true
                        } label: {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }
                        Button {
                            fileSystemViewModel.showUploadSheet = true
                        } label: {
                            Label("Upload Files", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!BLEManager.shared.hasLoadedCharacteristics || fileSystemViewModel.loadingFs || fileSystemViewModel.fileUploading)
                    .fileImporter(isPresented: $fileSystemViewModel.showUploadSheet, allowedContentTypes: [.data], allowsMultipleSelection: true) { result in
                        do {
                            let fileURLs = try result.get()
                            
                            self.fileSystemViewModel.files.removeAll()
                            for fileURL in fileURLs {
                                guard fileURL.startAccessingSecurityScopedResource() else { continue }
                                
                                self.fileSystemViewModel.fileSelected = true
                                self.fileSystemViewModel.files.append(FSFile(url: fileURL, filename: fileURL.lastPathComponent))
                                
                                // Don't stop accessing the security-scoped resource because then the upload button won't work due to lack of necessary permissions
                                // fileURL.stopAccessingSecurityScopedResource()
                            }
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    if fileSystemViewModel.fileSelected {
                        if fileSystemViewModel.fileUploading {
                            ProgressView({
                                if fileSystemViewModel.fileConverting {
                                    return NSLocalizedString("Converting...", comment: "")
                                } else {
                                    if fileSystemViewModel.fileSize != 0 {
                                        let progressPercentage = Int(Double(BLEFSHandler.shared.progress) / Double(fileSystemViewModel.fileSize) * 100)
                                        
                                        return NSLocalizedString("Uploading...\(progressPercentage)%", comment: "")
                                    } else {
                                        return NSLocalizedString("Uploading...", comment: "")
                                    }
                                }
                            }())
                        } else {
                            Button {
                                DispatchQueue.global(qos: .default).async {
                                    for file in fileSystemViewModel.files {
                                        let lowercaseFilename = file.filename.lowercased()
                                        
                                        guard let fileDataPath = file.url else {
                                            continue
                                        }
                                        
                                        do {
                                            if lowercaseFilename.hasSuffix(".png") ||
                                                lowercaseFilename.hasSuffix(".jpg") ||
                                                lowercaseFilename.hasSuffix(".jpeg") ||
                                                lowercaseFilename.hasSuffix(".gif") || lowercaseFilename.hasSuffix(".bmp") ||
                                                lowercaseFilename.hasSuffix(".tiff") ||
                                                lowercaseFilename.hasSuffix(".webp") ||
                                                lowercaseFilename.hasSuffix(".heif") ||
                                                lowercaseFilename.hasSuffix(".heic") {
                                                
                                                guard let img = UIImage(contentsOfFile: fileDataPath.path),
                                                      let cgImage = img.cgImage else {
                                                    continue
                                                }
                                                
                                                self.fileSystemViewModel.fileSize = 0
                                                
                                                let convertedImage = lvImageConvert(img: cgImage)
                                                
                                                let fileNameWithoutExtension = (file.filename as NSString).deletingPathExtension
                                                if let convertedImage = convertedImage {
                                                    self.fileSystemViewModel.fileSize = convertedImage.count
                                                    self.fileSystemViewModel.fileUploading = true
                                                    var _ = bleFSHandler.writeFile(data: convertedImage, path: fileSystemViewModel.directory + "/" + String(fileNameWithoutExtension.prefix(30).trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)) + ".bin", offset: 0)
                                                }
                                            } else {
                                                self.fileSystemViewModel.fileSize = 0
                                                let fileData = try Data(contentsOf: fileDataPath)
                                                self.fileSystemViewModel.fileSize = fileData.count
                                                
                                                self.fileSystemViewModel.fileUploading = true
                                                var _ = bleFSHandler.writeFile(data: fileData, path: fileSystemViewModel.directory + "/" + file.filename, offset: 0)
                                            }
                                        } catch {
                                            print("Error: \(error.localizedDescription)")
                                        }
                                    }
                                    
                                    self.fileSystemViewModel.fileUploading = false
                                    
                                    self.fileSystemViewModel.fileSelected = false
                                    self.fileSystemViewModel.files = []
                                    
                                    fileSystemViewModel.lsDir(dir: fileSystemViewModel.directory)
                                }
                            } label: {
                                let count = fileSystemViewModel.files.count
                                
                                Text("Upload \(count) File\(count == 1 ? "" : "s")")
                                    .padding(12)
                                    .padding(.horizontal, 4)
                                    .foregroundStyle(.white)
                                    .background(Color.accentColor)
                                    .clipShape(Capsule())
                            }
                            .padding(.top)
                        }
                    }
                }
            }
    }
}

struct FileSystemView: View {
    @Environment(\.presentationMode) var presMode
    @Environment(\.colorScheme) var colorScheme
    
    @ObservedObject var bleFSHandler = BLEFSHandler.shared
    @ObservedObject var fileSystemViewModel = FileSystemViewModel.shared
    
    @State var showUploadSheet = false
    @State var showFileDetailView = false
    @State var fileSelected = false
    @State var showNewFolderView = false
    
    @State var fileSize = 0
    
    @State var newFolderName = ""
    
    @FocusState var isNewFolderFocused: Bool
    
    var body: some View {
        List {
            if fileSystemViewModel.loadingFs {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                if fileSystemViewModel.directory != "/" {
                    Section {
                        Button {
                            let currentDir = fileSystemViewModel.directory
                            
                            fileSystemViewModel.directory = fileSystemViewModel.removeLastPathComponent(currentDir)
                            fileSystemViewModel.lsDir(dir: fileSystemViewModel.directory)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.body.weight(.medium))
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                        }
                        .disabled(fileSystemViewModel.loadingFs || fileSystemViewModel.fileUploading)
                    }
                }
                Section {
                    ForEach(fileSystemViewModel.commandHistory.filter({ $0 != "" }), id: \.self) { listItem in
                        let isFile = listItem.contains(".")
                        
                        Group {
                            if listItem != "." && listItem != ".." {
                                Button {
                                    if isFile {
                                        showFileDetailView = true
                                    } else {
                                        fileSystemViewModel.loadingFs = true
                                        fileSystemViewModel.cdAndLs(dir: listItem)
                                    }
                                } label: {
                                    Text(listItem)
                                }
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                fileSystemViewModel.deleteFile(fileName: listItem)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $fileSystemViewModel.showNewFolderView) {
            newFolder
        }
        .sheet(isPresented: $showFileDetailView) {
            FileSystemDetailView()
        }
        .onAppear {
            fileSystemViewModel.loadingFs = true
            fileSystemViewModel.lsDir(dir: "/")
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("File System")
    }
    
    var newFolder: some View {
        NavigationView {
            Form {
                TextField("Title", text: $newFolderName)
                    .focused($isNewFolderFocused)
            }
            .navigationTitle("New Folder")
            .onAppear {
                isNewFolderFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showNewFolderView = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        fileSystemViewModel.createDir(name: newFolderName)
                        fileSystemViewModel.showNewFolderView = false
                    }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

#Preview {
    NavigationView {
        FileSystemView()
    }
}