# offline_alert

Flutter client for Offline Message Alert. Setup and running: see
[docs/03-setup-guide.md](../docs/03-setup-guide.md).

## Layout

```
lib/
├── main.dart                 # calls bootstrap()
├── app/                      # bootstrap, root widget, build-time config
├── core/
│   ├── di/                   # injection.dart + generated injection.config.dart
│   ├── bloc/                 # Resource / ActionStatus
│   ├── network/              # ApiClient, ApiException
│   ├── router/               # AppRouter (go_router)
│   └── ...                   # notifications, sms, device, widgets
└── features/<feature>/
    ├── domain/
    │   ├── models/
    │   ├── repository/       # abstract contracts (XRepository)
    │   └── services/         # implementations (XService)
    ├── logic/<name>_cubit/   # <name>_cubit.dart + part '<name>_state.dart'
    ├── screens/
    ├── widgets/
    └── index.dart            # barrel; each folder has one
```

## Dependency injection

get_it + injectable. Annotate, then regenerate the config:

```sh
dart run build_runner build
```

- Services: `@LazySingleton(as: XRepository) class XService implements XRepository`.
  Code depends on the contract, so tests mock `XRepository`.
- Cubits: `@injectable` (a new instance per screen). Runtime arguments are
  `@factoryParam`, e.g. `getIt<AlertDetailCubit>(param1: alertId)`.
- Objects the graph does not build (the Supabase auth client) are declared in
  `core/di/register_module.dart`.
- Async setup that must finish before `runApp` uses `@preResolve` with a
  `@factoryMethod` (see `AlertReminders.create`).

`injection.config.dart` is committed; regenerate it whenever an annotation or
constructor changes.
