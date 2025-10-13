source 'https://cdn.cocoapods.org/'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Force Swift 5.0 for all pods to maintain Xcode 15 compatibility
      if config.build_settings['SWIFT_VERSION'] && Gem::Version.new(config.build_settings['SWIFT_VERSION']) > Gem::Version.new('5.0')
        config.build_settings['SWIFT_VERSION'] = '5.0'
      end

      # Ensure minimum deployment target
      if config.build_settings['MACOSX_DEPLOYMENT_TARGET'] == '' || Gem::Version.new(config.build_settings['MACOSX_DEPLOYMENT_TARGET']) < Gem::Version.new("10.14")
        config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.14'
      end
    end
  end
end

target 'ClashX' do
  platform :osx, '10.14'
  inhibit_all_warnings!
  use_modular_headers!
  pod 'LetsMove'
  pod 'Alamofire', '~> 5.0'
  pod 'SwiftyJSON'
  pod 'RxSwift', '~> 6.0'
  pod 'RxCocoa', '~> 6.0'
  pod 'CocoaLumberjack/Swift', '~> 3.8.0'
  pod 'Starscream','3.1.1'
  pod 'AppCenter/Analytics'
  pod 'AppCenter/Crashes'
  pod 'Sparkle','~>2.0'
  pod "FlexibleDiff"
  pod 'GzipSwift'
  pod 'SwiftLint'
  pod 'SwiftFormat/CLI', '~> 0.49'
end

