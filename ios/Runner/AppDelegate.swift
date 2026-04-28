import UIKit
import Flutter
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Load Google Maps API Key from environment or Info.plist
    if let apiKey = loadGoogleMapsAPIKey() {
      GMSServices.provideAPIKey(apiKey)
    } else {
      print("⚠️ WARNING: Google Maps API Key not found. Maps functionality may not work.")
      print("Set the API_KEY in Info.plist or GOOGLE_MAPS_API_KEY in .env file")
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  /// Load Google Maps API Key from multiple sources
  /// Priority: Bundle (Info.plist) > Environment
  private func loadGoogleMapsAPIKey() -> String? {
    // First, try loading from Info.plist
    if let apiKey = Bundle.main.infoDictionary?["API_KEY"] as? String, !apiKey.isEmpty {
      return apiKey
    }
    
    // Fallback: Log warning if key not found
    return nil
  }
}
