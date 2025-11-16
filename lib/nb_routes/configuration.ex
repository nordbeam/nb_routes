defmodule NbRoutes.Configuration do
  @moduledoc """
  Configuration structure for NbRoutes.

  ## Options

    * `:module_type` - Module format for generated code. One of `:esm`, `:cjs`, `:umd`, or `nil` for global namespace. Defaults to `:esm`.
    * `:output_file` - Path to the generated JavaScript file. Defaults to `"assets/js/routes.js"`.
    * `:types_file` - Path to the generated TypeScript definitions file. If `nil`, will use the same path as `:output_file` with `.d.ts` extension. Defaults to `nil`.
    * `:include` - List of regular expressions to match route names to include. Defaults to `[]` (include all).
    * `:exclude` - List of regular expressions to match route names to exclude. Defaults to `[]`.
    * `:camel_case` - Convert route names to camelCase. Defaults to `false`.
    * `:url_helpers` - Generate URL helpers (`*_url`) in addition to path helpers. Defaults to `false`.
    * `:compact` - Remove `_path` suffix from route names. Defaults to `false`.
    * `:default_url_options` - Default URL options (host, port, scheme) for URL helpers. Defaults to `%{}`.
    * `:documentation` - Include JSDoc documentation comments. Defaults to `true`.
    * `:router` - Phoenix router module. If `nil`, will attempt to auto-detect. Defaults to `nil`.

  ## Examples

      config = %NbRoutes.Configuration{
        module_type: :esm,
        output_file: "assets/js/routes.js",
        include: [~r/^api_/],
        exclude: [~r/^admin_/]
      }

  """

  @type module_type :: :esm | :cjs | :umd | nil
  @type t :: %__MODULE__{
          module_type: module_type(),
          output_file: String.t(),
          types_file: String.t() | nil,
          include: [Regex.t()],
          exclude: [Regex.t()],
          camel_case: boolean(),
          url_helpers: boolean(),
          compact: boolean(),
          default_url_options: map(),
          documentation: boolean(),
          router: module() | nil
        }

  @enforce_keys []
  defstruct module_type: :esm,
            output_file: "assets/js/routes.js",
            types_file: nil,
            include: [],
            exclude: [],
            camel_case: false,
            url_helpers: false,
            compact: false,
            default_url_options: %{},
            documentation: true,
            router: nil

  @doc """
  Creates a new configuration with the given options.

  ## Examples

      iex> NbRoutes.Configuration.new(module_type: :cjs)
      %NbRoutes.Configuration{module_type: :cjs}

  """
  def new(opts \\ []) do
    struct!(__MODULE__, opts)
  end

  @doc """
  Merges configuration options with defaults.

  ## Examples

      iex> config = %NbRoutes.Configuration{}
      iex> NbRoutes.Configuration.merge(config, module_type: :cjs)
      %NbRoutes.Configuration{module_type: :cjs}

  """
  def merge(%__MODULE__{} = config, opts) when is_list(opts) do
    struct!(config, opts)
  end

  @doc """
  Gets the TypeScript definitions file path.

  If `:types_file` is explicitly set, returns that. Otherwise, derives it from `:output_file`.

  ## Examples

      iex> config = %NbRoutes.Configuration{output_file: "assets/js/routes.js"}
      iex> NbRoutes.Configuration.types_file(config)
      "assets/js/routes.d.ts"

      iex> config = %NbRoutes.Configuration{types_file: "assets/types/routes.d.ts"}
      iex> NbRoutes.Configuration.types_file(config)
      "assets/types/routes.d.ts"

  """
  def types_file(%__MODULE__{types_file: file}) when not is_nil(file), do: file

  def types_file(%__MODULE__{output_file: output_file}) do
    output_file
    |> Path.rootname()
    |> Kernel.<>(".d.ts")
  end

  @doc """
  Validates the configuration.

  Returns `:ok` if valid, or `{:error, reason}` if invalid.

  ## Examples

      iex> config = %NbRoutes.Configuration{}
      iex> NbRoutes.Configuration.validate(config)
      :ok

  """
  def validate(%__MODULE__{module_type: type})
      when type not in [:esm, :cjs, :umd, nil] do
    {:error, "Invalid module_type: #{inspect(type)}. Must be one of :esm, :cjs, :umd, or nil"}
  end

  def validate(%__MODULE__{include: include}) when not is_list(include) do
    {:error, "include must be a list of regular expressions"}
  end

  def validate(%__MODULE__{exclude: exclude}) when not is_list(exclude) do
    {:error, "exclude must be a list of regular expressions"}
  end

  def validate(%__MODULE__{}), do: :ok
end
