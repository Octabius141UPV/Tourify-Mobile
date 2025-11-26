# Repository Guidelines

## Project Structure & Modules
- Entry point: `lib/main.dart` (routing, theme, deep links).
- Screens: `lib/screens/**` (e.g., `auth/`, `guides/`, `main/`, `onboarding/`).
- Services: `lib/services/**` (API, auth, analytics, maps, navigation).
- Widgets: `lib/widgets/**` (map UI, home sections, dialogs, common UI).
- Data & Models: `lib/data/**`, `lib/models/**`.
- Config & Utils: `lib/config/**` (Firebase/app), `lib/utils/**` helpers.
- Platforms & Assets: `android/`, `ios/`, `web/`, `assets/` (includes `.env`).

## Build, Run & Analyze
- Install deps: `flutter pub get`.
- Run locally: `flutter run -d ios | -d android | -d chrome`.
- Build release: `flutter build apk --release`; `flutter build ios --release`.
- Analyze/lint: `flutter analyze` (rules from `analysis_options.yaml`).
- Format: `dart format lib test`.
- Tests: `flutter test` (add `--coverage` if needed).

## Coding Style & Naming
- Use Dart/Flutter style with `flutter_lints`; 2-space indent.
- Files: `snake_case.dart` (e.g., `guide_detail_screen.dart`).
- Classes/enums: `PascalCase`; methods/vars: `lowerCamelCase`.
- Widgets end with `Screen`/`Widget`; services end with `Service`.
- Prefer `const` constructors, trailing commas, and small, focused widgets.

## Testing Guidelines
- Framework: `flutter_test`.
- Location: `test/` with files ending in `_test.dart`.
- Widget tests: `pumpWidget(const AppWrapper())` and assert with finders.
- Service tests: isolate logic; mock Firebase/HTTP as appropriate.

## Commit & Pull Requests
- Commits: short, imperative summaries (ES/EN), e.g., "Agrega mapa" / "Fix login flow"; include scope when helpful (`auth:`, `map:`).
- Reference issues (`#123`) and explain rationale for non-trivial changes.
- PRs: clear description, linked issues, screenshots for UI, and test steps. Target the active development branch.

## Security & Configuration
- Secrets via `.env` (e.g., `API_BASE_URL`, `CLARITY_PROJECT_ID`); never commit keys.
- Firebase initialized in `lib/config/firebase_config.dart`; platform files (`GoogleService-Info.plist`, `google-services.json`) must exist locally.
- Google Maps keys managed per platform. Review `pubspec.yaml` assets and keep them in sync.

