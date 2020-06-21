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
        
        var pixels = [Pixel]()
        for x in 0..<width {
            for y in 0..<height {
                // Construct pixel
                let pixelIndex = ((width * y) + x) * 4
                let pixel = Pixel(r: Double(imageData[pixelIndex]) / 255.0, g: Double(imageData[pixelIndex + 1]) / 255.0, b: Double(imageData[pixelIndex + 2]) / 255.0, a: Double(imageData[pixelIndex + 3]) / 255.0)
                pixels.append(pixel)
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

fileprivate struct Pixel {
    var r: Double
    var g: Double
    var b: Double
    var a: Double
    var count = 0

    init(r: Double, g: Double, b: Double, a: Double) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
    
    func distanceTo(_ other: Pixel) -> Double {
        // Simple distance formula
        let rDistance = pow(r - other.r, 2)
        let gDistance = pow(g - other.g, 2)
        let bDistance = pow(b - other.b, 2)
        let aDistance = pow(a - other.a, 2)
        
        return sqrt(rDistance + gDistance + bDistance + aDistance)
    }
    
    mutating func append(_ pixel: Pixel) {
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
}

fileprivate extension UIColor {
    convenience init?(pixel: Pixel) {
        guard !pixel.r.isNaN else {
            return nil
        }
        
        self.init(red: CGFloat(pixel.r), green: CGFloat(pixel.g), blue: CGFloat(pixel.b), alpha: CGFloat(pixel.a))
    }
}

fileprivate class KMeans {
    let clusterNumber: Int
    let tolerance: Double
    let dataPoints: [Pixel]
    
    init(clusterNumber: Int, tolerance: Double, dataPoints: [Pixel]) {
        self.clusterNumber = clusterNumber
        self.tolerance = tolerance
        self.dataPoints = dataPoints
    }
    
    private func getRandomSamples(_ samples: [Pixel], k: Int) -> [Pixel] {
        var result = [Pixel]()
        
        // Fill array with a random entry in samples
        for _ in 0..<k {
            let random = Int.random(in: 0..<samples.count)
            result.append(samples[random])
        }

        return result
    }
    
    private func indexOfNearestCentroid(_ pixel: Pixel, centroids: [Pixel]) -> Int {
        var smallestDistance = Double.greatestFiniteMagnitude
        var index = 0

        for (i, centroid) in centroids.enumerated() {
            let distance = pixel.distanceTo(centroid)
            if distance >= smallestDistance {
                // Not the smallest
                continue
            }
            
            smallestDistance = distance
            index = i
        }

        return index
    }
    
    func kMeans(partitions: Int, tolerance: Double, entries: [Pixel]) -> [Pixel] {
        // The main engine behind the scenes
        var centroids = getRandomSamples(entries, k: partitions)
        
        var centerMoveDist = 0.0
        repeat {
            // Create new centers every loop
            var centerCandidates = [Pixel](repeating: Pixel(r: 0, g: 0, b: 0, a: 0), count: partitions)
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
        return pixels.sorted {
            $0.count > $1.count
        }
    }
}
