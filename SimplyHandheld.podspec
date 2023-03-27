Pod::Spec.new do |spec|
  spec.name         = "SimplyHandheld"
  spec.version      = "0.2.3"
  spec.summary      = "Simply RFID Master Handheld Service"
  spec.description  = "A framework for all supported SimplyRFID handhelds"

  spec.homepage     = "https://github.com/VinceSantos/SimplyHandheld"
  spec.license      = "MIT"
  spec.author             = { "Vince Santos" => "vince.santos@simplyrfid.com" }
  spec.platform     = :ios, "13.0"
  spec.source       = { :git => "https://github.com/VinceSantos/SimplyHandheld", :tag => spec.version.to_s }
  spec.source_files  = "SimplyHandheld"
  spec.swift_versions = "5.0"
  spec.dependency 'CSL-CS108'
  spec.dependency 'SimplyChainway'
end
