Pod::Spec.new do |s|
  s.name = 'Bridgecraft'
  s.version = '0.0.1'
  s.license = 'MIT'
  s.summary = 'Generate Swift interface for ObjC bridging headers '
  s.description = <<-DESC
Bridgecraft is a command line tool for generating the Swift interface 
for ObjC bridging headers. This comes handy if you have a mixed Swift-ObjC codebase 
and you want to use code generation tools (e.g. Sourcery) that only support Swift.
DESC
  s.homepage = 'https://github.com/lvsti/Bridgecraft'
  s.license = 'MIT'
  s.authors = { 'Tamas Lustyik' => 'elveestei@gmail.com' }
  s.social_media_url = 'https://twitter.com/cocoagrinder'
  s.source = { :http => "https://github.com/lvsti/Bridgecraft/releases/download/#{s.version}/Bridgecraft-#{s.version}.zip" }
  s.preserve_paths = '*'
  s.exclude_files = '**/file.zip'
end

