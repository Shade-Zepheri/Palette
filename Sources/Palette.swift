//
//  Palette.swift
//
//  Created by Alfonso Gonzalez on 4/9/20.
//  Copyright (c) 2020 Alfonso Gonzalez

#if os(macOS)
    import AppKit
    public typealias UIImage = NSImage
    public typealias UIColor = NSColor
#else
    import UIKit
#endif

// MARK: Public API

public struct UIImageColorPalette: CustomStringConvertible {
    let primary: UIColor
    let secondary: UIColor?
    let tertiary: UIColor?
    
    public init(primary: UIColor, secondary: UIColor?, tertiary: UIColor?) {
        self.primary = primary
        self.secondary = secondary
        self.tertiary = tertiary
    }
    
    public var description: String {
        var description = "Primary: \(primary)"
        
        if let secondary = secondary {
            description += ", Secondary: \(secondary)"
        }
        
        if let tertiary = tertiary {
            description += ", Tertiary: \(tertiary)"
        }
        
        return description
    }
}

public enum UIImageResizeQuality: CGFloat {
    case low = 0.3
    case medium = 0.5
    case high = 0.8
    case standard = 1.0
}

extension UIImage {
    #if os(macOS)
        private func resizeImage(desiredSize: CGSize) -> UIImage? {
            if desiredSize == size {
                return self
            }
            
            let frame = CGRect(origin: .zero, size: desiredSize)
            guard let representation = bestRepresentation(for: frame, context: nil, hints: nil) else {
                return nil
            }
            
            let result = NSImage(size: desiredSize, flipped: false) { (_) -> Bool in
                return representation.draw(in: frame)
            }
            
            return result
        }
    #else
        private func resizeImage(desiredSize: CGSize) -> UIImage? {
            if desiredSize == size {
                return self
            }
            
            // Make sure scale remains the same
            let format = UIGraphicsImageRendererFormat()
            format.scale = scale

            // UIGraphicsImageRenderer makes life easy
            let renderer = UIGraphicsImageRenderer(size: desiredSize, format: format)
            return renderer.image { (context) in
                self.draw(in: CGRect(origin: .zero, size: desiredSize))
            }
        }
    #endif
    
    public func retrieveColorPalette(quality: UIImageResizeQuality = .standard, _ completion: @escaping (UIImageColorPalette?) -> Void) {
        // Run in background
        DispatchQueue.global(qos: .utility).async {
            let palette = self.retrieveColorPalette(quality: quality)
            
            // Back to main
            DispatchQueue.main.async {
                completion(palette)
            }
        }
    }
    
    public func retrieveColorPalette(quality: UIImageResizeQuality = .standard) -> UIImageColorPalette? {
        // Resize if needed
        var desiredSize = size
        if quality != .standard {
            // Determine new size
            desiredSize = CGSize(width: size.width * quality.rawValue, height: size.height * quality.rawValue)
        }
        
        guard let imageToProcess = resizeImage(desiredSize: desiredSize) else {
            return nil
        }
        
        // Get image data
        #if os(macOS)
            guard let cgImage = imageToProcess.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return nil
            }
        #else
            guard let cgImage = imageToProcess.cgImage else {
                return nil
            }
        #endif
        
        guard let imageData = CFDataGetBytePtr(cgImage.dataProvider!.data) else {
            fatalError("Could not retrieve image data")
        }
        
        // Create our array of pixels
        let width = cgImage.width
        let height = cgImage.height
        
        var pixels = [Double]()
        pixels.reserveCapacity(width * height)
        for x in 0..<width {
            for y in 0..<height {
                // Construct pixel
                let pixelIndex = ((width * y) + x) * 4
                let r = Double(imageData[pixelIndex]) * 1000000000
                let g = Double(imageData[pixelIndex + 1]) * 1000000
                let b = Double(imageData[pixelIndex + 2]) * 1000
                let a = Double(imageData[pixelIndex + 3])
                let doubleRepresentation = r + g + b + a
                pixels.append(doubleRepresentation)
            }
        }
        
        // Process by k-means clustering
        let analyzer = KMeans(clusterNumber: 3, tolerance: 0.01, dataPoints: pixels)
        let prominentPixels = analyzer.calculateProminentClusters()
        
        // Create palette object
        guard let primaryColor = UIColor(pixel: prominentPixels[0]) else {
            return nil
        }

        let secondaryColor = UIColor(pixel: prominentPixels[1])
        let tertiaryColor = UIColor(pixel: prominentPixels[2])
        return UIImageColorPalette(primary: primaryColor, secondary: secondaryColor, tertiary: tertiaryColor)
    }
}


// MARK: Private Helpers

fileprivate extension UIColor {
    convenience init?(pixel: Pixel) {
        guard !pixel.r.isNaN else {
            return nil
        }
        
        self.init(red: CGFloat(pixel.r / 255), green: CGFloat(pixel.g / 255), blue: CGFloat(pixel.b / 255), alpha: CGFloat(pixel.a / 255))
    }
}

// MARK: K-Means Clustering Helper

// Utilizing a double because normal structs take too long to allocate
fileprivate extension Double {
    // MARK: RGBA
    var r: Double {
        return floor(self / 1000000000)
    }
    
    var g: Double {
        return floor(fmod(self, 1000000000) / 1000000)
    }
    
    var b: Double {
        return floor(fmod(self, 1000000) / 1000)
    }
    
    var a: Double {
        return fmod(self, 1000)
    }
}

fileprivate struct Pixel: Comparable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double
    
    var count = 0

    init(double: Double) {
        self.r = double.r
        self.g = double.g
        self.b = double.b
        self.a = double.a
    }
    
    func distanceTo(_ other: Double) -> Double {
        // Simple distance formula
        let rDistance = pow(r - other.r, 2)
        let gDistance = pow(g - other.g, 2)
        let bDistance = pow(b - other.b, 2)
        let aDistance = pow(a - other.a, 2)
        
        return sqrt(rDistance + gDistance + bDistance + aDistance)
    }

    func distanceTo(_ other: Pixel) -> Double {
        // Simple distance formula
        let rDistance = pow(r - other.r, 2)
        let gDistance = pow(g - other.g, 2)
        let bDistance = pow(b - other.b, 2)
        let aDistance = pow(a - other.a, 2)
        
        return sqrt(rDistance + gDistance + bDistance + aDistance)
    }
    
    mutating func append(_ pixel: Double) {
        // Add data
        r += pixel.r
        g += pixel.g
        b += pixel.b
        a += pixel.a
    }
    
    mutating func averageOut(count: Int) {
        // Add to count and average
        self.count = count
        r /= Double(count)
        g /= Double(count)
        b /= Double(count)
        a /= Double(count)
    }
    
    // MARK: Comparable

    static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.count < rhs.count
    }
    
    static func <= (lhs: Self, rhs: Self) -> Bool {
        return lhs.count <= rhs.count
    }
    
    static func > (lhs: Self, rhs: Self) -> Bool {
        return lhs.count > rhs.count
    }
    
    static func >= (lhs: Self, rhs: Self) -> Bool {
        return lhs.count >= rhs.count
    }
    
    // MARK: Equatable
    
    static func == (lhs: Self, rhs: Self) -> Bool  {
        return lhs.count == rhs.count
    }
}

fileprivate class KMeans {
    let clusterNumber: Int
    let tolerance: Double
    let dataPoints: [Double]
    
    init(clusterNumber: Int, tolerance: Double, dataPoints: [Double]) {
        self.clusterNumber = clusterNumber
        self.tolerance = tolerance
        self.dataPoints = dataPoints
    }
    
    private func getRandomSamples(_ samples: [Double], k: Int) -> [Pixel] {
        var result = [Pixel]()
        
        // Fill array with a random entry in samples
        for i in 0..<k {
            let startIndex = (samples.count / 4) * i
            let endIndex = (samples.count / 4) * (i + 1)
            let random = Int.random(in: startIndex..<endIndex)
            
            // Create Pixel wrapper
            let pixel = Pixel(double: samples[random])
            result.append(pixel)
        }

        return result
    }
    
    private func indexOfNearestCentroid(_ pixel: Double, centroids: [Pixel]) -> Int {
        var smallestDistance = Double.greatestFiniteMagnitude
        var index = 0

        for (i, centroid) in centroids.enumerated() {
            let distance = centroid.distanceTo(pixel)
            if distance >= smallestDistance {
                // Not the smallest
                continue
            }
            
            smallestDistance = distance
            index = i
        }

        return index
    }
    
    func kMeans(partitions: Int, tolerance: Double, entries: [Double]) -> [Pixel] {
        // The main engine behind the scenes
        var centroids = getRandomSamples(entries, k: partitions)
        
        var centerMoveDist = 0.0
        repeat {
            // Create new centers every loop
            var centerCandidates = [Pixel](repeating: Pixel(double: 0), count: partitions)
            var totals = [Int](repeating: 0, count: partitions)
            
            // Calculate nearest points to centers
            for pixel in entries {
                // Update data points
                let index = indexOfNearestCentroid(pixel, centroids: centroids)
                centerCandidates[index].append(pixel)
                totals[index] += 1
            }
            
            // Average out data
            for i in 0..<partitions {
                centerCandidates[i].averageOut(count: totals[i])
            }
            
            // Calculate how much each centroid moved
            centerMoveDist = 0.0
            for i in 0..<partitions {
                centerMoveDist += centroids[i].distanceTo(centerCandidates[i])
            }
            
            // Set new centroids
            centroids = centerCandidates
        } while centerMoveDist > tolerance
        
        return centroids
    }
    
    func calculateProminentClusters() -> [Pixel] {
        // Get pixels
        let pixels = kMeans(partitions: clusterNumber, tolerance: tolerance, entries: dataPoints)
        
        // Sort by count
        return pixels.sorted(by: >)
    }
}
