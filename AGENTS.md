# AGENTS.md — DailySpur

DailySpur is a Daily Knowledge Prompt & Quiz: one customized question/fact per day in a user-chosen subject area. Early scaffold — backend is a placeholder `GET /weatherforecast`, mobile is `Hello World`.

## Structure

- `DailySpur.slnx` (root, new XML `slnx` format — not `sln`) -> `src/DailySpur.Api/DailySpur.Api.csproj`
- `src/DailySpur.Api/` — ASP.NET Core Minimal API, `net10.0`, `Nullable`+`ImplicitUsings` enabled, `Microsoft.AspNetCore.OpenApi` 10.0.6. Single file `Program.cs` (top-level statements, `AddOpenApi`/`MapOpenApi` in Development). No tests/projects yet.
- `src/dailyspur_mobile/` — Flutter app. **Folder is `dailyspur_mobile` but pubspec `name: dailyspur`** — imports are `package:dailyspur/...` (see `lib/main.dart:1`). Entrypoint `lib/main.dart:launchDailySpurApp()` -> `lib/daily_spur_app.dart:DailySpurApp` (MaterialApp, `deepPurple` seed).
- No CI/workflows (`.github/workflows/` empty), no `opencode.json`, no test directories.

## Commands

Requires .NET SDK 10.0.202+ (`net10.0`) and Flutter 3.44.x / Dart 3.13+ (verified `3.44.4` / `3.12.2`).

```bash
# API — from repo root
dotnet build DailySpur.slnx
dotnet run --project src/DailySpur.Api              # http://localhost:5205 https://localhost:7240 (see launchSettings.json)
dotnet watch --project src/DailySpur.Api

# Mobile — from src/dailyspur_mobile
flutter pub get
flutter analyze
flutter test              # no tests yet, but this is the harness
flutter run
dart format --set-exit-if-changed .
```

Single-suite verification: `dotnet build DailySpur.slnx` and `flutter analyze` inside `src/dailyspur_mobile`.

## Gotchas — Won't Guess Without This

- **Solution file is `DailySpur.slnx`**: `dotnet sln`/`dotnet build` must reference `DailySpur.slnx`, not `DailySpur.sln`.
- **Import mismatch**: `pubspec.yaml` name `dailyspur` ≠ folder `dailyspur_mobile`. Always `import 'package:dailyspur/...'`, not `package:dailyspur_mobile/...`.
- **Formatter/lint is strict**: `src/dailyspur_mobile/analysis_options.yaml` sets `page_width: 200`, `trailing_commas: preserve`, plus ~25 custom lints (`always_use_package_imports`, `avoid_relative_lib_imports`, `use_super_parameters`, etc.). Run `flutter analyze` before pushing; failures block logically even without CI.
- **`appsettings.*.json` is gitignored after initial commit**: `.gitignore:100` has `**/appsettings.*.json` (only `appsettings.json` whitelisted). `appsettings.Development.json` is tracked but now ignored — edits won't appear in `git status`; force with `git add -f` if you must. Don't add secrets there; use `secrets.json`/env vars.
- **`pubspec.lock` is intentionally committed** (app, not package) — don't delete. `.vscode/` is fully ignored per repo choice; don't add it.
- **Line endings enforced**: `.gitattributes` normalizes to LF; `*.ps1`/`*.bat`/`*.cmd` are CRLF. Don't fight it.
- **Only endpoint** is `GET /weatherforecast` in `src/DailySpur.Api/Program.cs:22` — see `src/DailySpur.Api/DailySpur.Api.http:3` for manual test.
- **No codegen yet** but `.gitattributes` already hides `*.g.dart`/`*.freezed.dart`/`*.gr.dart` + `**/lib/generated/**` as `linguist-generated` — expect them when models added.
