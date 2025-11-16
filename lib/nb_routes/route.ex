defmodule NbRoutes.Route do
  @moduledoc """
  Represents a single Phoenix route for code generation.

  A route contains all the information needed to generate a JavaScript helper function,
  including the route name, HTTP verb, path pattern, and parameter information.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          verb: atom(),
          path: String.t(),
          segments: list(),
          required_params: [String.t()],
          optional_params: [String.t()],
          defaults: map()
        }

  @enforce_keys [:name, :verb, :path, :segments]
  defstruct [
    :name,
    :verb,
    :path,
    :segments,
    required_params: [],
    optional_params: [],
    defaults: %{}
  ]

  @doc """
  Creates a new route from a Phoenix route struct.

  ## Examples

      iex> phoenix_route = %Phoenix.Router.Route{
      ...>   helper: "user",
      ...>   verb: :GET,
      ...>   path: "/users/:id"
      ...> }
      iex> NbRoutes.Route.from_phoenix_route(phoenix_route)
      %NbRoutes.Route{
        name: "user_path",
        verb: :GET,
        path: "/users/:id",
        segments: ["/users/", :id],
        required_params: ["id"],
        optional_params: []
      }

  """
  def from_phoenix_route(phoenix_route, opts \\ [])

  def from_phoenix_route(%Phoenix.Router.Route{} = phoenix_route, opts) do
    name = generate_name(phoenix_route.helper, opts)
    segments = parse_path_segments(phoenix_route.path)
    {required, optional} = categorize_params(segments)

    %__MODULE__{
      name: name,
      verb: phoenix_route.verb,
      path: phoenix_route.path,
      segments: segments,
      required_params: required,
      optional_params: optional,
      defaults: Map.new()
    }
  end

  # Handle plain maps (Phoenix 1.8+)
  def from_phoenix_route(%{helper: helper, verb: verb, path: path} = _phoenix_route, opts) do
    name = generate_name(helper, opts)
    segments = parse_path_segments(path)
    {required, optional} = categorize_params(segments)

    %__MODULE__{
      name: name,
      verb: verb,
      path: path,
      segments: segments,
      required_params: required,
      optional_params: optional,
      defaults: Map.new()
    }
  end

  @doc """
  Generates the JavaScript helper name from a Phoenix helper name.

  ## Examples

      iex> NbRoutes.Route.generate_name("user", [])
      "user_path"

      iex> NbRoutes.Route.generate_name("user", compact: true)
      "user"

      iex> NbRoutes.Route.generate_name("user", camel_case: true)
      "userPath"

      iex> NbRoutes.Route.generate_name("user", camel_case: true, compact: true)
      "user"

  """
  def generate_name(helper, opts) do
    name = if Keyword.get(opts, :compact, false), do: helper, else: "#{helper}_path"

    if Keyword.get(opts, :camel_case, false) do
      to_camel_case(name)
    else
      name
    end
  end

  @doc """
  Generates the URL helper name (e.g., "user_url").

  ## Examples

      iex> NbRoutes.Route.generate_url_name("user", [])
      "user_url"

      iex> NbRoutes.Route.generate_url_name("user", camel_case: true)
      "userUrl"

  """
  def generate_url_name(helper, opts) do
    name = "#{helper}_url"

    if Keyword.get(opts, :camel_case, false) do
      to_camel_case(name)
    else
      name
    end
  end

  # Private functions

  # Parse path into segments, separating static strings from dynamic parameters
  defp parse_path_segments(path) do
    path
    |> String.split("/", trim: true)
    |> Enum.flat_map(fn segment ->
      cond do
        # Dynamic parameter: :id or *path
        String.starts_with?(segment, ":") ->
          param = String.trim_leading(segment, ":")
          [String.to_atom(param)]

        String.starts_with?(segment, "*") ->
          param = String.trim_leading(segment, "*")
          [{:glob, String.to_atom(param)}]

        # Static segment with optional parameter: posts(.:format)
        String.contains?(segment, "(") ->
          parse_optional_segment(segment)

        # Static segment
        true ->
          ["/#{segment}/"]
      end
    end)
    |> normalize_slashes()
  end

  # Parse segments with optional parts like "posts(.:format)"
  defp parse_optional_segment(segment) do
    case Regex.run(~r/^([^(]+)\((.*)\)$/, segment) do
      [_, static, optional] ->
        static_parts = if static != "", do: ["/#{static}"], else: []
        optional_parts = parse_optional_part(optional)
        static_parts ++ [{:optional, optional_parts}]

      nil ->
        ["/#{segment}/"]
    end
  end

  # Parse the content inside parentheses
  defp parse_optional_part("." <> rest) do
    if String.starts_with?(rest, ":") do
      param = String.trim_leading(rest, ":")
      [".", String.to_atom(param)]
    else
      [".#{rest}"]
    end
  end

  defp parse_optional_part(":" <> rest), do: [String.to_atom(rest)]
  defp parse_optional_part(static), do: [static]

  # Normalize slashes - combine consecutive static segments and remove leading/trailing slashes
  defp normalize_slashes(segments) do
    segments
    |> Enum.chunk_by(&is_binary/1)
    |> Enum.flat_map(fn
      [segment | _] = static_segments when is_binary(segment) ->
        combined =
          static_segments
          |> Enum.join()
          |> String.replace(~r{/+}, "/")

        [combined]

      dynamic_segments ->
        dynamic_segments
    end)
  end

  # Categorize parameters into required and optional
  defp categorize_params(segments) do
    {required, optional} =
      segments
      |> Enum.flat_map(fn
        {:optional, parts} -> Enum.filter(parts, &is_atom/1)
        {:glob, param} -> [param]
        param when is_atom(param) -> [param]
        _static -> []
      end)
      |> Enum.split_with(fn
        {:optional, _} -> false
        _ -> true
      end)

    required_names = Enum.map(required, &to_string/1)

    optional_names =
      optional
      |> Enum.map(fn
        {:optional, parts} -> parts
        param -> param
      end)
      |> List.flatten()
      |> Enum.filter(&is_atom/1)
      |> Enum.map(&to_string/1)

    {required_names, optional_names}
  end

  # Convert snake_case to camelCase
  defp to_camel_case(name) do
    name
    |> String.split("_")
    |> Enum.with_index()
    |> Enum.map(fn
      {word, 0} -> word
      {word, _} -> String.capitalize(word)
    end)
    |> Enum.join()
  end
end
