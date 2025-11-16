defmodule NbRoutes.Generator do
  @moduledoc """
  Extracts routes from a Phoenix router and generates route helpers.
  """

  alias NbRoutes.{Configuration, Route}

  @doc """
  Extracts routes from the given Phoenix router module.

  ## Options

  See `NbRoutes.Configuration` for available options.

  ## Examples

      iex> NbRoutes.Generator.extract_routes(MyAppWeb.Router)
      [
        %NbRoutes.Route{name: "user_path", verb: :GET, path: "/users/:id", ...},
        ...
      ]

  """
  def extract_routes(router, opts \\ []) when is_atom(router) do
    config = Configuration.new(opts)

    # Convert routes and keep track of original phoenix routes
    routes_with_metadata =
      router.__routes__()
      |> Enum.filter(&has_helper?/1)
      |> Enum.filter(&filter_route(&1, config))
      |> Enum.map(fn phoenix_route ->
        route = Route.from_phoenix_route(phoenix_route, opts)
        {route, get_action(phoenix_route)}
      end)

    # Handle duplicate helper names by appending action name
    routes_with_metadata
    |> Enum.group_by(fn {route, _action} -> route.name end)
    |> Enum.flat_map(fn
      {_name, [{single_route, _action}]} ->
        # Only one route with this name, keep as is
        [single_route]

      {_name, multiple_routes} ->
        # Multiple routes with same helper name, append action to make unique
        Enum.map(multiple_routes, fn {route, action} ->
          # Remove _path suffix, append action, then add _path back
          base_name = String.replace_suffix(route.name, "_path", "")
          %{route | name: "#{base_name}_#{action}_path"}
        end)
    end)
  end

  @doc """
  Attempts to detect the Phoenix router module in the current application.

  Looks for modules matching the pattern `*Web.Router`.

  ## Examples

      iex> NbRoutes.Generator.detect_router()
      MyAppWeb.Router

  """
  def detect_router do
    app = Mix.Project.config()[:app]

    if app do
      Application.ensure_all_started(app)

      app
      |> Application.spec(:modules)
      |> Enum.find(fn module ->
        module_name = module |> Module.split() |> List.last()
        module_name == "Router" && function_exported?(module, :__routes__, 0)
      end)
    end
  end

  # Private functions

  # Extract action from route
  defp get_action(%Phoenix.Router.Route{plug_opts: action}), do: action
  defp get_action(%{plug_opts: action}), do: action

  # Check if the route has a helper name (some routes like forward/4 don't)
  defp has_helper?(%Phoenix.Router.Route{helper: nil}), do: false
  defp has_helper?(%Phoenix.Router.Route{helper: ""}), do: false
  defp has_helper?(%Phoenix.Router.Route{}), do: true
  # Handle plain maps (Phoenix 1.8+)
  defp has_helper?(%{helper: nil}), do: false
  defp has_helper?(%{helper: ""}), do: false
  defp has_helper?(%{helper: _}), do: true
  defp has_helper?(_), do: false

  # Filter routes based on configuration include/exclude patterns
  defp filter_route(%Phoenix.Router.Route{helper: helper}, %Configuration{
         include: include,
         exclude: exclude
       }) do
    included? = Enum.empty?(include) || Enum.any?(include, &Regex.match?(&1, helper))
    excluded? = Enum.any?(exclude, &Regex.match?(&1, helper))

    included? && !excluded?
  end

  # Handle plain maps (Phoenix 1.8+)
  defp filter_route(%{helper: helper}, %Configuration{include: include, exclude: exclude}) do
    included? = Enum.empty?(include) || Enum.any?(include, &Regex.match?(&1, helper))
    excluded? = Enum.any?(exclude, &Regex.match?(&1, helper))

    included? && !excluded?
  end
end
