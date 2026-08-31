# NbRoutes Usage Rules

Use `nb_routes` to generate JavaScript and TypeScript route helpers from a
Phoenix router. It is a standalone Mix task; `nb_vite`, `nb_inertia`, and
`nb_ts` integrations remain optional.

## Installation

Add the package to the application, fetch dependencies, and install the
standard dependency-backed skill manager:

```bash
mix deps.get
mix igniter.install usage_rules
```

Configure the application project's `mix.exs`:

```elixir
def project do
  [
    # ...
    usage_rules: usage_rules()
  ]
end

defp usage_rules do
  [
    skills: [
      location: ".agents/skills",
      package_skills: [:nb_routes]
    ]
  ]
end
```

Then sync the configured package skill:

```bash
mix usage_rules.sync
```

## Generate routes

Run `mix nb_routes.gen` after compiling the Phoenix router. Choose the
documented output style for the selected release:

```bash
mix nb_routes.gen
mix nb_routes.gen --variant rich --with-methods --with-forms
mix nb_routes.gen --style resource --output-dir assets/js/routes
```

Classic helpers return URL strings. Rich helpers can return `{url, method}`
objects and method variants; resource mode emits per-resource TypeScript
modules. Inspect generated signatures before passing route objects to Inertia
or forms, and treat generated files as build artifacts.

## Integrations and verification

When using `nb_vite`, configure the matching `nbRoutes` plugin export to watch
the router and run `mix nb_routes.gen`. When using `nb_inertia`, verify whether
the client expects a URL string or rich route result. Run `mix compile`, route
generation, generated-artifact inspection, and the relevant `mix test` suite
after changing configuration or router structure.
