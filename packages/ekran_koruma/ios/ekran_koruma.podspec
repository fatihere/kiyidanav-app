Pod::Spec.new do |s|
  s.name             = 'ekran_koruma'
  s.version          = '1.0.0'
  s.summary          = 'KıyıdanAv ekran kaydı koruması'
  s.homepage         = 'https://www.kiyidanav.com'
  s.license          = { :type => 'MIT' }
  s.author           = { 'KıyıdanAv' => 'info@kiyidanav.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
end
