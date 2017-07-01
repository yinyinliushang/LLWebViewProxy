#
#  Be sure to run `pod spec lint LLWebViewProxy.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|
  s.description  = <<-DESC
                   DESC
  s.name         = "LLWebViewProxy"
  s.version      = "0.0.1"
  s.summary      = "A standalone iOS & OSX class for intercepting and proxying HTTP requests (e.g. from a Web View)"
  s.homepage     = "https://github.com/yinyinliushang/LLWebViewProxy"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { "刘政利" => "liuzhengli0706@163.com" }
  s.requires_arc = true
  s.source       = { :git => "https://github.com/yinyinliushang/LLWebViewProxy.git", :tag => "#{s.version}" }
  s.ios.platform     = :ios, "9.0"
  s.osx.platform     = :osx, "10.9.4"
  s.ios.source_files = "LLWebViewProxy/*.{h,m}"
  s.osx.source_files = "LLWebViewProxy/*.{h,m}"
  s.ios.framework    = "UIKit"
  s.osx.framework    = "WebKit"
end
