Pod::Spec.new do |s|
  s.name         = "Slingshot"
  s.version      = "1.0.1"
  s.summary      = "Lightweight extension to UIScrollView that adds a pull up at the bottom of a UISCrollView, and slingshot back to the top!"
  s.homepage     = "https://github.com/GreenJell0/Slingshot"
  s.description  = <<-DESC
  
  This extension adds a "slingshot" behavior to any scroll view via `isSlingshotEnabled`. When enabled, if the user scrolls past the bottom of
  the content a certain amount (the "threshold") and releases, the scroll view will slingshot and scroll back to the top of the content. As they scroll past
  the content, a view (the slingshot view) appears and hints that this behavior is available and when they've scrolled sufficiently far. This behavior is
  implemented by observing the scroll view's content offset and keying off of certain stateful properties (see `startObserving`) to determine whether the user
  is scrolling and whether the slingshot should engage and trigger.
  
  DESC
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = 'GreenJell0'
  s.platform     = :ios, "11.0"
  s.source       = { :git => "https://github.com/GreenJell0/Slingshot.git", :tag => s.version.to_s }
  s.requires_arc = true
  s.source_files = "Sources/*.{swift}"
  s.resources    = "Resources/Images.xcassets"
  s.framework    = "UIKit"
  s.swift_version = '5.0'
end
