# Axis Frontend

Aplicación Flutter que consume la API de TourifyUPV. Compila para Android, iOS y web.

## Requisitos previos

- Flutter 3.22 o superior (incluye Dart SDK).
- Xcode y CocoaPods para compilar iOS (macOS).
- Android Studio + Android SDK para compilar Android.
- Acceso a los ficheros de configuración de Firebase (`google-services.json`, `GoogleService-Info.plist`).

Verifica tu instalación con:
```bash
flutter doctor
```

## Instalación y ejecución

1. **Instala dependencias del proyecto**:
	```bash
	flutter pub get
	```
2. **Selecciona un dispositivo/emulador**:
	```bash
	flutter devices
	```
3. **Ejecuta la app**:
	```bash
	flutter run
	```
	- Web: `flutter run -d chrome`
	- Android (emulador): `flutter run -d emulator-5554`
	- iOS (simulador): `flutter run -d ios`

## Configuración de Firebase

- Android: coloca `google-services.json` en `android/app/`.
- iOS: coloca `GoogleService-Info.plist` en `ios/Runner/` y ejecuta `pod install` dentro de `ios/` si es necesario.
- Web: revisa `firebase.json`, `firestore.rules` y el contenido de `web/`.

Si cambias entornos de Firebase, ejecuta `flutterfire configure` o sincroniza con los archivos oficiales del equipo.

## Comandos útiles

- `flutter analyze`: análisis estático.
- `flutter test`: ejecuta las pruebas unitarias.
- `flutter build apk`: compila APK de producción.
- `flutter build ios --release`: compila IPA (requiere cuenta Apple y configuración de firmas).
- `flutter build web`: genera build web en `build/web/`.

## Estructura principal

- `lib/`: código Dart de la aplicación (config, models, screens, widgets, servicios).
- `assets/`: recursos gráficos.
- `android/`, `ios/`: proyectos nativos para cada plataforma.
- `web/`: config y recursos para la versión web.

## Recomendaciones

- Mantén `flutter run` activo durante el desarrollo para aprovechar hot-reload.
- Tras instalar nuevos paquetes, vuelve a ejecutar `flutter pub get` y revisa posibles cambios en archivos generados.
- Antes de abrir un PR, ejecuta `flutter analyze && flutter test`.
