# AGENTS.md

This file gives AI agents the project context and working rules for this repository. Its scope is the entire repository.

## Project at a glance

- **Product**: TinyPNG GUI, a Flutter desktop application for batch image compression through the TinyPNG/Tinify API.
- **Primary platform**: Windows desktop. The app initializes `sqflite_common_ffi` and `window_manager` in `lib/main.dart`; keep desktop behavior in mind when changing startup, storage, or file handling code.
- **Language / framework**: Dart + Flutter, Material 3 UI, `provider` for state management.
- **Architecture intent**: The docs describe a layered architecture plus MVVM-style state separation. The current codebase is organized as UI widgets, provider-backed notifiers, services, data models, and local/remote data sources.

## Important source map

- `lib/main.dart` wires application startup, Windows window options, `SharedPreferences`, the Provider tree, theme selection, and `HomeScreen`.
- `lib/data/models/`
  - `compression_task.dart`: task entity and `CompressionStatus` lifecycle.
  - `api_key_info.dart`: API key metadata, status, usage counters, default flag.
  - `app_settings.dart`: persisted app settings, including API keys, output behavior, concurrency, retry count, language, and theme.
  - `compression_result_data.dart`: API compression result payload.
- `lib/data/datasources/local/`
  - `settings_local_data_source.dart`: `SharedPreferences`-backed `AppSettings` persistence.
  - `secure_api_key_storage.dart`: encrypted API key persistence using AES plus `flutter_secure_storage`; call `initialize()` before reading/writing keys.
- `lib/data/datasources/remote/tinypng_api.dart`: low-level TinyPNG HTTP client based on `dio`; manages Basic Auth, `/shrink`, optional resize/convert processing, download, compression-count parsing, validation, and API exception mapping.
- `lib/services/`
  - `api_key_service.dart`: initializes secure key storage, manages available/default keys, validation, usage updates, and auto-rotation.
  - `compression_service.dart`: orchestrates one compression task: initialize API keys, read settings, call TinyPNG with key rotation, compute output path, write compressed bytes, and return updated task state.
  - `queue_service.dart`: in-memory queue with `pool`-based concurrency, pause/resume/stop, and broadcast `QueueEvent`s.
  - `file_service.dart`: supported extension checks, file size formatting, output path generation, directory creation, and file/directory checks.
  - `logger_service.dart`: centralized logging wrapper; prefer it over `print` in production code.
- `lib/providers/`
  - `settings_notifier.dart`: load/update/reset persisted settings.
  - `tasks_notifier.dart`: task list state, aggregate statistics, retry/clear operations, and synchronization from queue events.
  - `queue_status_notifier.dart`: queue status/progress/control facade for UI.
  - `providers.dart`: barrel export for notifiers.
- `lib/screens/`
  - `home/`: main batch workflow UI, file list, stats panel, queue controls, and action toolbar.
  - `settings/`: settings UI and widgets for API keys, compression, appearance, and output.
- `docs/`: design and usage references. Read these before changing the related subsystem:
  - `docs/architecture.md`: intended architecture, module responsibilities, persistence, errors, performance, Windows notes, and conventions.
  - `docs/requirements.md`: functional/non-functional requirements, TinyPNG limits, UI/storage/error handling requirements.
  - `docs/implementation_plan.md`: phased implementation plan and dependency list.
  - `docs/*_usage.md` and `docs/*_guide.md`: provider/storage integration examples and best practices.

## Runtime flow to preserve

1. `main()` initializes Flutter bindings, Windows database FFI, window manager options, and `SharedPreferences`.
2. `TinyPngApp` builds a `MultiProvider` tree:
   - data sources: settings storage, secure API key storage, TinyPNG API client;
   - services: file service, API key service, compression service, queue service;
   - notifiers: settings, tasks, and queue status.
3. `MainApp` reads `SettingsNotifier.settings.themeMode` using `context.select` and renders `HomeScreen`.
4. UI actions create/update `CompressionTask`s in `TasksNotifier`; queue-related notifiers and services coordinate start/pause/resume/stop and task completion updates.
5. `CompressionService.compressTask()` is the central per-file workflow: initialize key service, read settings, compress via `TinyPngApi`, rotate keys on quota if enabled, save output with `FileService`, and return a completed or failed task.

## State management rules

- Continue using `provider`/`ChangeNotifier`; do not introduce another state-management framework unless explicitly requested.
- Use `context.watch`/`Consumer` for reactive UI, `context.read` for one-time actions, and `context.select`/`Selector` for focused rebuilds.
- Keep queue execution state in `QueueService`, task list and statistics in `TasksNotifier`, and user settings in `SettingsNotifier`.
- `QueueService.events` is a broadcast stream. If you add listeners, dispose subscriptions to avoid leaks.
- `QueueService` uses `Pool`; dynamic concurrency changes do not resize an already-created pool. Prefer applying concurrency before queue start unless you also update this behavior deliberately.

## Persistence and security rules

- API keys are sensitive. Do not log raw API keys; existing code masks or avoids them. Preserve that behavior.
- `SecureApiKeyStorage.initialize()` must run before `saveApiKeys()`, `getApiKeys()`, or deletion methods.
- API keys are stored separately from normal settings. `AppSettings` may include key metadata, but secure storage is the authority for key secrets.
- Settings are serialized via `AppSettings.toJson()` into `SharedPreferences` key `app_settings`; keep JSON compatibility when changing models.
- Be careful with `SecureApiKeyStorage.clearAll()`: it removes the device identifier and can make previously encrypted data unrecoverable.

## TinyPNG API rules

- The TinyPNG client authenticates with Basic Auth where username is `api` and password is the API key.
- `/shrink` upload responses include the compressed download URL and may include `Compression-Count`; keep usage accounting in sync with `ApiKeyService.updateKeyUsage()`.
- Handle these errors distinctly:
  - `401` -> invalid API key.
  - `429` -> quota exceeded; `CompressionService` may rotate keys when `AppSettings.autoRotateKeys` is true.
  - network errors -> surface as network/API failures without crashing the queue.
- TinyPNG supports `.jpg`, `.jpeg`, `.png`, `.webp`, and `.avif` in this project. Keep `FileService.supportedExtensions` aligned with UI filtering and requirements docs.

## File/output behavior

- Use `FileService.getOutputPath()` for output naming and directory placement rather than duplicating path logic.
- Use `FileService.ensureDirectoryExists()` before writing generated files.
- Respect settings for `outputDirectory`, `overwriteOriginal`, and `fileNameSuffix`.
- When adding directory-recursive features, preserve folder structure only through the `baseDir` mechanism already present in `FileService.getOutputPath()`.

## UI conventions

- UI text is currently Chinese in most application-facing widgets; keep new user-facing strings consistent unless the task asks for localization changes.
- The app uses Material 3 and a `ColorScheme.fromSeed` blue theme with `Microsoft YaHei` font in `MainApp`.
- Home screen widgets live under `lib/screens/home/widgets/`; settings widgets live under `lib/screens/settings/widgets/`. Put new screen-specific widgets near their screen unless they are truly reusable.
- Settings UI should write through `SettingsNotifier` methods so validation and persistence remain centralized.

## Coding conventions

- Follow `flutter_lints` from `analysis_options.yaml`.
- Prefer small, focused classes matching the existing layer boundaries.
- Prefer immutable model updates through `copyWith()` and JSON helpers already defined on models.
- Use `LoggerService` instead of `print` for app diagnostics.
- Do not wrap imports in `try/catch` blocks.
- Avoid committing generated build output or local platform artifacts unless the task explicitly requires it.

## Test and validation commands

Run the narrowest useful checks after changes. Common commands:

```bash
flutter pub get
flutter analyze
flutter test
```

For documentation-only changes, a quick repository check such as `git diff --check` is usually sufficient.

## Known documentation/code drift

- `docs/architecture.md` includes planned folders such as `app/`, `core/`, `domain/`, repositories, and history storage that may not exist in the current implementation. Treat docs as architecture intent, but verify against `lib/` before editing code.
- `README.md` is still the default Flutter starter README and is not a reliable source of product behavior.
- Some docs include illustrative examples rather than exact current code. Prefer actual source files when behavior differs.
