source 'https://cdn.cocoapods.org/'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      if config.build_settings['MACOSX_DEPLOYMENT_TARGET'] == ''
        config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.10'
      end
    end
  end
end

target 'ClashX' do
  inhibit_all_warnings!
  use_frameworks!
  pod 'LetsMove'
  pod 'Alamofire', '~> 5.0'
  pod 'SwiftyJSON'
  pod 'RxSwift'
  pod 'RxCocoa'
  pod 'CocoaLumberjack/Swift'
  pod 'WebViewJavascriptBridge'
  pod 'Starscream','3.1.1'
  pod 'Fabric'
  pod 'Crashlytics'
  pod 'Sparkle'
  
end

