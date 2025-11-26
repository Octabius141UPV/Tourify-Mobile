# Tourify Mobile

Tourify es la app que crea, organiza y comparte guías de viaje inteligentes en iOS y Android. Usa Firebase (auth, Firestore, Storage), un backend propio (`API_BASE_URL`) y servicios de mapas para mezclar recomendaciones en tiempo real con colaboración y analítica.

## Que puedes hacer con la app
- Onboarding guiado y seguro: registro con email/clave, Google o Apple, verificacion por SMS como segundo factor, biometria (Face/Touch ID) y deep links para completar registros pendientes.
- Crear guias en minutos: selecciona destino (autocompletado Google Places), fechas y viajeros; acepta/rechaza sugerencias en Discover con cards tipo swipe y se genera una guia con dias, franjas horarias y actividades ordenadas.
- Editar y enriquecer cada guia: reorganiza dias/actividades, agrega o edita con dialogos dedicados, sube tickets/reservas (Firestore + Storage), asigna colaboradores y controla permisos de edicion.
- Mapas y exportaciones: vista integrada con Google Maps, geocodificacion/places para pinpoints, rutas, seleccion por dias y exportacion a listas privadas de Google Maps/My Maps desde `GoogleMapsExportService`.
- IA y productividad: chat de agente de viaje por guia (streaming desde el backend) para ajustar planes, resúmenes o reordenar actividades.
- Compartir y vista previa: links con token para preview solo lectura, invitaciones a colaborar y manejo de `sharedWithMe`/`recentlyOpened` para reabrir guias rapidas.
- Seguimiento y contenido publico: rachas de ciudades viajadas, estadisticas en Home, ver guias publicas y contadores de vistas, con VersionService que bloquea builds obsoletas.
- Observabilidad: Firebase Analytics + Microsoft Clarity (si hay `CLARITY_PROJECT_ID`), NavigationObserver y logs controlados por `DebugConfig`.

## Arquitectura rapida
- `lib/main.dart`: punto de entrada; carga `.env`, inicializa Firebase/Analytics/Clarity, registra deep links con `AppLinks` y usa `NavigationService.navigatorKey`.
- `lib/screens/`: flujo completo de la app.
  - `onboarding/`: bienvenida interactiva, recogida de preferencias, Face/Touch ID y SMS MFA.
  - `auth/`: login, registro, verificacion de email y reset de clave.
  - `main/`: Home, perfil, streaks y `AppWrapper` que decide entre update, welcome u home.
  - `guides/`: Discover (swipe), detalle de guia con mapa, colaboracion y modales de organizacion.
  - `other/`: pantallas de update, premium, etc.
- `lib/services/`: capa de dominio y APIs (AuthService, DiscoverService, GuideService, CollaboratorsService, GoogleMapsExportService, AnalyticsService, VersionService, NavigationService, OnboardingService, UserService, LocationService, etc.).
- `lib/widgets/`: UI reutilizable (navegacion inferior, modales de guia, mapa, chat del agente, tutoriales, tickets).
- `lib/config/`: colores, Firebase options, configuracion de API y flags de debug.
- `assets/`: icono y recursos; `.env` esta declarado como asset en `pubspec.yaml`.

## Requisitos previos
- Flutter 3.2+ (Dart 3.2+) y toolchains de iOS (Xcode 15+) / Android (SDK 21+).
- Archivos nativos de Firebase en `ios/` y `android/` (`GoogleService-Info.plist` y `google-services.json`).
- Claves de Google Maps activas para iOS/Android y facturacion habilitada.
- Backend accesible en `API_BASE_URL` con los endpoints usados por `ApiService`.

## Configuracion rapida
1) Crea `.env` en la raiz con valores reales:
```
API_BASE_URL=https://tu-backend.com
GUEST_APP_KEY=clave_para_modo_invitado
CLARITY_PROJECT_ID=tu_clarity_project_id_aqui   # vacio para desactivar
FIREBASE_API_KEY=xxx
FIREBASE_APP_ID=xxx
FIREBASE_MESSAGING_SENDER_ID=xxx
FIREBASE_PROJECT_ID=xxx
FIREBASE_STORAGE_BUCKET=xxx.appspot.com
FIREBASE_AUTH_DOMAIN=xxx.firebaseapp.com
GOOGLE_IOS_CLIENT_ID=xxx.apps.googleusercontent.com
GOOGLE_MAPS_API_KEY=xxx
```
1b) iOS: copia `ios/Runner/GoogleService-Info.plist.example` a `ios/Runner/GoogleService-Info.plist` con tus claves de Firebase/Google; añade tu `GMSApiKey` en `ios/Runner/Info.plist` (no la publiques).
2) Instala dependencias: `flutter pub get`.
3) Ejecuta en el dispositivo/emulador deseado:
   - `flutter run -d ios`
   - `flutter run -d android`
   - `flutter run -d chrome` (para pruebas rapidas web).
4) Comprueba que el backend responde en `API_BASE_URL` y que los deep links estan configurados para App Links/Universal Links si los vas a usar.

## Flujos principales
- Bienvenida y onboarding: `AppWrapper` muestra UpdateScreen si hay version forzada en `app_versions/config` de Firestore; si no, lleva a Welcome → onboarding interactivo → registro/login. Si llega un link de colaboracion antes de autenticarse, se guarda `pendingJoin` y se usa tras completar el onboarding.
- Creacion de guia: en Home abre `CreateGuideModal` → destino con Google Places, fechas y viajeros → Discover (stream de actividades con swipe). Al confirmar se crea la guia en Firestore con dias y horarios, y opcionalmente se publica.
- Edicion y colaboracion: en `GuideDetailScreen` se pueden reordenar dias, editar actividades, abrir mapa filtrando por dias, adjuntar tickets/reservas, exportar a Google Maps, abrir el chat de agente o invitar colaboradores/compartir token de preview.
- Perfil y preferencias: `ProfileScreen` permite editar nombre/username/localidad, lanzar de nuevo el tutorial de guias y ajustar preferencias de viaje en `PreferencesScreen`.
- Estadisticas y rachas: Home muestra guias recientes (propias y compartidas) y KPI de actividades/ciudades; `StreakScreen` ensena la racha actual y objetivos.

## Calidad y builds
- Formato: `dart format lib test`
- Linter/analyze: `flutter analyze`
- Tests: `flutter test`
- Builds release: `flutter build apk --release` | `flutter build ios --release`

## Notas utiles para desarrollo
- Las claves de entorno se cargan en `main.dart` y `FirebaseConfig`; si falta alguna, veras logs de debug en consola.
- `NavigationService` gestiona deep links de Firebase Auth y accesos compartidos a guias; evita manipular `Navigator` global sin pasar por su `navigatorKey`.
- `DiscoverService` requiere usuario autenticado; en modo invitado se guarda una guia temporal en `SharedPreferences` hasta que el usuario se registre.
