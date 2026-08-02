//
//  Music_CardsApp.swift
//  Music Cards
//
//  Created by Elliot Williams on 2025-08-06.
//

import SwiftUI
import MediaPlayer
import UIKit

// Improved dominant color extraction
extension UIImage {
    func dominantColor() -> UIColor? {
        guard let cgImage = self.cgImage else { return nil }
        let width = 1
        let height = 1
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixel = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        return UIColor(
            red: CGFloat(pixel[0]) / 255.0,
            green: CGFloat(pixel[1]) / 255.0,
            blue: CGFloat(pixel[2]) / 255.0,
            alpha: 1.0
        )
    }
}

// Helper to calculate text color based on background brightness
func textColorForBackground(_ color: UIColor) -> Color {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
    guard color.getRed(&r, green: &g, blue: &b, alpha: nil) else {
        return .primary
    }
    let brightness = (r * 299 + g * 587 + b * 114) / 1000
    return brightness > 0.6 ? .black : .white
}

struct MusicCardView: View {
    let album: MPMediaItemCollection
    @Binding var currentBackgroundColor: Color
    let isCurrentCard: Bool
    @State private var flipped = false
    @State private var backgroundColor = Color.gray.opacity(0.3)
    @State private var textColor = Color.primary
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Front of card
                AlbumFrontView(album: album,
                               backgroundColor: $backgroundColor,
                               textColor: $textColor)
                    .opacity(flipped ? 0 : 1)
                
                // Back of card
                AlbumBackView(album: album,
                              backgroundColor: $backgroundColor,
                              textColor: $textColor)
                    .opacity(flipped ? 1 : 0)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(backgroundColor)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
            .rotation3DEffect(
                .degrees(flipped ? 180 : 0),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .onTapGesture(count: 1) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    flipped.toggle()
                }
            }
            .onAppear {
                updateColors()
            }
            .onChange(of: backgroundColor) { newColor in
                // Update the global background color
                if isCurrentCard {
                    currentBackgroundColor = newColor
                }
            }
        }
    }
    
    private func updateColors() {
        guard let item = album.representativeItem,
              let artwork = item.artwork,
              let image = artwork.image(at: CGSize(width: 300, height: 300)) else {
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Create a thumbnail version for faster processing
            let thumbnailSize = CGSize(width: 100, height: 100)
            UIGraphicsBeginImageContextWithOptions(thumbnailSize, false, 0.0)
            image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
            let thumbnailImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            guard let thumb = thumbnailImage,
                  let dominantColor = thumb.dominantColor() else { return }
            
            let newTextColor = textColorForBackground(dominantColor)
            
            DispatchQueue.main.async {
                backgroundColor = Color(dominantColor)
                textColor = newTextColor
            }
        }
    }
}

struct AlbumFrontView: View {
    let album: MPMediaItemCollection
    @Binding var backgroundColor: Color
    @Binding var textColor: Color
    var representativeItem: MPMediaItem? { album.representativeItem }
    
    var body: some View {
        VStack {
            if let artwork = representativeItem?.artwork?.image(at: CGSize(width: 300, height: 300)) {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 280)
                    .cornerRadius(12)
                    .padding()
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            } else {
                ZStack {
                    Color.gray.opacity(0.3)
                    Image(systemName: "music.note")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100)
                        .foregroundColor(.secondary)
                }
                .frame(height: 280)
                .cornerRadius(12)
                .padding()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(representativeItem?.albumTitle ?? "Unknown Album")
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .foregroundColor(textColor)
                
                Text(representativeItem?.albumArtist ?? "Unknown Artist")
                    .font(.headline)
                    .foregroundColor(textColor.opacity(0.8))
                
                Text("\(album.count) song\(album.count > 1 ? "s" : "")")
                    .font(.subheadline)
                    .foregroundColor(textColor.opacity(0.7))
            }
            .padding(.horizontal)
            
            Spacer()
            
            Text("Tap to see tracks")
                .font(.caption)
                .foregroundColor(textColor.opacity(0.7))
                .padding(.bottom, 20)
        }
        .padding(.top, 20)
    }
}

// Track row view to simplify complex expression
struct TrackRow: View {
    let track: MPMediaItem
    let textColor: Color
    
    var body: some View {
        HStack {
            Text("\(track.albumTrackNumber)")
                .font(.system(size: 14, design: .monospaced))
                .frame(width: 30, alignment: .trailing)
                .foregroundColor(textColor.opacity(0.8))
            
            Text(track.title ?? "Unknown Track")
                .font(.body)
                .lineLimit(1)
                .foregroundColor(textColor)
            
            Spacer()
            
            Text(formattedDuration(duration: track.playbackDuration))
                .font(.caption)
                .foregroundColor(textColor.opacity(0.7))
        }
        .padding(.vertical, 4)
    }
    
    private func formattedDuration(duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct AlbumBackView: View {
    let album: MPMediaItemCollection
    @Binding var backgroundColor: Color
    @Binding var textColor: Color
    
    var tracks: [MPMediaItem] {
        album.items.sorted { ($0.albumTrackNumber, $0.discNumber) < ($1.albumTrackNumber, $1.discNumber) }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Track List")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 5)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Divider()
                .background(textColor.opacity(0.3))
                .padding(.vertical, 5)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(tracks, id: \.persistentID) { track in
                        Button(action: {
                            playTrack(track)
                        }) {
                            TrackRow(track: track, textColor: textColor)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            Text("Tap to flip back")
                .font(.caption)
                .foregroundColor(textColor.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 10)
        }
        .padding(.top, 20)
        .padding(.horizontal)
    }
    
    private func playTrack(_ track: MPMediaItem) {
        let player = MPMusicPlayerController.systemMusicPlayer
        player.stop()
        player.setQueue(with: album)
        player.nowPlayingItem = track
        player.play()
    }
}

// Search Panel View
struct SearchPanelView: View {
    @Binding var searchText: String
    @Binding var showSearch: Bool
    var albums: [MPMediaItemCollection]
    var onSelectAlbum: (MPMediaItemCollection) -> Void
    
    var filteredAlbums: [MPMediaItemCollection] {
        guard !searchText.isEmpty else { return albums }
        return albums.filter { album in
            let repItem = album.representativeItem
            let albumTitle = repItem?.albumTitle ?? ""
            let artist = repItem?.albumArtist ?? ""
            return albumTitle.localizedCaseInsensitiveContains(searchText) ||
                   artist.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                TextField("Search albums...", text: $searchText)
                    .padding(10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .padding(.leading)
                    .padding(.vertical, 8)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button(action: {
                    withAnimation {
                        showSearch = false
                    }
                }) {
                    Text("Cancel")
                        .padding(.trailing)
                }
            }
            .background(Color.black.opacity(0.5))
            
            List(filteredAlbums, id: \.persistentID) { album in
                Button(action: {
                    onSelectAlbum(album)
                    withAnimation {
                        showSearch = false
                    }
                }) {
                    HStack {
                        if let artwork = album.representativeItem?.artwork?.image(at: CGSize(width: 50, height: 50)) {
                            Image(uiImage: artwork)
                                .resizable()
                                .frame(width: 50, height: 50)
                                .cornerRadius(4)
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .foregroundColor(.secondary)
                                )
                        }
                        
                        VStack(alignment: .leading) {
                            Text(album.representativeItem?.albumTitle ?? "Unknown Album")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(album.representativeItem?.albumArtist ?? "Unknown Artist")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 8)
                        
                        Spacer()
                    }
                }
                .listRowBackground(Color.black.opacity(0.5))
            }
            .listStyle(PlainListStyle())
            .background(Color.black.opacity(0.5))
        }
        .background(Color.black.opacity(0.5))
        .transition(.move(edge: .top))
    }
}

struct MusicLibraryView: View {
    @StateObject private var musicLibrary = MusicLibrary()
    @State private var currentIndex = 0
    @State private var rotations: [Double] = []
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var currentBackgroundColor = Color(red: 0.1, green: 0.1, blue: 0.2)
    @State private var isPlaying = false
    @State private var currentAlbumID: MPMediaEntityPersistentID?
    
    var body: some View {
        ZStack {
            // Background with current album color
            LinearGradient(
                gradient: Gradient(colors: [currentBackgroundColor, .black]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            mainContent
        }
        .onAppear(perform: {
            musicLibrary.requestAuthorization()
            // Initialize with current album ID
            if let firstAlbum = musicLibrary.albums.first {
                currentAlbumID = firstAlbum.persistentID
                updateBackgroundColor(for: firstAlbum)
            }
        })
        .onChange(of: musicLibrary.albums) { albums in
            rotations = albums.map { _ in Double.random(in: -2...2) }
            // Update current album ID when albums load
            if let firstAlbum = albums.first, currentAlbumID == nil {
                currentAlbumID = firstAlbum.persistentID
                updateBackgroundColor(for: firstAlbum)
            }
        }
        .onChange(of: currentIndex) { newIndex in
            // Update background color immediately when index changes
            if let album = musicLibrary.albums[safe: newIndex] {
                updateBackgroundColor(for: album)
                currentAlbumID = album.persistentID
            }
        }
        .overlay(searchOverlay)
    }
    
    private var mainContent: some View {
        VStack {
            if musicLibrary.isLoading {
                loadingView
            } else if musicLibrary.albums.isEmpty {
                emptyLibraryView
            } else {
                cardStack
                bottomBar
            }
        }
    }
    
    private var loadingView: some View {
        ProgressView("Loading Music Library...")
            .padding()
    }
    
    private var emptyLibraryView: some View {
        VStack {
            Image(systemName: "music.note.list")
                .font(.system(size: 50))
                .foregroundColor(.white)
                .padding()
            
            Text("No albums found")
                .font(.title)
                .foregroundColor(.secondary)
                .padding()
            
            Text("Please add music to your Library")
                .font(.title2)
                .foregroundColor(.white)
                .padding()
            
            Button("Open Music App") {
                if let url = URL(string: "music://") {
                    UIApplication.shared.open(url)
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
    
    private var cardStack: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(displayedAlbumIndices(), id: \.self) { index in
                    if let album = musicLibrary.albums[safe: index] {
                        cardView(for: album, index: index, geometry: geometry)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(
                DragGesture()
                    .onEnded { value in
                        handleSwipe(value.translation.width)
                    }
            )
            .padding()
        }
    }
    
    private func cardView(for album: MPMediaItemCollection, index: Int, geometry: GeometryProxy) -> some View {
        let cardIndex = index - currentIndex
        let rotation = fanRotation(for: cardIndex)
        let offset = fanOffset(for: cardIndex, in: geometry)
        let width = cardWidth(for: geometry, index: cardIndex)
        let height = cardHeight(for: geometry)
        let isCurrentCard = (cardIndex == 2)
        
        // Calculate zIndex based on cardIndex but ensure current card is always on top
        let zIndexValue = Double(cardIndex) + (isCurrentCard ? 10 : 0)
        
        return MusicCardView(album: album, currentBackgroundColor: $currentBackgroundColor, isCurrentCard: isCurrentCard)
            .frame(width: width, height: height)
            .offset(offset)
            .rotationEffect(.degrees(rotation))
            .zIndex(zIndexValue)
    }
    
    private var bottomBar: some View {
        HStack {
            Text("\(currentIndex + 1)/\(musicLibrary.albums.count)")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            playPauseButton
            
            searchButton
        }
        .padding(.horizontal, 40)
        .padding(.bottom)
    }
    
    private var playPauseButton: some View {
        Button(action: togglePlayPause) {
            Image(systemName: isPlaying ? "pause.circle" : "play.circle")
                .font(.title)
                .foregroundColor(.white)
                .padding(8)
                .background(Circle().fill(Color.white.opacity(0.2)))
        }
    }
    
    private var searchButton: some View {
        Button(action: showSearchPanel) {
            Image(systemName: "magnifyingglass")
                .font(.title)
                .foregroundColor(.white)
                .padding(8)
                .background(Circle().fill(Color.white.opacity(0.2)))
        }
    }
    
    private var searchOverlay: some View {
        Group {
            if showSearch {
                SearchPanelView(
                    searchText: $searchText,
                    showSearch: $showSearch,
                    albums: musicLibrary.albums
                ) { album in
                    if let index = musicLibrary.albums.firstIndex(where: { $0.persistentID == album.persistentID }) {
                        currentIndex = index
                        // Force background color update
                        updateBackgroundColor(for: album)
                        // Update current album ID
                        currentAlbumID = album.persistentID
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func displayedAlbumIndices() -> [Int] {
        let maxIndex = min(currentIndex + 3, musicLibrary.albums.count)
        return Array(currentIndex..<maxIndex)
    }
    
    private func handleSwipe(_ translation: CGFloat) {
        if translation < -100 {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                let newIndex = min(currentIndex + 1, musicLibrary.albums.count - 1)
                if newIndex != currentIndex {
                    currentIndex = newIndex
                    // Force background color update for the new current card
                    if let album = musicLibrary.albums[safe: currentIndex] {
                        updateBackgroundColor(for: album)
                    }
                }
            }
        } else if translation > 100 {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                let newIndex = max(currentIndex - 1, 0)
                if newIndex != currentIndex {
                    currentIndex = newIndex
                    // Force background color update for the new current card
                    if let album = musicLibrary.albums[safe: currentIndex] {
                        updateBackgroundColor(for: album)
                    }
                }
            }
        }
    }
    
    private func fanRotation(for cardIndex: Int) -> Double {
        switch cardIndex {
        case 0: return -20.0
        case 1: return -10.0
        case 2: return rotations.indices.contains(currentIndex) ? rotations[currentIndex] : 0
        default: return 0
        }
    }
    
    private func fanOffset(for cardIndex: Int, in geometry: GeometryProxy) -> CGSize {
        let cardSpacing: CGFloat = 20
        let maxXOffset = geometry.size.width * 0.25  // Limit offset to 25% of screen width
        
        switch cardIndex {
        case 0:  // Leftmost card
            return CGSize(width: -min(cardSpacing * 4, maxXOffset),
                         height: -cardSpacing * 2)
        case 1:  // Middle card
            return CGSize(width: -min(cardSpacing * 2, maxXOffset * 0.5),
                         height: -cardSpacing)
        case 2:  // Current card
            return .zero
        default:
            return .zero
        }
    }
    
    private func cardWidth(for geometry: GeometryProxy, index: Int) -> CGFloat {
        let baseWidth = geometry.size.width - 40
        let scale = cardScale(for: index)
        return baseWidth * scale
    }
    
    private func cardHeight(for geometry: GeometryProxy) -> CGFloat {
        geometry.size.height - 100
    }
    
    private func cardScale(for index: Int) -> CGFloat {
        switch index {
        case 0: return 1.0
        case 1: return 0.92
        case 2: return 0.84
        default: return 0.7
        }
    }
    
    private func showSearchPanel() {
        withAnimation {
            showSearch = true
        }
    }
    
    private func togglePlayPause() {
        let player = MPMusicPlayerController.systemMusicPlayer
        
        if isPlaying {
            player.pause()
        } else if let album = musicLibrary.albums[safe: currentIndex] {
            player.stop()
            player.setQueue(with: album)
            player.play()
        }
        
        isPlaying.toggle()
    }
    
    private func updateBackgroundColor(for album: MPMediaItemCollection) {
        guard let item = album.representativeItem,
              let artwork = item.artwork,
              let image = artwork.image(at: CGSize(width: 300, height: 300)) else {
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let thumbnailSize = CGSize(width: 100, height: 100)
            UIGraphicsBeginImageContextWithOptions(thumbnailSize, false, 0.0)
            image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
            let thumbnailImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            guard let thumb = thumbnailImage,
                  let dominantColor = thumb.dominantColor() else { return }
            
            DispatchQueue.main.async {
                currentBackgroundColor = Color(dominantColor)
            }
        }
    }
}

// Safe array access extension
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

class MusicLibrary: ObservableObject {
    @Published var albums: [MPMediaItemCollection] = []
    @Published var isLoading = true
    
    func requestAuthorization() {
        MPMediaLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    self.fetchAlbums()
                } else {
                    print("Media library access denied")
                    self.isLoading = false
                }
            }
        }
    }
    
    private func fetchAlbums() {
        let query = MPMediaQuery.albums()
        query.groupingType = .album
        
        if let collections = query.collections {
            // Filter out albums without tracks
            self.albums = collections.filter { $0.count > 0 }
            print("Loaded \(self.albums.count) albums")
        }
        
        self.isLoading = false
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            MusicLibraryView()
                .navigationTitle("Music Albums")
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.2), .black]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .edgesIgnoringSafeArea(.all)
                )
        }
    }
}

@main
struct Music_CardsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    ContentView()
}
