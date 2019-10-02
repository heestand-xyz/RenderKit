Pod::Spec.new do |spec|

  spec.name         = "RenderKit"
  spec.version      = "0.1.0"

  spec.summary      = "Live Graphics Realtime Render Engine"
  spec.description  = <<-DESC
  					          Live Graphics Realtime Render Engine.
                      DESC

  spec.homepage     = "http://hexagons.se"

  spec.license      = { :type => "MIT", :file => "LICENSE" }

  spec.author             = { "Hexagons" => "anton@hexagons.se" }
  spec.social_media_url   = "https://twitter.com/anton_hexagons"

  spec.ios.deployment_target  = "11.0"
  spec.osx.deployment_target  = "10.13"
  spec.tvos.deployment_target = "11.0"
  
  spec.swift_version = '5.0'

  spec.source        = { :git => "https://github.com/hexagons/renderkit.git", :branch => "master", :tag => "#{spec.version}" }

  spec.source_files  = "Source", "Source/**/*.swift"

end
