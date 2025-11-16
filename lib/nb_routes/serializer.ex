defmodule NbRoutes.Serializer do
  @moduledoc """
  Serializes route segments into a compact format for JavaScript runtime.

  This module converts Phoenix route patterns into a tree-like structure that can be
  efficiently evaluated by the JavaScript runtime to generate URLs.

  ## Node Types

  The serializer uses the following node types (inspired by js-routes):

    * `{:literal, string}` - Static text like "/users/"
    * `{:param, name}` - Dynamic parameter like `:id`
    * `{:glob, name}` - Glob parameter like `*path`
    * `{:optional, segments}` - Optional segment like `(.:format)`

  ## Examples

      # Serialize route segments
      route = %NbRoutes.Route{
        name: "users_path",
        verb: :GET,
        path: "/users/:id(.:format)",
        segments: ["/users/", :id, {:optional, [".", :format]}]
      }
      NbRoutes.Serializer.serialize(route)
      # => ["/users/", [:param, "id"], [:optional, [".", [:param, "format"]]]]

  """

  alias NbRoutes.Route

  @doc """
  Serializes route segments into a JavaScript-compatible format.

  ## Examples

      iex> route = %NbRoutes.Route{
      ...>   name: "user_path",
      ...>   verb: :GET,
      ...>   path: "/users/:id",
      ...>   segments: ["/users/", :id]
      ...> }
      iex> NbRoutes.Serializer.serialize(route)
      ["/users/", [:param, "id"]]

  """
  def serialize(%Route{segments: segments}) do
    serialize_segments(segments)
  end

  @doc """
  Serializes the parameter metadata (required/optional params with defaults).

  ## Examples

      iex> route = %NbRoutes.Route{
      ...>   name: "user_path",
      ...>   verb: :GET,
      ...>   path: "/users/:id(.:format)",
      ...>   segments: [],
      ...>   required_params: ["id"],
      ...>   optional_params: ["format"],
      ...>   defaults: %{"format" => "json"}
      ...> }
      iex> NbRoutes.Serializer.serialize_params(route)
      %{
        "id" => %{required: true},
        "format" => %{default: "json"}
      }

  """
  def serialize_params(%Route{
        required_params: required,
        optional_params: optional,
        defaults: defaults
      }) do
    required_map =
      required
      |> Enum.map(&{&1, %{required: true}})
      |> Map.new()

    optional_map =
      optional
      |> Enum.map(fn param ->
        case Map.fetch(defaults, param) do
          {:ok, default} -> {param, %{default: default}}
          :error -> {param, %{}}
        end
      end)
      |> Map.new()

    Map.merge(required_map, optional_map)
  end

  # Private functions

  # Serialize a list of segments
  defp serialize_segments(segments) do
    Enum.map(segments, &serialize_segment/1)
  end

  # Serialize individual segment types
  defp serialize_segment(segment) when is_binary(segment) do
    # Static literal - keep as-is
    segment
  end

  defp serialize_segment(atom) when is_atom(atom) do
    # Dynamic parameter
    [:param, Atom.to_string(atom)]
  end

  defp serialize_segment({:glob, param}) when is_atom(param) do
    # Glob parameter
    [:glob, Atom.to_string(param)]
  end

  defp serialize_segment({:optional, parts}) when is_list(parts) do
    # Optional segment - recursively serialize its parts
    [:optional, serialize_segments(parts)]
  end

  defp serialize_segment(other) do
    # Fallback for any unexpected types
    other
  end
end
