Pod::Spec.new do |s|
  s.name     = 'LLWebViewProxy'
  s.version  = '0.0.1'
  s.license  = 'MIT'
  s.summary  = "A standalone iOS & OSX class for intercepting and proxying HTTP requests (e.g. from a Web View)."
  s.homepage = 'https://github.com/yinyinliushang/LLWebViewProxy'
  s.authors  = { '刘政利' =>
                 'liuzhengli0706@163.com' }
  #s.social_media_url = "https://twitter.com/mattt"
  s.source   = { :git => 'https://github.com/yinyinliushang/LLWebViewProxy.git', :tag => s.version }
  s.source_files = 'LLWebViewProxy'
end
