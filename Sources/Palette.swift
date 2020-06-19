//
//  Palette.swift
//
//  Created by Alfonso Gonzalez on 4/9/20.
//  Copyright (c) 2020 Alfonso Gonzalez

import UIKit

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
            description.append(", Secondary: \(secondary)")
        }
        
        if let tertiary = tertiary {
            description.append(", Tertiary: \(tertiary)")
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
    private func resizeImage(desiredSize: CGSize) -> UIImage {
        // Make sure scale remains the same
        let format = UIGraphicsImageRendererFormat()
        format.scale = self.scale

        // UIGraphicsImageRenderer makes life easy
        let renderer = UIGraphicsImageRenderer(size: desiredSize, format: format)
        return renderer.image { (context) in
            self.draw(in: CGRect(origin: .zero, size: desiredSize))
        }
    }
    
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
        var imageToProcess = self
        if quality != .standard {
            let newSize = CGSize(width: self.size.width * quality.rawValue, height: self.size.height * quality.rawValue)
            imageToProcess = resizeImage(desiredSize: newSize)
        }
        
        // Get image data
        guard let cgImage = imageToProcess.cgImage else {
            return nil
        }
        
        guard let imageData = CFDataGetBytePtr(cgImage.dataProvider!.data) else {
            fatalError("Could not retrieve image data")
        }
        
        // Create our array of pixels
        let width = cgImage.width
        let height = cgImage.height
        
        var pixels:[Pixel] = [Pixel]()
        for x in 0..<width {
            for y in 0..<height {
                // Construct pixel
                let pixelData = ((Int(width) * y) + x) * 4
                let pixel = Pixel(r: Double(imageData[pixelData]) / 255.0, g: Double(imageData[pixelData + 1]) / 255.0, b: Double(imageData[pixelData + 2]) / 255.0, a: Double(imageData[pixelData + 3]) / 255.0)
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
    private(set) var r: Double
    private(set) var g: Double
    private(set) var b: Double
    private(set) var a: Double
    
    private(set) var count = 0

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
}

extension UIColor {
    fileprivate convenience init?(pixel: Pixel) {
        guard pixel.r != .nan else {
            return nil
        }
        
        self.init(red: CGFloat(pixel.r), green: CGFloat(pixel.g), blue: CGFloat(pixel.b), alpha: CGFloat(pixel.a))
    }
}

// MARK: K-Means Clustering Helper

extension Pixel: Comparable {
    // MARK: K-Means stuff

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
        return pixels.sorted(by: >)
    }
}
