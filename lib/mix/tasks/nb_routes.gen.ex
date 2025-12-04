defmodule Mix.Tasks.NbRoutes.Gen do
  @shortdoc "Generate JavaScript route helpers from Phoenix routes"

  @moduledoc """
  Generates JavaScript and TypeScript route helpers from your Phoenix router.

      $ mix nb_routes.gen
      $ mix nb_routes.gen --router MyAppWeb.Router
      $ mix nb_routes.gen --output assets/js/routes.js

  ## Options

  ### Classic Mode (default)

    * `--router` - Phoenix router module (default: auto-detect)
    * `--output` - Output file path (default: assets/js/routes.js)
    * `--module-type` - Module format: esm, cjs, umd (default: esm)
    * `--no-types` - Skip TypeScript definitions generation
    * `--include` - Regex pattern to include routes (can be repeated)
    * `--exclude` - Regex pattern to exclude routes (can be repeated)
    * `--camel-case` - Convert route names to camelCase
    * `--compact` - Remove _path suffix from route names
    * `--url-helpers` - Generate URL helpers (*_url) in addition to path helpers
    * `--variant` - Route helper variant: simple or rich (default: simple)
    * `--with-methods` - Enable method variants (.get, .post, .url, etc.)
    * `--with-forms` - Enable form helpers (.form, .form.patch, etc.)

  ### Resource Mode

    * `--style resource` - Generate per-resource TypeScript files for tree-shaking
    * `--output-dir` - Output directory for resource files (default: assets/js/routes)
    * `--group-by` - How to group routes: resource, scope, controller (default: resource)
    * `--no-index` - Skip generating index.ts barrel file
    * `--no-live` - Exclude LiveView routes

  ## Examples

      # Generate with defaults (classic mode)
      mix nb_routes.gen

      # Generate only API routes
      mix nb_routes.gen --include "^api_"

      # Exclude admin routes
      mix nb_routes.gen --exclude "^admin_"

      # Generate as CommonJS module
      mix nb_routes.gen --module-type cjs

      # Generate with camelCase names
      mix nb_routes.gen --camel-case

      # Generate rich mode with form helpers
      mix nb_routes.gen --variant rich --with-methods --with-forms

      # Generate per-resource TypeScript files
      mix nb_routes.gen --style resource --output-dir assets/js/routes

      # Resource mode with scope-based grouping
      mix nb_routes.gen --style resource --group-by scope

  """

  use Mix.Task

  alias NbRoutes.Configuration

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")
    Mix.Task.reenable("nb_routes.gen")

    {opts, _args, _invalid} =
      OptionParser.parse(args,
        strict: [
          # Classic mode options
          router: :string,
          output: :string,
          module_type: :string,
          variant: :string,
          with_methods: :boolean,
          with_forms: :boolean,
          types: :boolean,
          include: :keep,
          exclude: :keep,
          camel_case: :boolean,
          compact: :boolean,
          url_helpers: :boolean,
          # Resource mode options
          style: :string,
          output_dir: :string,
          group_by: :string,
          index: :boolean,
          live: :boolean
        ],
        aliases: [
          r: :router,
          o: :output,
          m: :module_type,
          s: :style
        ]
      )

    # Build configuration from options
    config_opts = build_config_opts(opts)

    # Resolve router module (CLI option > config > auto-detect)
    router =
      case Keyword.get(opts, :router) do
        nil ->
          case Application.get_env(:nb_routes, :router) do
            nil -> NbRoutes.Generator.detect_router()
            router_module -> router_module
          end

        module_name ->
          Module.concat([module_name])
      end

    unless router do
      Mix.shell().error("""
      NbRoutes: Could not detect Phoenix router module.

      Please specify the router explicitly:

          mix nb_routes.gen --router MyAppWeb.Router

      Or configure it in config/config.exs:

          config :nb_routes, router: MyAppWeb.Router
      """)

      exit({:shutdown, 1})
    end

    config = Configuration.new(config_opts)
    style = config.style

    Mix.shell().info(
      "NbRoutes: Generating route helpers from #{inspect(router)} (#{style} mode)..."
    )

    try do
      case style do
        :resource ->
          generate_resource_mode!(config_opts, router, opts)

        :classic ->
          generate_classic_mode!(config_opts, router, opts)
      end
    rescue
      e ->
        Mix.shell().error("NbRoutes: Error generating routes: #{Exception.message(e)}")
        Mix.shell().error(Exception.format(:error, e, __STACKTRACE__))
        exit({:shutdown, 1})
    end
  end

  defp generate_classic_mode!(config_opts, router, opts) do
    output_file = Keyword.get(config_opts, :output_file, "assets/js/routes.js")

    js_file = NbRoutes.generate!(output_file, router, config_opts)
    Mix.shell().info("NbRoutes: ✓ Generated #{js_file}")

    # Generate TypeScript definitions unless --no-types
    unless Keyword.get(opts, :types) == false do
      config = Configuration.new(config_opts)
      types_file = Configuration.types_file(config)
      ts_file = NbRoutes.definitions!(types_file, router, config_opts)
      Mix.shell().info("NbRoutes: ✓ Generated #{ts_file}")
    end

    # Count routes
    routes = NbRoutes.routes(router, config_opts)
    Mix.shell().info("NbRoutes: Generated #{length(routes)} route helper(s)")
  end

  defp generate_resource_mode!(config_opts, router, _opts) do
    output_dir = Keyword.get(config_opts, :output_dir, "assets/js/routes")

    files = NbRoutes.generate!(output_dir, router, config_opts)

    Enum.each(files, fn file ->
      relative_path = Path.relative_to(file, File.cwd!())
      Mix.shell().info("NbRoutes: ✓ Generated #{relative_path}")
    end)

    # Count routes
    routes = NbRoutes.routes(router, config_opts)
    Mix.shell().info("NbRoutes: Generated #{length(files)} files for #{length(routes)} route(s)")
  end

  defp build_config_opts(opts) do
    config_opts = []

    config_opts =
      if output = Keyword.get(opts, :output) do
        Keyword.put(config_opts, :output_file, output)
      else
        config_opts
      end

    config_opts =
      if module_type = Keyword.get(opts, :module_type) do
        type_atom =
          case String.downcase(module_type) do
            "esm" -> :esm
            "cjs" -> :cjs
            "umd" -> :umd
            "nil" -> nil
            other -> raise ArgumentError, "Invalid module type: #{other}"
          end

        Keyword.put(config_opts, :module_type, type_atom)
      else
        config_opts
      end

    config_opts =
      if Keyword.get(opts, :camel_case) do
        Keyword.put(config_opts, :camel_case, true)
      else
        config_opts
      end

    config_opts =
      if Keyword.get(opts, :compact) do
        Keyword.put(config_opts, :compact, true)
      else
        config_opts
      end

    config_opts =
      if Keyword.get(opts, :url_helpers) do
        Keyword.put(config_opts, :url_helpers, true)
      else
        config_opts
      end

    # Handle variant option
    config_opts =
      if variant = Keyword.get(opts, :variant) do
        variant_atom =
          case String.downcase(variant) do
            "simple" -> :simple
            "rich" -> :rich
            other -> raise ArgumentError, "Invalid variant: #{other}. Must be 'simple' or 'rich'"
          end

        Keyword.put(config_opts, :variant, variant_atom)
      else
        config_opts
      end

    # Handle with_methods option
    config_opts =
      if Keyword.get(opts, :with_methods) do
        Keyword.put(config_opts, :with_methods, true)
      else
        config_opts
      end

    # Handle with_forms option
    config_opts =
      if Keyword.get(opts, :with_forms) do
        Keyword.put(config_opts, :with_forms, true)
      else
        config_opts
      end

    # Handle include patterns
    includes = Keyword.get_values(opts, :include)

    config_opts =
      if Enum.any?(includes) do
        regex_list = Enum.map(includes, &Regex.compile!/1)
        Keyword.put(config_opts, :include, regex_list)
      else
        config_opts
      end

    # Handle exclude patterns
    excludes = Keyword.get_values(opts, :exclude)

    config_opts =
      if Enum.any?(excludes) do
        regex_list = Enum.map(excludes, &Regex.compile!/1)
        Keyword.put(config_opts, :exclude, regex_list)
      else
        config_opts
      end

    # Handle style option (resource mode)
    config_opts =
      if style = Keyword.get(opts, :style) do
        style_atom =
          case String.downcase(style) do
            "classic" ->
              :classic

            "resource" ->
              :resource

            other ->
              raise ArgumentError, "Invalid style: #{other}. Must be 'classic' or 'resource'"
          end

        Keyword.put(config_opts, :style, style_atom)
      else
        config_opts
      end

    # Handle output_dir option (resource mode)
    config_opts =
      if output_dir = Keyword.get(opts, :output_dir) do
        Keyword.put(config_opts, :output_dir, output_dir)
      else
        config_opts
      end

    # Handle group_by option (resource mode)
    config_opts =
      if group_by = Keyword.get(opts, :group_by) do
        group_by_atom =
          case String.downcase(group_by) do
            "resource" ->
              :resource

            "scope" ->
              :scope

            "controller" ->
              :controller

            other ->
              raise ArgumentError,
                    "Invalid group_by: #{other}. Must be 'resource', 'scope', or 'controller'"
          end

        Keyword.put(config_opts, :group_by, group_by_atom)
      else
        config_opts
      end

    # Handle --no-index option (resource mode)
    config_opts =
      if Keyword.get(opts, :index) == false do
        Keyword.put(config_opts, :include_index, false)
      else
        config_opts
      end

    # Handle --no-live option (resource mode)
    config_opts =
      if Keyword.get(opts, :live) == false do
        Keyword.put(config_opts, :include_live, false)
      else
        config_opts
      end

    config_opts
  end
end
