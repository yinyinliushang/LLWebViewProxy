Pod::Spec.new do |s|
  s.description  = <<-DESC
                   DESC
  s.name         = "LLWebViewProxy"
  s.version      = “0.0.1”
  s.summary      = "A standalone iOS & OSX class for intercepting and proxying HTTP requests (e.g. from a Web View)"
  s.homepage     = "https://github.com/yinyinliushang/LLWebViewProxy"
  s.license      = "MIT"
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