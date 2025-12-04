defmodule NbRoutes.ResourceGenerator do
  @moduledoc """
  Generates per-resource TypeScript files for tree-shakeable route imports.

  This module implements resource mode for nb_routes, which generates separate
  TypeScript files per resource (e.g., users.ts, posts.ts) instead of a single
  routes.js file. This enables better tree-shaking and a more Phoenix-idiomatic
  developer experience.

  ## Resource Grouping

  Routes are grouped into resources based on the configured `:group_by` option:

    * `:resource` (default) - Groups by helper name (user_path -> users)
    * `:scope` - Groups by path prefix (/admin/users -> admin.users)
    * `:controller` - Groups by controller module

  ## Output Structure

      assets/js/routes/
      ├── index.ts           # Barrel file exporting all resources
      ├── lib/
      │   └── wayfinder.ts   # Runtime library
      ├── users.ts           # Users resource
      ├── posts.ts           # Posts resource
      └── admin/
          ├── index.ts       # Admin scope barrel
          └── users.ts       # Admin users resource

  """

  alias NbRoutes.{Configuration, Route, ResourceTypeScript}

  @doc """
  Generates all files for resource mode.

  Returns a list of file maps with `:path` and `:content` keys.
  """
  def generate(routes, %Configuration{} = config) do
    resources = group_routes_by_resource(routes, config)

    files = []

    # Generate runtime
    files = [ResourceTypeScript.generate_runtime(config) | files]

    # Generate resource files
    resource_files = Enum.flat_map(resources, &generate_resource_files(&1, config))
    files = files ++ resource_files

    # Generate index file if enabled
    files =
      if config.include_index do
        files ++ [ResourceTypeScript.generate_index(resources, config)]
      else
        files
      end

    # Generate scoped index files
    scoped_indexes = generate_scoped_indexes(resources, config)
    files ++ scoped_indexes
  end

  @doc """
  Groups routes into resources based on configuration.

  Returns a list of resource maps with keys:
    * `:key` - Resource key as list of atoms (e.g., [:admin, :users])
    * `:name` - Resource name atom (e.g., :users)
    * `:path` - File path relative to output_dir
    * `:actions` - List of action maps
    * `:routes` - Original routes
  """
  def group_routes_by_resource(routes, %Configuration{} = config) do
    routes
    |> Enum.group_by(&resource_key(&1, config))
    |> Enum.map(fn {key, routes} ->
      %{
        key: key,
        name: List.last(key),
        path: generate_resource_path(key),
        actions: extract_actions(routes),
        routes: routes
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  @doc """
  Determines the resource key for a route based on configuration.

  The key is a list of atoms representing the resource hierarchy.
  """
  def resource_key(%Route{} = route, %Configuration{group_by: group_by}) do
    case group_by do
      :resource -> resource_key_from_helper(route)
      :scope -> resource_key_from_path(route)
      :controller -> resource_key_from_controller(route)
    end
  end

  @doc """
  Extracts resource key from helper name.

  ## Examples

      iex> route = %Route{name: "users_path", path: "/users"}
      iex> ResourceGenerator.resource_key_from_helper(route)
      [:users]

      iex> route = %Route{name: "admin_users_path", path: "/admin/users"}
      iex> ResourceGenerator.resource_key_from_helper(route)
      [:admin, :users]

  """
  def resource_key_from_helper(%Route{name: name, path: path}) do
    # Extract scope from path
    scope = extract_scope_from_path(path)

    # Get resource from helper name
    resource =
      name
      # Remove _path/_url suffix
      |> String.replace(~r/_(path|url)$/, "")
      # Remove action prefix (new_user, edit_user, etc.)
      |> String.replace(~r/^(new|edit|create|update|delete|restore)_/, "")
      # Remove action suffix (users_index, users_new, contacts_create, etc.)
      # Also handles common custom actions like confirm, restore, etc.
      |> String.replace(
        ~r/_(index|show|new|edit|create|update|delete|confirm|restore|confirm_email)$/,
        ""
      )
      # Handle nested resource patterns like "contacts_contacts" -> "contacts"
      |> deduplicate_resource_name()
      |> then(fn name ->
        # Remove full scope prefix if present (e.g., "api_v1_" from "api_v1_products")
        name_without_scope = strip_scope_prefix(name, scope)

        # Ensure resource name is plural
        pluralize(name_without_scope)
      end)
      |> String.to_atom()

    scope ++ [resource]
  end

  @doc """
  Extracts resource key from path.
  """
  def resource_key_from_path(%Route{path: path}) do
    path
    |> String.split("/", trim: true)
    |> Enum.reject(&String.starts_with?(&1, ":"))
    |> Enum.reject(&String.starts_with?(&1, "*"))
    |> Enum.map(&String.to_atom/1)
    |> case do
      [] -> [:root]
      key -> key
    end
  end

  @doc """
  Extracts resource key from controller module.
  """
  def resource_key_from_controller(%Route{} = route) do
    # For now, fall back to helper-based grouping
    # This can be enhanced when we have controller info in Route struct
    resource_key_from_helper(route)
  end

  @doc """
  Generates the file path for a resource.

  ## Examples

      iex> ResourceGenerator.generate_resource_path([:users])
      "users.ts"

      iex> ResourceGenerator.generate_resource_path([:admin, :users])
      "admin/users.ts"

  """
  def generate_resource_path(key) do
    key
    |> Enum.map(&Atom.to_string/1)
    |> Path.join()
    |> Kernel.<>(".ts")
  end

  @doc """
  Infers the Phoenix-style action name from a route.

  ## Examples

      iex> route = %Route{name: "users_path", verb: :GET, path: "/users"}
      iex> ResourceGenerator.infer_action_name(route)
      :index

      iex> route = %Route{name: "user_path", verb: :GET, path: "/users/:id"}
      iex> ResourceGenerator.infer_action_name(route)
      :show

  """
  def infer_action_name(%Route{name: name, verb: verb, path: path}) do
    # Normalize verb to uppercase for comparison (Phoenix uses lowercase)
    verb_upper = verb |> Atom.to_string() |> String.upcase() |> String.to_atom()

    cond do
      # Check helper name patterns first (prefix patterns)
      name =~ ~r/^new_/ -> :new
      name =~ ~r/^edit_/ -> :edit
      name =~ ~r/^create_/ -> :create
      name =~ ~r/^update_/ -> :update
      name =~ ~r/^delete_/ -> :delete
      name =~ ~r/^restore_/ -> :restore
      # Check helper name suffix patterns (e.g., contacts_restore_path)
      name =~ ~r/_restore_(path|url)$/ -> :restore
      name =~ ~r/_confirm_(path|url)$/ -> :confirm
      name =~ ~r/_new_(path|url)$/ -> :new
      name =~ ~r/_index_(path|url)$/ -> :index
      name =~ ~r/_show_(path|url)$/ -> :show
      # Check path patterns
      path =~ ~r"/new$" -> :new
      path =~ ~r"/create$" && verb_upper == :GET -> :new
      path =~ ~r"/:[\w]+/edit$" -> :edit
      path =~ ~r"/:[\w]+/restore$" -> :restore
      path =~ ~r"/:[\w]+/confirm$" -> :confirm
      # Infer from HTTP verb for standard CRUD
      verb_upper == :POST -> :create
      verb_upper == :PATCH -> :update
      verb_upper == :PUT -> :update
      verb_upper == :DELETE -> :delete
      # GET routes - collection vs member
      verb_upper == :GET && path =~ ~r"/:[\w]+$" -> :show
      verb_upper == :GET -> :index
      # Default
      true -> :index
    end
  end

  # Private functions

  defp extract_scope_from_path(path) do
    cond do
      path =~ ~r"^/admin/" ->
        [:admin]

      path =~ ~r"^/api/v(\d+)/" ->
        [_, version] = Regex.run(~r"^/api/v(\d+)/", path)
        [:api, :"v#{version}"]

      path =~ ~r"^/api/" ->
        [:api]

      true ->
        []
    end
  end

  defp extract_actions(routes) do
    routes
    |> Enum.map(fn route ->
      %{
        name: infer_action_name(route),
        route: route,
        verb: route.verb,
        path: route.path,
        params: build_params(route)
      }
    end)
    |> Enum.uniq_by(& &1.name)
    |> Enum.sort_by(&action_sort_order/1)
  end

  defp build_params(%Route{required_params: required, optional_params: optional}) do
    required_params = Enum.map(required, &%{name: &1, required: true})
    optional_params = Enum.map(optional, &%{name: &1, required: false})
    required_params ++ optional_params
  end

  defp action_sort_order(%{name: name}) do
    case name do
      :index -> 0
      :new -> 1
      :create -> 2
      :show -> 3
      :edit -> 4
      :update -> 5
      :delete -> 6
      :restore -> 7
      :confirm -> 8
      _ -> 9
    end
  end

  defp generate_resource_files(resource, config) do
    [ResourceTypeScript.generate_resource_file(resource, config)]
  end

  defp generate_scoped_indexes(resources, config) do
    resources
    |> Enum.filter(fn r -> length(r.key) > 1 end)
    |> Enum.group_by(fn r -> Enum.take(r.key, length(r.key) - 1) end)
    |> Enum.map(fn {scope, scoped_resources} ->
      ResourceTypeScript.generate_scoped_index(scope, scoped_resources, config)
    end)
  end

  defp strip_scope_prefix(name, []) do
    name
  end

  defp strip_scope_prefix(name, scope) do
    # Build the full scope prefix (e.g., [:api, :v1] -> "api_v1_")
    scope_prefix =
      scope
      |> Enum.map(&Atom.to_string/1)
      |> Enum.join("_")
      |> Kernel.<>("_")

    String.replace_prefix(name, scope_prefix, "")
  end

  defp deduplicate_resource_name(name) do
    # Handle patterns like "contacts_contacts" -> "contacts"
    # or "users_users" -> "users"
    parts = String.split(name, "_")

    case parts do
      [first, second | _rest] when first == second ->
        first

      _ ->
        name
    end
  end

  defp pluralize(word) do
    # Simple pluralization - can be enhanced with Inflex if available
    cond do
      String.ends_with?(word, "s") ->
        word

      String.ends_with?(word, "y") ->
        String.slice(word, 0..-2//1) <> "ies"

      true ->
        word <> "s"
    end
  end
end
