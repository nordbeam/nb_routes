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

    router.__routes__()
    |> Enum.filter(&has_helper?/1)
    |> Enum.filter(&filter_route(&1, config))
    |> Enum.map(&Route.from_phoenix_route(&1, opts))
    |> Enum.uniq_by(& &1.name)
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

  # Check if the route has a helper name (some routes like forward/4 don't)
  defp has_helper?(%Phoenix.Router.Route{helper: nil}), do: false
  defp has_helper?(%Phoenix.Router.Route{helper: ""}), do: false
  defp has_helper?(%Phoenix.Router.Route{}), do: true

  # Filter routes based on configuration include/exclude patterns
  defp filter_route(%Phoenix.Router.Route{helper: helper}, %Configuration{
         include: include,
         exclude: exclude
       }) do
    included? = Enum.empty?(include) || Enum.any?(include, &Regex.match?(&1, helper))
    excluded? = Enum.any?(exclude, &Regex.match?(&1, helper))

    included? && !excluded?
  end
end
