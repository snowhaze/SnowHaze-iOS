
platform :ios, '12.4'

target 'SnowHaze' do

pod 'SQLCipher', '~> 4.4', :inhibit_warnings => true
pod 'Sodium', '0.8'
pod 'Tor', podspec: 'https://raw.githubusercontent.com/iCepa/Tor.framework/v406.8.2/Tor.podspec'

end
post_install do |installer|
	installer.pods_project.targets.each do |target|
		target.build_configurations.each do |config|
			if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 12.4
				config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.4'
			end
		end
	end
end
