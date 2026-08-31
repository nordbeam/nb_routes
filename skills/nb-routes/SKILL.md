---
name: nb-routes
description: "Generate, configure, migrate, diagnose, and verify nb_routes JavaScript/TypeScript helpers from Phoenix routers, including rich, form, resource, and Vite+ integration modes."
---

# NbRoutes

Use this skill for `nb_routes` route-helper generation, TypeScript declarations, classic/simple or rich/method-aware output, form method spoofing, resource-style files, module formats, filtering, and integration with Inertia or Vite.

## Discover the target release

- Inspect the target app's `mix.exs`, `mix.lock`, Phoenix router(s), `config/config.exs`, `assets/package.json`/lockfile, existing generated routes, TypeScript config, and Vite+/Vite plugin config. Read the selected `README.md`, `lib/mix/tasks/nb_routes.gen.ex`, `NbRoutes.Configuration`, and generator source; docs may describe features newer than the locked package.
- The generator is a Mix task rather than an Igniter installer in current releases. Do not add `nb_vite`, `nb_inertia`, or `nb_ts` just to generate routes; integrations remain optional.

## Install and generate

- Add the version/source selected by the app, run `mix deps.get`, and invoke `mix nb_routes.gen`. Use an explicit `--router` when auto-detection is ambiguous.
- Choose only options present in the target task/config: classic output may use `--output`/module type/filtering, rich mode may enable method variants and forms, and resource mode may use `--style resource`, `--output-dir`, grouping, index, or LiveView switches. Confirm names and defaults before copying examples.
- Treat output as generated code. Configure output paths and naming in `config/config.exs` where supported, and do not hand-edit generated `.js`, `.ts`, or `.d.ts` files.

## Implement and configure

- In simple/classic mode, helpers return URL strings. In a release that supports rich mode, helpers can return `{url, method}` values and method variants; form helpers can return HTML form attributes with method spoofing. Only pass a route object to Inertia/client code when the generated type/output confirms that shape.
- Resource mode, when detected, emits per-resource TypeScript modules and a barrel/runtime helper. Import the actual generated names and inspect parameter signatures; do not assume every route is CRUD or that `users.update.patch` exists.
- Use query/merge-query, anchor, URL-helper, camel-case, compact, include, and exclude options only as documented by the selected version. Configure `nb_vite` auto-regeneration only after verifying the npm subpath export and command. In Vite+ projects import `defineConfig` and `lazyPlugins` from `vite-plus`, wrap the Phoenix and `nbRoutes` plugins with `lazyPlugins`, and use `vp dev`/`vp check`/`vp build`; preserve plain Vite compatibility only for an explicitly legacy target.

## Upgrade or migrate

- Compare generated output and TypeScript declarations before and after changing package versions or mode. For simple→rich/resource migrations, update consumers from strings to `.url`/route objects or new per-resource imports deliberately.
- Let the current generator clean stale artifacts when switching modes; inspect its cleanup target before deleting anything. Preserve custom app code outside generated directories and update Vite/tsconfig aliases with the output layout.
- Re-run generation after router changes and review renamed helpers, parameter extraction, HTTP methods, query serialization, and module-format changes.

## Diagnose and verify

- For missing routes, compile the router and run with `--router`; check helper naming, scope/controller grouping, filters, and whether the route is excluded. For stale files, inspect classic/resource collisions and the configured output path.
- For type errors, open the generated declaration and compare required params/options with the call site. For Inertia/form failures, verify rich/method/form flags and whether the client expects a URL string or route result.
- Verify with `mix compile`, `mix nb_routes.gen`, generated artifact inspection, `vp check`, `vp build`, and runtime tests for required params, query/anchor encoding, method variants, and form attributes when enabled. If `nb_vite` is configured, exercise router-change regeneration under `vp dev`.
- If “latest” is requested, consult current package source/HexDocs/GitHub and official Phoenix router guidance; state the date checked and compare with `mix.lock`.
