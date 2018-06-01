Pod::Spec.new do |s|
  s.name     = 'LLWebViewProxy'
  s.version  = '0.0.2'
  s.license  = 'MIT'
  s.summary  = "A standalone iOS & OSX class for intercepting and proxying HTTP requests (e.g. from a Web View)."
  s.homepage = 'https://github.com/yinyinliushang/LLWebViewProxy'
  s.authors  = { '刘政利' =>
                 'liuzhengli0706@163.com' }
  #s.social_media_url = "https://twitter.com/mattt"
  s.source   = { :git => 'https://github.com/yinyinliushang/LLWebViewProxy.git', :tag => s.version }
  s.requires_arc = true
  s.public_header_files = 'LLWebViewProxy/LLWebViewProxy.h'
  #s.source_files = 'LLWebViewProxy/LLWebViewProxy.h'
  s.ios.deployment_target     = :ios, '6.1'
  s.osx.deployment_target     = :osx, '10.9.4'
  s.ios.source_files = 'LLWebViewProxy/*.{h,m}'
  s.osx.source_files = 'LLWebViewProxy/*.{h,m}'
  s.ios.framework    = 'UIKit'
  s.osx.framework    = 'WebKit'
end
