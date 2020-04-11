//
//  File.swift
//
//  Created by Alfonso Gonzalez on 4/9/20.
//

import UIKit

public struct UIImageColorPalette {
    let primary: UIColor
    let secondary: UIColor
    let tertiary: UIColor
    
    public init(primary: UIColor, secondary: UIColor, tertiary: UIColor) {
        self.primary = primary
        self.secondary = secondary
        self.tertiary = tertiary
    }
}

public enum UIImageResizeQuality: CGFloat {
    public case: low = 0.3
    public case: medium = 0.5
    public case: high = 0.8
    public case: standard = 0.0
}

extension UIImage {
    private func resizeImage(desiredSize: CGSize) -> UIImage {
        // UIGraphicsImageRenderer makes life easy
        let renderer = UIGraphicsImageRenderer(size: desiredSize)
        return renderer.image { (context) in
            self.draw(in: CGRect(origin: .zero, size: desiredSize))
        }
    }
    
    public func retrieveColorPalette(quality: UIImageResizeQuality = .standard, _ completion: @escaping (UIImageColorPalette?) -> Void) {
        // Run in background
        DispatchQueue.global(qos: .utility).async {
            let palette = retrieveColorPalette(quality: quality)
            
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
            let currentSize = self.size
            let newSize = CGSize(width: currentSize.width * quality.rawValue, height: currentSize.height * quality.rawValue)
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
        
        var pixels:[Pixel] = [Pixel](repeating: 0, count: width * height)
        for x in 0..<width {
            for y in 0..<height {
                // Construct pixel
                let pixelData = ((Int(width) * y) + x) * 4
                let pixel = Pixel(r: Double(imageData[pixelData]) / 255.0, g: CGFloat(imageData[pixelData + 1]) / 255.0, b: CGFloat(imageData[pixelData + 2]) / 255.0, a: CGFloat(imageData[pixelData + 3]) / 255.0)
                pixels.append(pixel)
            }
        }
        
        // Process by k-means clustering
        let analyzer = KMeans(clusterNumber: 3, desiredAccuracy: 0.01, dataPoints: pixels)
        let prominentPixels = analyzer.calculateProminentClusters()
        
        // Create palette object
        let primaryColor = UIColor(pixel: prominentPixels[0])
        let secondaryColor = UIColor(pixel: prominentPixels[0])
        let tertiaryColor = UIColor(pixel: prominentPixels[0])
        
        return UIImageColorPalette(primary: primaryColor, secondary: secondaryColor, tertiary: tertiaryColor)
    }
}


fileprivate struct Pixel {
    let r: Double
    let g: Double
    let b: Double
    let a: Double

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
    fileprivate init(pixel: Pixel) {
        return UIColor(red: pixel.r, green: pixel.g, blue: pixel.b, alpha: pixel.a)
    }
}

// Hide the kmeans stuff in a class
private class KMeans {
    let clusterNumber: Double
    let desiredAccuracy: Double
    let dataPoints: [Pixel]
    
    init(clusterNumber: Double, desiredAccuracy: Double, dataPoints: [Pixel]) {
        self.clusterNumber = clusterNumber
        self.desiredAccuracy = desiredAccuracy
        self.dataPoints = dataPoints
    }
    
    private func getRandomSamples<T>(_ samples: [T], k: Int) -> [T] {
        var result = [T]()
        
        // Fill array with a random entry in samples
        for _ in 0..<k {
            let random = Int.random(in: 0..<samples.count)
            result.append(samples[random])
        }

        return result
    }
    
    private func kMeans(centers: Int, convergeDistance: Double, entries: [Pixel]) -> [Pixel] {
        // The main engine behind the scenes
        var randomSamples = getRandomSamples(entries, k: centers)
        
        var centerMoveDist = 0.0
        repeat {
            
        } while centerMoveDist > convergeDistance
        
        return randomSamples
    }
    
    func calculateProminentClusters() -> [Pixel] {
        return kMeans(centers: clusterNumber, convergeDistance: desiredAccuracy, entries: dataPoints)
    }
}
