import Flutter
import UIKit
import GoogleSignIn
import GoogleMaps
import UserNotifications
import Firebase
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Configurar Firebase
    FirebaseApp.configure()
    
    // Configurar Google Sign-In usando el helper
    GoogleSignInHelper.shared.configureGoogleSignIn()
    
    // Configurar notificaciones push para evitar reCAPTCHA
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    
    // Solicitar permisos de notificación
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      if granted {
        print("✅ Permisos de notificación concedidos")
      } else {
        print("❌ Permisos de notificación denegados: \(error?.localizedDescription ?? "")")
      }
    }
    
    GMSServices.provideAPIKey("AIzaSyAhOtZkJTa31bfL4W4BLAAG3P2wOWxyfGM")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    if GIDSignIn.sharedInstance.handle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }
  
  // Manejar token de notificaciones push
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    print("📱 Device Token: \(token)")
    
    // Enviar token a Firebase Messaging
    Messaging.messaging().apnsToken = deviceToken
  }
  
  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ Failed to register for remote notifications: \(error)")
  }
  
  // Manejar notificaciones cuando la app está en primer plano
  override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.alert, .badge, .sound])
  }
  
  // Manejar toque en notificación
  override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    completionHandler()
  }
}
