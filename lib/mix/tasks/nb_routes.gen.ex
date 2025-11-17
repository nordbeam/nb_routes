defmodule Mix.Tasks.NbRoutes.Gen do
  @shortdoc "Generate JavaScript route helpers from Phoenix routes"

  @moduledoc """
  Generates JavaScript and TypeScript route helpers from your Phoenix router.

      $ mix nb_routes.gen
      $ mix nb_routes.gen --router MyAppWeb.Router
      $ mix nb_routes.gen --output assets/js/routes.js

  ## Options

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

  ## Examples

      # Generate with defaults
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
          url_helpers: :boolean
        ],
        aliases: [
          r: :router,
          o: :output,
          m: :module_type
        ]
      )

    # Build configuration from options
    config_opts = build_config_opts(opts)

    # Resolve router module
    router =
      case Keyword.get(opts, :router) do
        nil ->
          NbRoutes.Generator.detect_router()

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

    Mix.shell().info("NbRoutes: Generating route helpers from #{inspect(router)}...")

    # Generate JavaScript
    output_file = Keyword.get(config_opts, :output_file, "assets/js/routes.js")

    try do
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
    rescue
      e ->
        Mix.shell().error("NbRoutes: Error generating routes: #{Exception.message(e)}")
        Mix.shell().error(Exception.format(:error, e, __STACKTRACE__))
        exit({:shutdown, 1})
    end
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

    config_opts
  end
end
