defmodule NbRoutes.ResourceGeneratorTest do
  use ExUnit.Case

  alias NbRoutes.{Configuration, Route, ResourceGenerator}

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

  # Simple segment parser for tests
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

  describe "group_routes_by_resource/2" do
    test "groups routes by resource name from helper" do
      routes = [
        route("users_path", :GET, "/users"),
        route("user_path", :GET, "/users/:id"),
        route("create_user_path", :POST, "/users"),
        route("posts_path", :GET, "/posts"),
        route("post_path", :GET, "/posts/:id")
      ]

      config = Configuration.new(style: :resource)
      resources = ResourceGenerator.group_routes_by_resource(routes, config)

      assert length(resources) == 2

      users_resource = Enum.find(resources, &(&1.name == :users))
      posts_resource = Enum.find(resources, &(&1.name == :posts))

      assert users_resource != nil
      assert posts_resource != nil

      assert length(users_resource.actions) == 3
      assert length(posts_resource.actions) == 2
    end

    test "extracts action names from routes" do
      routes = [
        route("users_path", :GET, "/users"),
        route("new_user_path", :GET, "/users/new"),
        route("create_user_path", :POST, "/users"),
        route("user_path", :GET, "/users/:id"),
        route("edit_user_path", :GET, "/users/:id/edit"),
        route("update_user_path", :PATCH, "/users/:id"),
        route("delete_user_path", :DELETE, "/users/:id")
      ]

      config = Configuration.new(style: :resource)
      resources = ResourceGenerator.group_routes_by_resource(routes, config)

      users_resource = Enum.find(resources, &(&1.name == :users))

      action_names = Enum.map(users_resource.actions, & &1.name)
      assert :index in action_names
      assert :new in action_names
      assert :create in action_names
      assert :show in action_names
      assert :edit in action_names
      assert :update in action_names
      assert :delete in action_names
    end

    test "handles scoped routes under admin" do
      routes = [
        route("admin_users_path", :GET, "/admin/users"),
        route("admin_user_path", :GET, "/admin/users/:id"),
        route("users_path", :GET, "/users"),
        route("user_path", :GET, "/users/:id")
      ]

      config = Configuration.new(style: :resource)
      resources = ResourceGenerator.group_routes_by_resource(routes, config)

      # Should have admin.users and users as separate resources
      resource_keys = Enum.map(resources, & &1.key)
      assert [:admin, :users] in resource_keys
      assert [:users] in resource_keys
    end

    test "handles API versioned routes" do
      routes = [
        route("api_v1_products_path", :GET, "/api/v1/products"),
        route("api_v1_product_path", :GET, "/api/v1/products/:id"),
        route("api_v2_products_path", :GET, "/api/v2/products")
      ]

      config = Configuration.new(style: :resource)
      resources = ResourceGenerator.group_routes_by_resource(routes, config)

      resource_keys = Enum.map(resources, & &1.key)
      assert [:api, :v1, :products] in resource_keys
      assert [:api, :v2, :products] in resource_keys
    end

    test "handles nested resources" do
      routes = [
        route("post_comments_path", :GET, "/posts/:post_id/comments"),
        route("post_comment_path", :GET, "/posts/:post_id/comments/:id")
      ]

      config = Configuration.new(style: :resource)
      resources = ResourceGenerator.group_routes_by_resource(routes, config)

      # Nested resources should use the last part as resource name
      resource_names = Enum.map(resources, & &1.name)
      assert :comments in resource_names or :post_comments in resource_names
    end
  end

  describe "infer_action_name/1" do
    test "infers :index for collection GET routes" do
      route = route("users_path", :GET, "/users")
      assert ResourceGenerator.infer_action_name(route) == :index
    end

    test "infers :show for member GET routes" do
      route = route("user_path", :GET, "/users/:id")
      assert ResourceGenerator.infer_action_name(route) == :show
    end

    test "infers :new from helper name" do
      route = route("new_user_path", :GET, "/users/new")
      assert ResourceGenerator.infer_action_name(route) == :new
    end

    test "infers :edit from helper name" do
      route = route("edit_user_path", :GET, "/users/:id/edit")
      assert ResourceGenerator.infer_action_name(route) == :edit
    end

    test "infers :create for POST routes" do
      route = route("create_user_path", :POST, "/users")
      assert ResourceGenerator.infer_action_name(route) == :create
    end

    test "infers :update for PATCH routes" do
      route = route("update_user_path", :PATCH, "/users/:id")
      assert ResourceGenerator.infer_action_name(route) == :update
    end

    test "infers :update for PUT routes" do
      route = route("update_user_path", :PUT, "/users/:id")
      assert ResourceGenerator.infer_action_name(route) == :update
    end

    test "infers :delete for DELETE routes" do
      route = route("delete_user_path", :DELETE, "/users/:id")
      assert ResourceGenerator.infer_action_name(route) == :delete
    end
  end

  describe "resource_key_from_helper/1" do
    test "extracts resource from simple helper" do
      route = route("users_path", :GET, "/users")
      assert ResourceGenerator.resource_key_from_helper(route) == [:users]
    end

    test "extracts resource from singular helper" do
      route = route("user_path", :GET, "/users/:id")
      assert ResourceGenerator.resource_key_from_helper(route) == [:users]
    end

    test "handles scoped helpers" do
      route = route("admin_users_path", :GET, "/admin/users")
      assert ResourceGenerator.resource_key_from_helper(route) == [:admin, :users]
    end

    test "handles nested resource helpers" do
      route = route("post_comments_path", :GET, "/posts/:post_id/comments")
      key = ResourceGenerator.resource_key_from_helper(route)
      assert key == [:posts, :comments] or key == [:post_comments]
    end
  end

  describe "generate/2" do
    test "generates file list in resource mode" do
      routes = [
        route("users_path", :GET, "/users"),
        route("user_path", :GET, "/users/:id")
      ]

      config = Configuration.new(style: :resource, variant: :rich)
      result = ResourceGenerator.generate(routes, config)

      assert is_list(result)

      assert Enum.all?(result, fn file ->
               is_map(file) and Map.has_key?(file, :path) and Map.has_key?(file, :content)
             end)
    end

    test "generates runtime file" do
      routes = []
      config = Configuration.new(style: :resource, variant: :rich)
      result = ResourceGenerator.generate(routes, config)

      runtime_file = Enum.find(result, fn file -> file.path =~ "wayfinder.ts" end)
      assert runtime_file != nil
      assert runtime_file.content =~ "export function route"
    end

    test "generates resource files" do
      routes = [
        route("users_path", :GET, "/users"),
        route("user_path", :GET, "/users/:id")
      ]

      config = Configuration.new(style: :resource, variant: :rich)
      result = ResourceGenerator.generate(routes, config)

      users_file = Enum.find(result, fn file -> file.path =~ "users.ts" end)
      assert users_file != nil
      assert users_file.content =~ "export const users"
    end

    test "generates index file" do
      routes = [
        route("users_path", :GET, "/users"),
        route("posts_path", :GET, "/posts")
      ]

      config = Configuration.new(style: :resource, variant: :rich, include_index: true)
      result = ResourceGenerator.generate(routes, config)

      index_file = Enum.find(result, fn file -> file.path == "index.ts" end)
      assert index_file != nil
      assert index_file.content =~ "export { users }"
      assert index_file.content =~ "export { posts }"
    end
  end

  describe "generate_resource_path/1" do
    test "generates path for simple resource" do
      assert ResourceGenerator.generate_resource_path([:users]) == "users.ts"
    end

    test "generates path for scoped resource" do
      assert ResourceGenerator.generate_resource_path([:admin, :users]) == "admin/users.ts"
    end

    test "generates path for deeply nested resource" do
      assert ResourceGenerator.generate_resource_path([:api, :v1, :products]) ==
               "api/v1/products.ts"
    end
  end
end
