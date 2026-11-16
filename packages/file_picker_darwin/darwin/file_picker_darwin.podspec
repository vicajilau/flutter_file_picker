#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint file_picker_darwin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'file_picker_darwin'
  s.version          = '1.0.0'
  s.summary          = 'iOS and macOS implementation of file_picker plugin'
  s.description      = <<-DESC
iOS and macOS implementation of file_picker plugin
                       DESC
  s.homepage         = 'https://github.com/vicajilau/flutter_file_picker'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = 'Miguel Ruivo, Dominik Roszkowski'
  s.source           = { :path => '.' }
  s.source_files     = 'file_picker_darwin/Sources/file_picker_darwin/**/*.swift'
  s.resource_bundles = {
    'file_picker_darwin_privacy' => ['file_picker_darwin/Sources/file_picker_darwin/PrivacyInfo.xcprivacy']
  }

  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '14.0'
  s.osx.deployment_target = '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
