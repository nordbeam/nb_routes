defmodule NbRoutes.ResourceTypeScriptTest do
  use ExUnit.Case

  alias NbRoutes.{Configuration, Route, ResourceGenerator, ResourceTypeScript}

  # Helper to create test routes
  defp route(name, verb, path, opts \\ []) do
    segments = parse_segments(path)
    {required, optional} = categorize_params(segments)

    %Route{
      name: name,
      verb: verb,
      path: path,
      segments: segments,
      required_params: Keyword.get(opts, :required_params, required),
      optional_params: Keyword.get(opts, :optional_params, optional),
      defaults: Keyword.get(opts, :defaults, %{})
    }
  end

  defp parse_segments(path) do
    path
    |> String.split("/", trim: true)
    |> Enum.flat_map(fn
      ":" <> param -> [String.to_atom(param)]
      "*" <> param -> [{:glob, String.to_atom(param)}]
      segment -> ["/#{segment}/"]
    end)
  end

  defp categorize_params(segments) do
    params =
      Enum.flat_map(segments, fn
        atom when is_atom(atom) -> [Atom.to_string(atom)]
        {:glob, atom} -> [Atom.to_string(atom)]
        _ -> []
      end)

    {params, []}
  end

  defp create_resource(name, routes) do
    config = Configuration.new(style: :resource, variant: :rich)
    resources = ResourceGenerator.group_routes_by_resource(routes, config)
    Enum.find(resources, &(&1.name == name))
  end

  describe "generate_runtime/1" do
    test "generates TypeScript runtime with route function" do
      config = Configuration.new(style: :resource, variant: :rich)
      %{content: content} = ResourceTypeScript.generate_runtime(config)

      assert content =~ "export type Method ="
      assert content =~ "export interface Route<M extends Method = Method>"
      assert content =~ "export interface RouteOptions"
      assert content =~ "export interface FormAttrs"
      assert content =~ "export type Param ="
      assert content =~ "export function route<P"
    end

    test "includes query parameter handling" do
      config = Configuration.new(style: :resource, variant: :rich)
      %{content: content} = ResourceTypeScript.generate_runtime(config)

      assert content =~ "query?"
      assert content =~ "URLSearchParams"
    end

    test "includes form helpers" do
      config = Configuration.new(style: :resource, variant: :rich, with_forms: true)
      %{content: content} = ResourceTypeScript.generate_runtime(config)

      assert content =~ "FormAttrs"
      assert content =~ "form:"
    end

    test "includes Phoenix.Param-style parameter extraction" do
      config = Configuration.new(style: :resource, variant: :rich)
      %{content: content} = ResourceTypeScript.generate_runtime(config)

      # Should handle objects with id property
      assert content =~ ~r/['"]id['"]\s+in/i or content =~ "id"
    end
  end

  describe "generate_resource_file/2" do
    test "generates resource file with imports" do
      routes = [
        route("users_path", :GET, "/users"),
        route("user_path", :GET, "/users/:id")
      ]

      resource = create_resource(:users, routes)
      config = Configuration.new(style: :resource, variant: :rich)
      file = ResourceTypeScript.generate_resource_file(resource, config)

      assert file.path =~ "users.ts"
      assert file.content =~ "import { route"
      assert file.content =~ "from"
      assert file.content =~ "wayfinder"
    end

    test "generates action with correct route call" do
      routes = [
        route("users_path", :GET, "/users")
      ]

      resource = create_resource(:users, routes)
      config = Configuration.new(style: :resource, variant: :rich)
      file = ResourceTypeScript.generate_resource_file(resource, config)

      assert file.content =~ ~r/index.*route.*['"]\/users['"].*['"]get['"]/s
    end

    test "generates typed parameters for actions with params" do
      routes = [
        route("user_path", :GET, "/users/:id")
      ]

      resource = create_resource(:users, routes)
      config = Configuration.new(style: :resource, variant: :rich)
      file = ResourceTypeScript.generate_resource_file(resource, config)

      # Should have type parameter for id
      assert file.content =~ "id"
      assert file.content =~ "Param"
    end

    test "exports resource object" do
      routes = [
        route("users_path", :GET, "/users"),
        route("user_path", :GET, "/users/:id")
      ]

      resource = create_resource(:users, routes)
      config = Configuration.new(style: :resource, variant: :rich)
      file = ResourceTypeScript.generate_resource_file(resource, config)

      assert file.content =~ "export const users"
      assert file.content =~ "as const"
    end

    test "generates individual action exports" do
      routes = [
        route("users_path", :GET, "/users"),
        route("user_path", :GET, "/users/:id")
      ]

      resource = create_resource(:users, routes)
      config = Configuration.new(style: :resource, variant: :rich)
      file = ResourceTypeScript.generate_resource_file(resource, config)

      # Should export actions individually for tree-shaking
      assert file.content =~ ~r/export\s*\{.*index/
      assert file.content =~ ~r/export\s*\{.*show/
    end

    test "uses reserved words as property names in exported object" do
      routes = [
        route("new_user_path", :GET, "/users/new"),
        route("delete_user_path", :DELETE, "/users/:id")
      ]

      resource = create_resource(:users, routes)
      config = Configuration.new(style: :resource, variant: :rich)
      file = ResourceTypeScript.generate_resource_file(resource, config)

      # Variable declarations need escaped names (const new_ = ...)
      # But object properties can use clean names (users.new, users.delete)
      assert file.content =~ ~r/const new_ = route/
      assert file.content =~ ~r/const delete_ = route/

      # Object literal uses clean property names with aliasing
      assert file.content =~ ~r/new:\s*new_/
      assert file.content =~ ~r/delete:\s*delete_/
    end

    test "generates JSDoc comments" do
      routes = [
        route("users_path", :GET, "/users")
      ]

      resource = create_resource(:users, routes)
      config = Configuration.new(style: :resource, variant: :rich, documentation: true)
      file = ResourceTypeScript.generate_resource_file(resource, config)

      assert file.content =~ "/**"
      assert file.content =~ "GET /users"
      assert file.content =~ "*/"
    end
  end

  describe "generate_index/2" do
    test "generates barrel file with exports" do
      routes = [
        route("users_path", :GET, "/users"),
        route("posts_path", :GET, "/posts")
      ]

      config = Configuration.new(style: :resource, variant: :rich)
      resources = ResourceGenerator.group_routes_by_resource(routes, config)
      file = ResourceTypeScript.generate_index(resources, config)

      assert file.path == "index.ts"
      assert file.content =~ "export { users }"
      assert file.content =~ "export { posts }"
    end

    test "handles scoped resources in index" do
      routes = [
        route("admin_users_path", :GET, "/admin/users"),
        route("users_path", :GET, "/users")
      ]

      config = Configuration.new(style: :resource, variant: :rich)
      resources = ResourceGenerator.group_routes_by_resource(routes, config)
      file = ResourceTypeScript.generate_index(resources, config)

      # Should export both regular and scoped resources
      assert file.content =~ "users"
      assert file.content =~ "admin"
    end

    test "exports runtime types" do
      routes = []
      config = Configuration.new(style: :resource, variant: :rich)
      resources = ResourceGenerator.group_routes_by_resource(routes, config)
      file = ResourceTypeScript.generate_index(resources, config)

      assert file.content =~ "Route"
      assert file.content =~ "RouteOptions"
    end
  end

  describe "generate_scoped_index/2" do
    test "generates index for scoped resources" do
      routes = [
        route("admin_users_path", :GET, "/admin/users"),
        route("admin_settings_path", :GET, "/admin/settings")
      ]

      config = Configuration.new(style: :resource, variant: :rich)
      resources = ResourceGenerator.group_routes_by_resource(routes, config)

      admin_resources = Enum.filter(resources, fn r -> List.first(r.key) == :admin end)
      file = ResourceTypeScript.generate_scoped_index([:admin], admin_resources, config)

      assert file.path == "admin/index.ts"
      assert file.content =~ "users"
      assert file.content =~ "settings"
    end
  end

  describe "render_action/2" do
    test "renders action without parameters" do
      action = %{
        name: :index,
        route: route("users_path", :GET, "/users"),
        verb: :GET,
        path: "/users",
        params: []
      }

      config = Configuration.new(style: :resource, variant: :rich)
      content = ResourceTypeScript.render_action(action, config)

      assert content =~ "index"
      assert content =~ "route("
      assert content =~ "'/users'"
      assert content =~ "'get'"
    end

    test "renders action with required parameters" do
      action = %{
        name: :show,
        route: route("user_path", :GET, "/users/:id"),
        verb: :GET,
        path: "/users/:id",
        params: [%{name: "id", required: true}]
      }

      config = Configuration.new(style: :resource, variant: :rich)
      content = ResourceTypeScript.render_action(action, config)

      assert content =~ "show"
      assert content =~ "route<"
      assert content =~ "id"
      assert content =~ "Param"
    end

    test "renders action with multiple parameters" do
      action = %{
        name: :show,
        route: route("post_comment_path", :GET, "/posts/:post_id/comments/:id"),
        verb: :GET,
        path: "/posts/:post_id/comments/:id",
        params: [%{name: "post_id", required: true}, %{name: "id", required: true}]
      }

      config = Configuration.new(style: :resource, variant: :rich)
      content = ResourceTypeScript.render_action(action, config)

      assert content =~ "post_id"
      assert content =~ "id"
    end
  end

  describe "safe_js_name/1" do
    test "returns name as-is for non-reserved words" do
      assert ResourceTypeScript.safe_js_name(:index) == "index"
      assert ResourceTypeScript.safe_js_name(:show) == "show"
      assert ResourceTypeScript.safe_js_name(:create) == "create"
    end

    # Reserved words need escaping for variable declarations (const new = ...)
    # but can be used as property names (users.new)
    test "escapes 'new' for variable declaration" do
      assert ResourceTypeScript.safe_js_name(:new) == "new_"
    end

    test "escapes 'delete' for variable declaration" do
      assert ResourceTypeScript.safe_js_name(:delete) == "delete_"
    end

    test "escapes 'class' for variable declaration" do
      assert ResourceTypeScript.safe_js_name(:class) == "class_"
    end

    test "escapes 'import' for variable declaration" do
      assert ResourceTypeScript.safe_js_name(:import) == "import_"
    end

    test "escapes 'export' for variable declaration" do
      assert ResourceTypeScript.safe_js_name(:export) == "export_"
    end
  end

  describe "is_reserved_word?/1" do
    test "identifies reserved words" do
      assert ResourceTypeScript.is_reserved_word?("new")
      assert ResourceTypeScript.is_reserved_word?("delete")
      assert ResourceTypeScript.is_reserved_word?("class")
    end

    test "non-reserved words return false" do
      refute ResourceTypeScript.is_reserved_word?("index")
      refute ResourceTypeScript.is_reserved_word?("show")
      refute ResourceTypeScript.is_reserved_word?("users")
    end
  end
end
