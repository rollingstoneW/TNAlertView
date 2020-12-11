Pod::Spec.new do |s|
  s.name             = 'TNAlertView'
  s.version          = '0.0.7'
  s.summary          = '扩展性高、易用的弹窗'

  s.description      = <<-DESC
扩展性高、易用的弹窗。
                       DESC

  s.homepage         = 'https://github.com/rollingstoneW/TNAlertView'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'rollingstoneW' => '190268198@qq.com' }
  s.source           = { :git => 'https://github.com/rollingstoneW/TNAlertView.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'

  s.dependency 'Masonry'
  s.frameworks = 'UIKit', 'Foundation'
  s.public_header_files = 'TNAlertView/Classes/**/*.h'
  s.source_files = 'TNAlertView/Classes/**/*'

end
