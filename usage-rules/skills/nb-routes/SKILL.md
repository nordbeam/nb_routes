---
name: nb-routes
description: "Generate, configure, migrate, diagnose, and verify nb_routes JavaScript/TypeScript helpers from Phoenix routers, including rich, form, resource, and Vite+ integration modes."
---

# NbRoutes

Use this skill for `nb_routes` route-helper generation, TypeScript
declarations, classic/simple or rich/method-aware output, form method
spoofing, resource-style files, module formats, filtering, and integration
with Inertia or Vite.

## Discover the target release

- Inspect the target app's `mix.exs`, `mix.lock`, Phoenix router, config,
  assets manifest/lockfile, generated routes, TypeScript config, and Vite+
  plugin config.
- Read the selected README, `lib/mix/tasks/nb_routes.gen.ex`,
  `NbRoutes.Configuration`, and generator source before changing options.
- This release exposes a Mix generator rather than an Igniter installer;
  integrations remain optional.

## Install and generate

- Add the version/source selected by the app, run `mix deps.get`, and invoke
  `mix nb_routes.gen`. Pass `--router` when automatic detection is ambiguous.
- Use only options exposed by the selected task. Classic mode emits one file;
  rich mode can add method/form variants; resource mode emits per-resource
  modules and indexes.
- Treat generated JavaScript, TypeScript, and declaration files as artifacts.

## Integrate and verify

- In simple mode helpers return URL strings. In rich mode confirm the generated
  result type before passing `{url, method}` objects to client code.
- Add the `nb_vite` watcher only after verifying its npm subpath export,
  router glob, and `mix nb_routes.gen` command.
- Compare generated output and declarations after mode changes. Run
  `mix compile`, `mix nb_routes.gen`, relevant runtime tests, and Vite+ checks
  when the app uses them.
