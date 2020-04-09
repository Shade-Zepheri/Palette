Pod::Spec.new do |spec|
  spec.name        = "Palette"
  spec.version     = "1.0.0"
  spec.license     = "MIT"
  spec.summary     = "Retrieve the color pallete of an UIImage."
  spec.homepage    = "https://github.com/Shade-Zepheri/Palette"
  spec.authors     = { "Shade Zepheri" => "https://twitter.com/alfonso_gonzo" }
  spec.source      = { :git => "https://github.com/Shade-Zepheri/Palette.git", :tag => spec.version }

  spec.ios.deployment_target = "8.0"
  spec.source_files = "Sources/Palette/*.swift"
  spec.requires_arc = true
  spec.pod_target_xcconfig = {
    "SWIFT_VERSION" => "5.0"
  }
end
