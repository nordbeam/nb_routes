defmodule NbRoutes do
  @moduledoc """
  Generate JavaScript/TypeScript route helpers from Phoenix routes.

  NbRoutes is a port of js-routes for Rails to Phoenix/Elixir. It extracts route
  information from your Phoenix router at compile time and generates JavaScript
  helper functions that you can use in your frontend code.

  ## Features

    * **Type-safe route generation** - Generate paths with compile-time validation
    * **TypeScript support** - Auto-generate `.d.ts` files with full type information
    * **Multiple module formats** - ESM, CommonJS, UMD, or global namespace
    * **Flexible configuration** - Include/exclude routes, camelCase naming, URL helpers
    * **Integration ready** - Works seamlessly with nb_vite, nb_inertia, and nb_ts

  ## Quick Start

      # Generate route helpers
      mix nb_routes.gen

      # In your JavaScript/TypeScript
      import { users_path, user_path } from './routes';

      users_path()                    // => "/users"
      user_path(1)                    // => "/users/1"
      user_path(1, { format: 'json' }) // => "/users/1.json"

  ## Configuration

  Configure in your `config/config.exs`:

      config :nb_routes,
        module_type: :esm,
        output_file: "assets/js/routes.js",
        include: [~r/^api_/],
        exclude: [~r/^admin_/]

  See `NbRoutes.Configuration` for all available options.

  ## Examples

      # Generate JavaScript code
      code = NbRoutes.generate(MyAppWeb.Router)

      # Generate and write to file
      NbRoutes.generate!("assets/js/routes.js", MyAppWeb.Router)

      # Generate TypeScript definitions
      types = NbRoutes.definitions(MyAppWeb.Router)

      # Generate and write TypeScript definitions
      NbRoutes.definitions!("assets/js/routes.d.ts", MyAppWeb.Router)

  """

  # Optional: Register compile hook for NbTs type generation
  # This enables automatic TypeScript type regeneration when router is recompiled
  # Only activates if nb_ts is installed (it's an optional dependency)
  if Code.ensure_loaded?(NbTs.CompileHooks) do
    @after_compile {NbTs.CompileHooks, :__after_compile__}
  end

  alias NbRoutes.{CodeGenerator, Configuration, Generator, TypeGenerator}

  @doc """
  Generates JavaScript route helper code from the given router.

  ## Options

  All options from `NbRoutes.Configuration` are supported.

  ## Examples

      # Generate JavaScript code
      code = NbRoutes.generate(MyAppWeb.Router)
      # => "export const users_path = ..."

      # Generate as CommonJS
      code = NbRoutes.generate(MyAppWeb.Router, module_type: :cjs)
      # => "module.exports.users_path = ..."

  """
  def generate(router \\ nil, opts \\ []) do
    config = build_config(opts)
    router = router || config.router || Generator.detect_router()

    unless router do
      raise ArgumentError, """
      Could not detect Phoenix router. Please specify explicitly:

          NbRoutes.generate(MyAppWeb.Router)

      Or configure it:

          config :nb_routes, router: MyAppWeb.Router
      """
    end

    routes = Generator.extract_routes(router, opts)
    CodeGenerator.generate(routes, config)
  end

  @doc """
  Generates JavaScript route helpers and writes to the specified file.

  ## Examples

      NbRoutes.generate!("assets/js/routes.js", MyAppWeb.Router)

      NbRoutes.generate!("assets/js/routes.js", MyAppWeb.Router,
        module_type: :esm,
        include: [~r/^api_/]
      )

  """
  def generate!(file_path, router \\ nil, opts \\ []) do
    code = generate(router, opts)
    File.mkdir_p!(Path.dirname(file_path))
    File.write!(file_path, code)
    file_path
  end

  @doc """
  Generates TypeScript type definitions for route helpers.

  ## Examples

      # Generate TypeScript definitions
      types = NbRoutes.definitions(MyAppWeb.Router)
      # => "export const users_path: RouteHelper<...>"

  """
  def definitions(router \\ nil, opts \\ []) do
    config = build_config(opts)
    router = router || config.router || Generator.detect_router()

    unless router do
      raise ArgumentError, """
      Could not detect Phoenix router. Please specify explicitly:

          NbRoutes.definitions(MyAppWeb.Router)
      """
    end

    routes = Generator.extract_routes(router, opts)
    TypeGenerator.generate(routes, config)
  end

  @doc """
  Generates TypeScript definitions and writes to the specified file.

  If no file path is provided, derives it from the configured `output_file`.

  ## Examples

      NbRoutes.definitions!("assets/js/routes.d.ts", MyAppWeb.Router)

      NbRoutes.definitions!(MyAppWeb.Router)  # Uses configured output_file

  """
  def definitions!(file_path \\ nil, router \\ nil, opts \\ [])

  def definitions!(file_path, router, opts) when is_binary(file_path) do
    types = definitions(router, opts)
    File.mkdir_p!(Path.dirname(file_path))
    File.write!(file_path, types)
    file_path
  end

  def definitions!(router, opts, _) when is_atom(router) or is_list(opts) do
    config = build_config(opts)
    file_path = Configuration.types_file(config)
    definitions!(file_path, router, opts)
  end

  @doc """
  Extracts routes from the given router module.

  Returns a list of `NbRoutes.Route` structs.

  ## Examples

      # Extract routes
      routes = NbRoutes.routes(MyAppWeb.Router)
      # => [%NbRoutes.Route{name: "user_path", verb: :GET, path: "/users/:id", ...}, ...]

  """
  def routes(router, opts \\ []) do
    Generator.extract_routes(router, opts)
  end

  @doc """
  Configures NbRoutes with the given options.

  This is a convenience function for building a configuration struct.

  ## Examples

      iex> NbRoutes.configure(module_type: :esm)
      %NbRoutes.Configuration{module_type: :esm}

  """
  def configure(opts \\ []) do
    build_config(opts)
  end

  # ============================================================================
  # nb_ts Integration
  # ============================================================================

  @doc """
  Returns the detected or configured Phoenix router module.

  This function is called by nb_ts to discover the router for type generation.
  It follows the same detection logic as the main API.

  ## Examples

      # Auto-detect router
      router = NbRoutes.__nb_routes_router__()
      # => MyAppWeb.Router

  """
  def __nb_routes_router__ do
    config = build_config([])
    config.router || Generator.detect_router()
  end

  @doc """
  Returns type metadata for all routes in the detected router.

  This function is called by nb_ts to generate TypeScript type definitions
  for route helpers. It returns a list of route metadata maps that nb_ts
  can use to generate type-safe route helper signatures.

  The metadata includes:
  - `name`: The route helper name (e.g., "user_path")
  - `path`: The route pattern (e.g., "/users/:id")
  - `verb`: The HTTP verb (e.g., :GET)
  - `required_params`: List of required parameter names
  - `optional_params`: List of optional parameter names

  ## Examples

      metadata = NbRoutes.__nb_routes_type_metadata__()
      # => [
      #   %{
      #     name: "user_path",
      #     path: "/users/:id",
      #     verb: :GET,
      #     required_params: ["id"],
      #     optional_params: ["format"]
      #   },
      #   ...
      # ]

  """
  def __nb_routes_type_metadata__ do
    case __nb_routes_router__() do
      nil ->
        []

      router ->
        routes = Generator.extract_routes(router, [])

        Enum.map(routes, fn route ->
          %{
            name: route.name,
            path: route.path,
            verb: route.verb,
            required_params: route.required_params,
            optional_params: route.optional_params
          }
        end)
    end
  end

  @doc """
  Returns type metadata for a specific configuration.

  Similar to `__nb_routes_type_metadata__/0`, but allows passing a router
  module and configuration options.

  ## Examples

      metadata = NbRoutes.__nb_routes_type_metadata__(MyAppWeb.Router, camel_case: true)

  """
  def __nb_routes_type_metadata__(router, opts \\ []) when is_atom(router) do
    routes = Generator.extract_routes(router, opts)

    Enum.map(routes, fn route ->
      %{
        name: route.name,
        path: route.path,
        verb: route.verb,
        required_params: route.required_params,
        optional_params: route.optional_params
      }
    end)
  end

  # Private functions

  defp build_config(opts) do
    app_config = Application.get_env(:nb_routes, :config, [])
    merged_opts = Keyword.merge(app_config, opts)
    Configuration.new(merged_opts)
  end
end
