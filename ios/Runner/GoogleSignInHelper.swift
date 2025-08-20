import Foundation
import GoogleSignIn
import Firebase

class GoogleSignInHelper {
    static let shared = GoogleSignInHelper()
    
    private init() {}
    
    func configureGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("❌ Error: No se pudo cargar GoogleService-Info.plist")
            return
        }
        
        let config = GIDConfiguration(clientID: clientId)
        GIDSignIn.sharedInstance.configuration = config
        
        print("✅ Google Sign-In configurado correctamente para iOS")
    }
    
    func signInWithGoogle(presenting viewController: UIViewController, completion: @escaping (Result<GIDGoogleUser, Error>) -> Void) {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            completion(.failure(NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No se pudo cargar la configuración de Google"])))
            return
        }
        
        let config = GIDConfiguration(clientID: clientId)
        GIDSignIn.sharedInstance.configuration = config
        
        GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { result, error in
            if let error = error {
                print("❌ Error en Google Sign-In: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let user = result?.user else {
                completion(.failure(NSError(domain: "GoogleSignIn", code: -2, userInfo: [NSLocalizedDescriptionKey: "No se pudo obtener el usuario"])))
                return
            }
            
            print("✅ Google Sign-In exitoso para: \(user.profile?.email ?? "email no disponible")")
            completion(.success(user))
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        print("✅ Google Sign-Out completado")
    }
}
