#
#  Be sure to run `pod spec lint EWAAudioPlayerView.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  s.name         = "EWAAudioPlayerView"
  s.version      = "0.9.3"
  s.summary      = "Customizable audio player user interface for iOS"

  s.description  = <<-DESC
                   A longer description of EWAAudioPlayerView in Markdown format.

                   * with time scrubber
                   * properties exposed for visual customization
                   * handles audio in the bundle, and remote audio URLs
                   * tested mainly with caf and mp3 files so far
                   DESC

  s.homepage     = "https://github.com/mattblair/EWAAudioPlayerViewDemo"
  # s.screenshots  = "www.example.com/screenshots_1", "www.example.com/screenshots_2"

  s.license      = { :type => 'MIT' }
  s.author       = { "Matt Blair" => "elsewisemedia@gmail.com" }

  s.platform     = :ios
  s.ios.deployment_target = '7.0'

  s.source       = { :git => "https://github.com/mattblair/EWAAudioPlayerViewDemo.git", :tag => "0.9.3" }
  s.source_files  = 'EWAAudioPlayerView'

  # ――― Resources ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

  s.frameworks = 'AVFoundation'
  s.requires_arc = true

end
