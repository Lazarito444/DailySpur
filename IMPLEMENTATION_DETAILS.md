# DailySpur — Implementation Details (Final Plan v4.4)

> **Status:** Locked plan — execution blueprint for modular monolith + Flutter. No code drift without explicit approval.

## 1. Product Locked

**Job:** Lifelong learner, time-poor, wants personalization. Gap: `too much time / no personalization`.

**Loop `60s`, 1 answer/day:** `Push 08:00 local (custom) + 17:00-20:00 nudge if unanswered → MCQ4 or TF → instant correct + explanation 2-3s + source → streak/rating/coins → share-card opt-in`.

**Streak:** `Wrong != loss`. Loss only on **missed calendar day `00:00` in `User.TimeZoneId` IANA**. Freeze `1 per 7d`, `cap 1 free / 3 pro`, `bank max 5`, **purchasable with coins**.

**Rating:** Per-subject hidden `800-2000` (`<1200 Beginner 1000 / 1200-1600 Intermediate 1400 / >1600 Expert 1700` initial). Apply: `correct +15,+25,+35,+50…` / `wrong|missed -10,-25,-50…` + `jitter 1-9` by `Difficulty`, clamp.

**Coins:** `Beginner 10 / Intermediate 15 / Expert 20 + jitter 1-9` on correct only, `0` on wrong. `1 freeze = 100 coins`. `Rewarded interstitial 1/day = +10 coins` (opt-in, allowed for `pro` as well). Free tier `Banner(ResultScreen) + 1/day forced interstitial`; `pro` = `0 forced` but rewarded allowed.

**Catalog:** Curated `12` (`Tech/CS, Science, History, Finance, Health, Philosophy, Arts, Geography, Language, Math, Psychology, Sports`), **MVP 6** first; `3 free / 10 pro` no swap limit.

**Content:** `IQuestionGenerator` abstraction (`OpenAI|Gemini|Local` via `LLM:Provider` env/user-secrets) → `IQuestionJudge` `<0.8 reject` → human spot-check. `Status Draft→Reviewed→Published`, `ScheduledFor DateOnly`.

**Accounts day-1, online-only MVP, private + share-card `RepaintBoundary → png` in MVP.**

## 2. Architecture — Modular Monolith (Host + 4-Layer Modules)

> Target structure per your example:
> ```
> DailySpur.Host/              # Single Deployable Entry Point (Monolith host)
> Modules/
> ├── Catalog/  ├── Catalog.Api / Domain / Application / Infrastructure
> ├── Spurs/    ├── Spurs.Api   / Domain / Application / Infrastructure
> ├── Progress/ ├── Progress.Api/ Domain / Application / Infrastructure
> ├── Billing/  ├── Billing.Api / Domain / Application / Infrastructure
> ├── Identity/ ├── Identity.Api/ Domain / Application / Infrastructure
> └── Notifications/ ├── Notifications.Api / Domain / Application / Infrastructure
> ```

```
Flutter (riverpod/go_router/dio + slang en/es) --HTTPS--> DailySpur.Host (thin host, Program.cs:1) — Shop.Host analogue
                                                          |
                           DailySpur.SharedKernel (Result, Error[MessageKey], IHasId<T>, IAuditable, ISoftDeletable[DeletedAtUtc], IClock, ISpecification<T> with Criteria/OrderBy/Paging/Selector, SpecificationEvaluator, Guid v7)
                                                          |
              Modules/Catalog.Api/Domain/Application/Infrastructure (Subject)
              Modules/Spurs.Api/Domain/Application/Infrastructure (Spur, QuestionType, IQuestionGenerator)
              Modules/Progress.Api/Domain/Application/Infrastructure (Rating, UserSubjectProgress, Attempt)
              Modules/Billing.Api/Domain/Application/Infrastructure (Wallet, Coins, LedgerEntry)
              Modules/Identity.Api/Domain/Application/Infrastructure (User)
              Modules/Notifications.Api/Domain/Application/Infrastructure (TickerQ crons)
                                                          |
              DailySpur.Infrastructure (shared AppDbContext schemas, Redis ICache cache-aside, TickerQ 2.2.0) + Postgres 10 + Redis + FCM + LLM
```

*   **Dependency rule per module:** `Api → Application → Domain ← Infrastructure` (each `Domain` → `SharedKernel`, `Application` → `Domain`, `Infrastructure` → `Application` + EF/Redis). `Host` references all `*.Api` + `*.Infrastructure` + `SharedKernel`. No `ModuleA → ModuleB`, only `IDomainEvent`.
*   **Single TFM** `net10.0` via `Directory.Build.props:4` and **CPM** via `Directory.Packages.props:9` — all `csproj` cleaned to inherit `TargetFramework/ImplicitUsings/Nullable` centrally (e.g., `src/DailySpur.SharedKernel/DailySpur.SharedKernel.csproj:1` empty `<Project Sdk>`).
*   **`DailySpur.slnx:9`** lists 27 projects under `/src/` + `/src/Modules/` (XML `slnx`, flat `/src/` folder for build).

## 3. DDD Tactical — Rich, Explicit Types

*   **Identifiers:** `Guid` only (`Guid.CreateVersion7()` everywhere — time-ordered, no v4). Removed `StrongIds.cs`, `ValueObject.cs`, `Entity.cs`.
*   **Bases:** `AggregateRoot<TId>: IHasId<TId>, IAuditable(CreatedAtUtc/UpdatedAtUtc/Touch()), ISoftDeletable(DeletedAtUtc only, SoftDelete()/Restore(), check `DeletedAtUtc is not null`)` — `IsDeleted` removed, no bool column. Previous `Entity<T>` replaced.
*   **Result:** Custom `Result` + `Result<T>` (`SharedKernel/Result.cs:1`) with `Failure/Success`, `Bind/BindAsync/Map`, `Match` (both branches), **explicit** `operator Result(Error)` / `operator Result<T>(T)` (no implicit). `Errors.cs:1` central `MessageKey` (`errors.rating.outOfRange` etc.) for `en+es`.
*   **ValueObjects:** `Rating.cs:1` and `Coins.cs:1` are `IEquatable<T>` plain classes (no `ValueObject` base), `Rating.Apply(...)` with jitter, `Coins.Add/Subtract`.
*   **IUnitOfWork:** `CommitAsync` + `RollbackAsync` (`SharedKernel/IUnitOfWork.cs:1`), `AppDbContext.cs:17` implements `CommitAsync → base.SaveChangesAsync`, `RollbackAsync → ChangeTracker.Clear()`.
*   **Rich aggregates** (`Catalog/Subject.cs:8 AggregateRoot<Guid>`, `Spurs/Spur.cs:8`, `Progress/UserSubjectProgress.cs:9` (`RecordAnswer → Result<Attempt>`), `Billing/Wallet.cs:8` (idempotent `Earn` per `SpurId`), `Identity/User.cs:8` (timezone validation)) — no setters, invariants in `Create`.

## 4. Specification — Full

**`ISpecification.cs:1`** now includes:

*   **Criteria** `Expression<Func<T,bool>>?` (`Where`)
*   **Selector** `ISpecification<T,TResult>` (`Select` projection)
*   **OrderBy** `IReadOnlyList<OrderByExpression<T>>(KeySelector, OrderType Asc/Desc)` — `OrderBy`, `OrderByDescending`, multiple `order by name ASC, lastname DESC`
*   **Paging** `Skip/Take` + `IsPagingEnabled` (`ApplyPaging(skip,take)`, `ApplyPagingByPage(page,pageSize)`)
*   `IsSatisfiedBy(T)` + `ToExpression()` compat + `And/Or/Not` merging `Criteria`/`OrderBy`/`Paging`.

**`SpecificationEvaluator.cs:1`** `GetQuery<T>(IQueryable<T>, ISpecification<T>)` and `GetQuery<T,TResult>(…, ISpecification<T,TResult>)` apply `Where → OrderBy/ThenBy → Skip/Take → Select` (ordering before paging before projection). Supports EF Core + in-memory.

**Examples** (`Catalog/Domain/Specifications/`): `SubjectBySlugSpec` (criteria), `SubjectsOrderedSpec` / `ProSubjectsOrderedByNameSpec` (order), `PagedSubjectsSpec` (paging + ordering), `SubjectNameProjectionSpec` / `SubjectNamesOnlySpec` (criteria + order + paging + selector → `SubjectNameDto`). `FreeSubjectLimitSpec.cs:9` migrated to `Where(ids => count <=…)`.

## 5. i18n — `en+es`

*   Backend: `AddLocalization` + `UseRequestLocalization` `en` default + `es` (`Program.cs:9`), `Resources/SharedResource.{en|es}.resx:1` (27 keys, `errors.*`, `subjects.*`).
*   Mobile: **slang 4.19.0 + slang_flutter** (`pubspec.yaml:14`), `slang.yaml:1` (`base_locale: en`, `input_directory: lib/i18n`), `lib/i18n/en.i18n.json:1` / `es.i18n.json:1` → `dart run slang` → `strings.g.dart:1` (`AppLocale.en/es`, `t.*`), `DailySpurApp:1` wrapped `TranslationProvider → Builder → MaterialApp(locale: TranslationProvider.of(context).flutterLocale, supportedLocales: AppLocaleUtils.supportedLocales)` with `flutter_localizations sdk:flutter`.

## 6. Infrastructure

*   **Postgres** `Npgsql.EntityFrameworkCore.PostgreSQL` + single `AppDbContext` schemas, migrations via `EF Tools` (PrivateAssets).
*   **Redis** `StackExchangeRedis` cache-aside `today:{user}:{date} TTL24h`, `wallet:{user} TTL5m`; fallback `DistributedMemoryCache` if no connection string.
*   **TickerQ** crons `TickerJobs.cs:1` `*/15 08:00 scan`, `0 17 nudge`, `0 2 generation UTC`, `0 1 decay UTC`.
*   Secrets via `user-secrets`/env (never `appsettings.*.json` per `.gitignore:100`).

## 7. API Contract (post-`/weatherforecast`)

```
POST /auth/register {email,password,timezone,notificationTime?}
POST /auth/login | POST /auth/refresh
GET  /subjects | GET/POST /me/subjects (FreeLimitSpec) | PATCH /me/preferences
GET  /spurs/today (204 if answered, Redis) | POST /spurs/{id}/answer {chosenIndex} → {isCorrect, explanation, ratingBefore/After, coinsEarned 0|10/15/20+jitter, walletBalance, streak, freeze}
GET  /me/history?subjectId&page&pageSize (Paged spec) | GET /me/streak | POST /me/device-token
GET  /me/wallet | POST /me/freeze/purchase {qty} 422 INSUFFICIENT_COINS | POST /me/ads/rewarded {requestId} +10 1/day | GET /me/entitlement
POST /admin/spurs/generate | PATCH /admin/spurs/{id}/review
```

`ProblemDetails {code, messageKey, message(localized)}` via `Accept-Language`, paginated, rate-limited auth.

## 8. Mobile (`package:dailyspur` `lib/main.dart:1`)

`lib/i18n/strings.g.dart` + `app_en/es.arb` removed, `l10n.yaml` removed, `pubspec.yaml` `sdk ">=3.12.0 <4.0.0"` for current `Dart 3.12.2`, strict `analysis_options.yaml:14` (`flutter analyze` passes).

## 9. Verify

`dotnet build DailySpur.slnx` 0 errors, `flutter analyze` 0 issues (NU1903 transitive vulns only warning). `csproj` cleanup keeps `EnforceCodeStyleInBuild` + `GenerateDocumentationFile`.

## 10. Next to Execute

**Phase 0** done (this scaffold). **Phase 1:** `Subjects/Spurs/Progress/Billing` endpoints + `SpecificationEvaluator` wiring + `Wallet` ledger + `Attempt` persistence + Flutter today/result/share. **Phase 2:** LLM judge + TickerQ jobs + FCM. **Phase 3:** Billing gate + ads.

## 11. Decisions & Tradeoffs

*   **Modular monolith vs microservices:** Monolith chosen for single `AppDbContext` transactions and simple `TickerQ` scheduling; microservices would add ops overhead not justified for MVP.
*   **Custom Result/Spec vs libraries (FluentResults/Ardalis):** Custom keeps `MessageKey` i18n and explicit control, avoids transitive version pinning per `CentralPackageTransitivePinningEnabled`.
*   **Guid v7 vs v4:** v7 time-ordered, no privacy concern, improves PG index locality vs random v4.
*   **`DeletedAtUtc` only vs `IsDeleted` flag:** Single nullable column is source of truth; `DeletedAtUtc is not null` check avoids syncing two columns; query filters use `Where(e => e.DeletedAtUtc == null)`.
*   **`en+es` only:** Slang YAMLs generated to `strings.g.dart`; `en` is `base_locale`, `es` is complete. Adding `fr` later is adding `fr.i18n.json` + `dart run slang`.
*   **Slang vs `flutter gen-l10n`:** Slang gives type-safe `t.*` with `AppLocale` enum and `TranslationProvider` rebuild, fewer `arb` plural edge cases; `gen-l10n` required `l10n.yaml` and `GlobalMaterialLocalizations`.
*   **TickerQ vs Hangfire/Quartz:** TickerQ 2.2.0 is lightweight, PG-backed, `Cron */15` bucket sufficient for per-user `08:00` local scan; Hangfire would require separate storage.
*   **Explicit `Result` operators:** `explicit operator` forces `Result<T>.Success(value)` call, making success/failure intent visible vs implicit `Error → Result` hidden conversions.
*   **Slang rewarded ad for `pro`:** Allowed because coins are gameplay, not forced interstitial; `pro` retains `0 forced` but can still earn `10` via opt-in.

## 12. File Index (Key Paths) — New Host + 4-Layer Layout

*   `DailySpur.slnx:9` — solution (XML slnx, 27 projects)
*   `Directory.Build.props:4` — `net10.0`, `Nullable`, `EnforceCodeStyleInBuild`
*   `Directory.Packages.props:9` — CPM
*   `src/DailySpur.Host/Program.cs:1`, `Resources/SharedResource.{en|es}.resx:1`, `Properties/launchSettings.json` (Host = Shop.Host)
*   `src/DailySpur.SharedKernel/` — `Result.cs:1`, `Error.cs:1`, `Errors.cs:1`, `Difficulty.cs:1`, `IHasId.cs:1`, `IAuditable.cs:1`, `ISoftDeletable.cs:1` (`DeletedAtUtc` only), `AggregateRoot.cs:1`, `IClock.cs:1`, `ISpecification.cs:1` (Criteria/OrderBy/Paging/Selector), `SpecificationEvaluator.cs:1`
*   `src/DailySpur.Infrastructure/` — `Persistence/AppDbContext.cs:17` (`CommitAsync`/`RollbackAsync`), `Caching/RedisCache.cs:1`
*   `src/Modules/Catalog/` — `Domain/Subject.cs:8`, `Domain/Specifications/FreeSubjectLimitSpec.cs:9` + `SubjectBySlugSpec`, `SubjectsOrderedSpec`, `PagedSubjectsSpec`, `SubjectProjectionSpec` (all demo OrderBy/Paging/Selector)
*   `src/Modules/Spurs/` — `Domain/Spur.cs:8`, `Domain/QuestionType.cs`, `Application/Ports/IQuestionGenerator.cs:1`
*   `src/Modules/Progress/` — `Domain/Rating.cs:1`, `Domain/UserSubjectProgress.cs:9`, `Domain/Attempt.cs:8`
*   `src/Modules/Billing/` — `Domain/Wallet.cs:8`, `Domain/Coins.cs:1`, `Domain/LedgerEntry.cs:1`
*   `src/Modules/Identity/` — `Domain/User.cs:8`
*   `src/Modules/Notifications/` — `Application/TickerJobs.cs:1`
*   Each module has 4 projects: `Api` (`DependencyInjection.cs` → `AddCatalog()` etc., `Microsoft.Extensions.DependencyInjection.Abstractions`), `Domain` (→ `SharedKernel`), `Application` (→ `Domain`), `Infrastructure` (→ `Application` + `Npgsql`/`TickerQ`/`StackExchange.Redis`)
*   `src/dailyspur_mobile/` — `pubspec.yaml:14` (`slang ^4.19.0`, `slang_flutter`, `flutter_localizations`), `slang.yaml:1`, `lib/i18n/en.i18n.json:1`, `lib/i18n/strings.g.dart:1`, `lib/daily_spur_app.dart:1` (`TranslationProvider`)
