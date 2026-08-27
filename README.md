# DailySpur

> Daily Knowledge Prompt & Quiz — one customized question or fact per day in a subject area you want to stay sharp on.

DailySpur delivers a 60-second daily loop: push notification → MCQ/TF → instant feedback with explanation and source → streak, rating, and coins. Designed for lifelong learners who are time-poor and want personalization.

## How It Works

- **One spur per day** — push at `08:00` local time (custom per user), nudge `17:00–20:00` if unanswered
- **Answer** — 4-choice MCQ or True/False → instant correctness + 2–3s explanation + source link
- **Progression** — per-subject hidden rating `800–2000`, streak (calendar-day based on `User.TimeZoneId`), coin wallet
- **Share** — opt-in share card (`RepaintBoundary → PNG`)
- **Catalog** — 12 curated subjects (Tech/CS, Science, History, Finance, Health, Philosophy, Arts, Geography, Language, Math, Psychology, Sports); MVP ships 6, `3 free / 10 pro`

Detailed product and architecture decisions: [`IMPLEMENTATION_DETAILS.md`](./IMPLEMENTATION_DETAILS.md) (locked plan v4.4).

## Tech Stack

| Layer | Stack |
|-------|-------|
| API | ASP.NET Core Minimal API, `net10.0`, `Microsoft.AspNetCore.OpenApi` 10.0.6 |
| Architecture | Modular monolith — `DailySpur.Host` + 6 modules × 4 layers (`Api` / `Domain` / `Application` / `Infrastructure`) + `SharedKernel` |
| Data | PostgreSQL (`Npgsql.EntityFrameworkCore.PostgreSQL`), single `AppDbContext` with schemas, EF Core migrations |
| Cache | Redis (`StackExchange.Redis`) cache-aside, fallback `DistributedMemoryCache` |
| Jobs | TickerQ 2.2.0 (cron: `08:00` scan every 15m, `17:00` nudge, `02:00` generation UTC, `01:00` decay UTC) |
| Mobile | Flutter 3.44.4 / Dart 3.12.2, `package:dailyspur` |
| i18n | Backend `SharedResource.{en,es}.resx` + mobile `slang` 4.19.0 (`en`/`es`) |
| Build | `Directory.Build.props` (single TFM `net10.0`, `Nullable`+`ImplicitUsings`), `Directory.Packages.props` (CPM) |

> Current code is scaffold stage: `GET /weatherforecast` (`src/DailySpur.Api/Program.cs:22`) and Flutter `Hello World` (`src/dailyspur_mobile/lib/daily_spur_app.dart:5`). The modular host and 24+ projects described in `IMPLEMENTATION_DETAILS.md` are the target layout — check `src/` for implementation progress.

## Project Structure

```
DailySpur.slnx                          # XML slnx format (not .sln)
Directory.Build.props                   # net10.0, Nullable, ImplicitUsings, EnforceCodeStyleInBuild
Directory.Packages.props                # Central Package Management (CPM)
src/
├── DailySpur.Api/                      # Current Minimal API host (placeholder, will be superseded by DailySpur.Host)
│   ├── Program.cs                      # GET /weatherforecast
│   ├── DailySpur.Api.http              # Manual endpoint test
│   └── Properties/launchSettings.json  # http://localhost:5205 https://localhost:7240
├── DailySpur.Host/                     # Target monolith host (Program.cs:1) — see IMPLEMENTATION_DETAILS.md
├── DailySpur.SharedKernel/             # Result, Error, AggregateRoot, ISpecification, etc.
├── DailySpur.Infrastructure/           # AppDbContext, RedisCache
├── Modules/
│   ├── Catalog/       # Subject — Api / Domain / Application / Infrastructure
│   ├── Spurs/         # Spur, QuestionType, IQuestionGenerator
│   ├── Progress/      # Rating, UserSubjectProgress, Attempt
│   ├── Billing/       # Wallet, Coins, LedgerEntry
│   ├── Identity/      # User
│   └── Notifications/ # TickerQ jobs
└── dailyspur_mobile/                   # Flutter app (folder dailyspur_mobile, pubspec name: dailyspur)
    ├── lib/main.dart                   # launchDailySpurApp() -> DailySpurApp
    ├── lib/daily_spur_app.dart         # MaterialApp, deepPurple seed
    ├── lib/i18n/                       # slang en.i18n.json / es.i18n.json -> strings.g.dart
    ├── pubspec.yaml
    └── analysis_options.yaml           # page_width 200, strict lints
```

Module dependency rule: `Api → Application → Domain ← Infrastructure`; `Host` references all `*.Api` + `*.Infrastructure` + `SharedKernel`. No cross-module references, only `IDomainEvent`. Identifiers are `Guid` v7 (`Guid.CreateVersion7()`), soft-delete via `DeletedAtUtc` only.

## Prerequisites

- **.NET SDK 10.0.202+** (`net10.0`) — `dotnet --version`
- **Flutter 3.44.x / Dart 3.13+** — verified `3.44.4` / `3.12.2` — `flutter --version`
- **PostgreSQL 10+** and **Redis** (for full host — not required for current scaffold)
- Optional: `user-secrets`, `FCM` credentials, LLM provider key (`LLM:Provider` = `OpenAI|Gemini|Local`)

## Quick Start

```bash
# Clone
git clone https://github.com/Lazarito444/DailySpur.git
cd DailySpur

# API — from repo root (note: DailySpur.slnx, not .sln)
dotnet build DailySpur.slnx
dotnet run --project src/DailySpur.Api              # http://localhost:5205 https://localhost:7240
# or with hot reload
dotnet watch --project src/DailySpur.Api

# Verify OpenAPI (Development only)
# http://localhost:5205/openapi/v1.json

# Mobile — from src/dailyspur_mobile
cd src/dailyspur_mobile
flutter pub get
flutter analyze
flutter test              # no tests yet — harness ready
flutter run
dart format --set-exit-if-changed .
```

Single-suite verification (CI-equivalent):

```bash
dotnet build DailySpur.slnx
flutter analyze        # run inside src/dailyspur_mobile
```

## Configuration

| File | Purpose |
|------|---------|
| `src/DailySpur.Api/appsettings.json` | Base logging + `AllowedHosts` |
| `src/DailySpur.Host/appsettings.Development.json` | Dev overrides (if host present) |
| `secrets.json` / env vars | Secrets — **never** `appsettings.*.json` |

> `**/appsettings.*.json` is gitignored after the initial commit (`.gitignore:100` — only `appsettings.json` is whitelisted). `appsettings.Development.json` is tracked but now ignored; force-add with `git add -f` if you must edit it. Use `dotnet user-secrets` or env vars for `ConnectionStrings`, `LLM:Provider`, `FCM`, etc.

## API

Current scaffold:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/weatherforecast` | Sample 5-day forecast — `src/DailySpur.Api/Program.cs:22`, test via `src/DailySpur.Api/DailySpur.Api.http:3` |

Planned contract (post-scaffold, see `IMPLEMENTATION_DETAILS.md:7`):

```
POST /auth/register {email,password,timezone,notificationTime?}
POST /auth/login | POST /auth/refresh
GET  /subjects | GET/POST /me/subjects | PATCH /me/preferences
GET  /spurs/today (204 if answered, Redis) | POST /spurs/{id}/answer {chosenIndex}
GET  /me/history?subjectId&page&pageSize | GET /me/streak | POST /me/device-token
GET  /me/wallet | POST /me/freeze/purchase | POST /me/ads/rewarded | GET /me/entitlement
POST /admin/spurs/generate | PATCH /admin/spurs/{id}/review
```

All responses use `ProblemDetails {code, messageKey, message}` localized via `Accept-Language`, paginated, and rate-limited on auth.

## Mobile

- **Import path**: `pubspec.yaml` `name: dailyspur` ≠ folder `dailyspur_mobile`. Always `import 'package:dailyspur/...'` — never `package:dailyspur_mobile/...` (`lib/main.dart:1`).
- **Lint is strict**: `analysis_options.yaml` enforces `page_width: 200`, `trailing_commas: preserve`, and ~25 lints (`always_use_package_imports`, `avoid_relative_lib_imports`, `use_super_parameters`, etc.). Run `flutter analyze` before pushing.
- **i18n**: `slang` with `slang.yaml` (`base_locale: en`, `input_directory: lib/i18n`) → `dart run slang` → `lib/i18n/strings.g.dart` (`AppLocale.en/es`, `t.*`). App is wrapped in `TranslationProvider → Builder → MaterialApp(locale: TranslationProvider.of(context).flutterLocale)`.
- **`pubspec.lock` is committed** (app, not package) — do not delete. `.vscode/` is fully ignored.

## Game Rules (Summary)

- **Streak**: wrong answer ≠ loss. Loss only on missed calendar day `00:00` in `User.TimeZoneId` (IANA). Freeze `1 per 7d`, cap `1 free / 3 pro`, bank max `5`, purchasable with coins (`1 freeze = 100 coins`).
- **Rating**: per-subject `800–2000` (Beginner `<1200` start `1000`, Intermediate `1200–1600` start `1400`, Expert `>1600` start `1700`). Correct `+15/+25/+35/+50…`, wrong/missed `-10/-25/-50…` + jitter `1–9` by `Difficulty`.
- **Coins**: `10/15/20 + jitter 1–9` on correct only, `0` on wrong. Rewarded interstitial `1/day = +10` (opt-in, allowed for `pro`).
- **Ads**: free tier `Banner(ResultScreen) + 1/day forced interstitial`; `pro` = `0 forced` but rewarded still allowed.

## Roadmap

- **Phase 0** — Scaffold (done): `DailySpur.slnx`, `Directory.*.props`, `DailySpur.Api` placeholder, Flutter `Hello World`, `.editorconfig`/`.gitattributes`/`.gitignore`
- **Phase 1** — Core: `Subjects/Spurs/Progress/Billing` endpoints, `SpecificationEvaluator`, `Wallet` ledger, `Attempt` persistence, Flutter today/result/share
- **Phase 2** — LLM: `IQuestionGenerator` + `IQuestionJudge` (`<0.8` reject), TickerQ jobs, FCM push
- **Phase 3** — Monetization: billing gate, ads, rewarded flow

## Development Notes

- **Solution file**: `DailySpur.slnx` (XML format). All `dotnet` commands must reference `DailySpur.slnx`, not `DailySpur.sln`.
- **Line endings**: `.gitattributes` normalizes to LF; `*.ps1`/`*.bat`/`*.cmd` are CRLF.
- **Code style**: `.editorconfig` enforces 4-space indent, `file_scoped` namespaces, CRLF for `*.cs`, etc. `EnforceCodeStyleInBuild` + `GenerateDocumentationFile` are on.
- **Generated files**: `*.g.dart`/`*.freezed.dart`/`*.gr.dart` + `**/lib/generated/**` are marked `linguist-generated` in `.gitattributes` — expect them when models are added.
- **Central versioning**: `Directory.Packages.props:9` enables `ManagePackageVersionsCentrally` + `CentralPackageTransitivePinningEnabled`; keep `csproj` files inheriting `TargetFramework`/`ImplicitUsings`/`Nullable`.

## License

No license file yet. All rights reserved until one is added.

---

Built with `net10.0` + Flutter. See `AGENTS.md` for agent-specific gotchas and `IMPLEMENTATION_DETAILS.md` for the full execution blueprint.
