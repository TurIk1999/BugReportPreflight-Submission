# Bug Report Preflight — Element X iOS

Тестовое задание: **Senior iOS Developer**.

Задача — добавить экран «предварительного отчёта» для багрепорта в приложение [Element X iOS](https://github.com/element-hq/element-x-ios), устойчивый к будущим изменениям Rust SDK / FFI.

---

## Что реализовано

| # | Требование | Статус |
|---|---|---|
| 1 | Settings → «Report a problem» → Bug Report Preflight screen | ✅ |
| 2 | Шаблон: Summary / Steps / Expected / Actual + Diagnostics | ✅ |
| 3 | Copy to Clipboard + Share (iOS Share Sheet) | ✅ |
| 4 | `DiagnosticsProviding` protocol + `SystemDiagnosticsProvider` (async, cancellable, UI-independent) | ✅ |
| 5 | `DiagnosticsRedactor` — редакция email, URL, Matrix ID | ✅ |
| 6 | Unit-тесты: редакция (5) + формат отчёта (5) = **10 тестов** | ✅ |

### Ограничения (соблюдены)

- Не требуется реальный логин / homeserver.
- Rust SDK / FFI **не затронуты** — изоляция через протокол `DiagnosticsProviding`.

---

## Структура файлов

```
├── ElementX/
│   └── Sources/
│       ├── FlowCoordinators/
│       │   └── SettingsFlowCoordinator.swift          # MODIFIED — .bugReport → preflight screen
│       ├── Other/
│       │   └── AccessibilityIdentifiers.swift          # MODIFIED — +BugReportPreflightScreen IDs
│       ├── Screens/
│       │   ├── BugReportPreflightScreen/               # NEW — full MVVM-C screen
│       │   │   ├── BugReportPreflightScreenCoordinator.swift
│       │   │   ├── BugReportPreflightScreenModels.swift
│       │   │   ├── BugReportPreflightScreenViewModel.swift
│       │   │   ├── BugReportPreflightScreenViewModelProtocol.swift
│       │   │   └── View/
│       │   │       └── BugReportPreflightScreen.swift
│       │   └── Settings/SettingsScreen/                # MODIFIED — routing + isBugReportServiceEnabled guard
│       │       ├── SettingsScreenCoordinator.swift
│       │       ├── SettingsScreenModels.swift
│       │       ├── SettingsScreenViewModel.swift
│       │       └── View/
│       │           └── SettingsScreen.swift
│       └── Services/
│           └── Diagnostics/                            # NEW — reusable diagnostics layer
│               ├── DiagnosticsProviding.swift           # Protocol + DiagnosticsReport
│               ├── DiagnosticsRedactor.swift            # Email/URL/MatrixID redaction
│               └── SystemDiagnosticsProvider.swift      # Concrete implementation
└── UnitTests/
    └── Sources/
        └── BugReportPreflightTests.swift               # NEW — 10 unit tests
```

**Новых файлов: 11** | **Модифицированных: 5** | Итого: **16 файлов** (15 Swift + README)

---

## Архитектура

### MVVM-Coordinator (паттерн проекта)

```
Settings → SettingsFlowCoordinator
              ↓ .bugReport
         BugReportPreflightScreenCoordinator
              ↓ creates
         BugReportPreflightScreenViewModel ← DiagnosticsProviding (protocol)
              ↓ binds
         BugReportPreflightScreen (SwiftUI View)
```

### Изоляция SDK/FFI

```
┌──────────────────────────┐
│   BugReportPreflight VM  │  ← Зависит ТОЛЬКО от протокола
│          ↓               │
│  DiagnosticsProviding    │  ← Абстракция (protocol)
│          ↓               │
│  SystemDiagnosticsProvider│  ← Текущая реализация (Bundle + UIDevice)
│                          │
│  [Future: RustSDKProvider]│  ← Будущая реализация (Rust SDK/FFI)
└──────────────────────────┘
```

Замена провайдера на SDK-версию: **одна строка** в `SettingsFlowCoordinator.presentBugReportPreflightScreen()`.

### Async + Cancellation

- `collectDiagnostics() async` — кооперативная отмена.
- `@CancellableTask` property wrapper — автоматическая отмена при `= nil`.
- `.onDisappear` → `.viewDisappeared` → `diagnosticsTask = nil` — покрывает swipe-back, pop, dismiss.

### Privacy (Redactor)

`DiagnosticsRedactor.redact(_:)` заменяет на `[REDACTED]`:
- Email: `alice@example.com`
- URL: `https://matrix.org/path`
- Matrix ID: `@user:server.tld`

---

## Тесты

| Класс | Тест | Что проверяет |
|---|---|---|
| `DiagnosticsRedactorTests` | `testRedactsEmailAddresses` | Email → `[REDACTED]` |
| | `testRedactsURLs` | URL → `[REDACTED]` |
| | `testRedactsMatrixIDs` | Matrix ID → `[REDACTED]` |
| | `testRedactsMultiplePatternsAtOnce` | Все паттерны в одном тексте |
| | `testPreservesInnocentText` | Безопасный текст не затрагивается |
| `BugReportPreflightViewModelTests` | `testDeterministicReportFormat` | Одинаковый ввод → одинаковый выход |
| | `testEmptyFieldsShowPlaceholder` | Пустые поля → `(not provided)` |
| | `testDiagnosticsAreRedacted` | Redactor применяется к диагностике |
| | `testInitialStateShowsLoadingDiagnostics` | Начальное состояние: loading |
| | `testViewDisappearedCancelsDiagnostics` | Отмена async-задачи при уходе |

- Используется `deferFulfillment` (стандартный паттерн проекта) — **нет flaky `Task.sleep`**.
- `StubDiagnosticsProvider` и `SlowDiagnosticsProvider` — полная изоляция от системы.

---

## Паттерны проекта Element X iOS

Все файлы следуют стандартам [element-hq/element-x-ios](https://github.com/element-hq/element-x-ios):

- `StateStoreViewModelV2` + `BindableState`
- `@CancellableTask` для управления async-задачами
- `CoordinatorProtocol` + `toPresentable() → AnyView`
- `AccessibilityIdentifiers` (7 новых A11y ID)
- `L10n` ключи для локализованных строк
- `TestablePreview` для SwiftUI Preview
- `// sourcery: AutoMockable` для генерации моков
- Copyright headers: `AGPL-3.0-only OR LicenseRef-Element-Commercial`
