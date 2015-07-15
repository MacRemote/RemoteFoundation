Pod::Spec.new do |s|
  s.name         = "MRFoundation"
  s.version      = "0.1"
  s.summary      = "A network communication framework."

  s.description  = "MRFoundation is a network communication framework for iOS and OS X."

  s.homepage     = "https://github.com/MacRemote/RemoteFoundation"
  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author             = { "h1994st" => "h1994st@gmail.com" }
  s.social_media_url   = "http://twitter.com/h1994st"

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.9"

  s.source       = { :git => "https://github.com/MacRemote/RemoteFoundation.git", :tag => s.version }

  s.source_files = "MRFoundation/*.swift"

  s.requires_arc = true

  s.dependency "CocoaAsyncSocket", "~> 7.0"
end
