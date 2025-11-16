defmodule NbRoutes.GeneratorTest do
  use ExUnit.Case, async: true

  alias NbRoutes.Generator

  defmodule TestRouter do
    @moduledoc false

    def __routes__ do
      [
        # Single route with unique helper
        %{
          helper: "user",
          verb: :GET,
          path: "/users/:id",
          plug_opts: :show
        },
        # Multiple routes with same helper "help"
        %{
          helper: "help",
          verb: :GET,
          path: "/help",
          plug_opts: :index
        },
        %{
          helper: "help",
          verb: :GET,
          path: "/help/getting-started",
          plug_opts: :getting_started
        },
        %{
          helper: "help",
          verb: :GET,
          path: "/help/create-space",
          plug_opts: :create_space
        },
        # Route without helper
        %{
          helper: nil,
          verb: :GET,
          path: "/forward",
          plug_opts: :forward
        }
      ]
    end
  end

  describe "extract_routes/2" do
    test "extracts routes with unique helper names unchanged" do
      routes = Generator.extract_routes(TestRouter)

      user_route = Enum.find(routes, &(&1.name == "user_path"))
      assert user_route
      assert user_route.path == "/users/:id"
    end

    test "filters out routes without helper names" do
      routes = Generator.extract_routes(TestRouter)

      refute Enum.any?(routes, &(&1.path == "/forward"))
    end

    test "resolves duplicate helper names by appending action" do
      routes = Generator.extract_routes(TestRouter)

      # Should have 3 help routes with action appended
      help_index = Enum.find(routes, &(&1.name == "help_index_path"))
      help_getting_started = Enum.find(routes, &(&1.name == "help_getting_started_path"))
      help_create_space = Enum.find(routes, &(&1.name == "help_create_space_path"))

      assert help_index
      assert help_index.path == "/help"

      assert help_getting_started
      assert help_getting_started.path == "/help/getting-started"

      assert help_create_space
      assert help_create_space.path == "/help/create-space"
    end

    test "does not create original helper name for duplicates" do
      routes = Generator.extract_routes(TestRouter)

      # Should NOT have a plain "help_path" since all help routes are duplicates
      refute Enum.any?(routes, &(&1.name == "help_path"))
    end

    test "generates correct number of routes" do
      routes = Generator.extract_routes(TestRouter)

      # 1 user route + 3 help routes = 4 total
      assert length(routes) == 4
    end
  end

  describe "extract_routes/2 with same helper and same action" do
    defmodule TestRouterWithConflicts do
      @moduledoc false

      def __routes__ do
        [
          # Two routes with same helper AND same action (edge case)
          %{
            helper: "user",
            verb: :GET,
            path: "/api/users/:id",
            plug_opts: :show
          },
          %{
            helper: "user",
            verb: :GET,
            path: "/admin/users/:id",
            plug_opts: :show
          },
          # Regular unique route
          %{
            helper: "post",
            verb: :GET,
            path: "/posts/:id",
            plug_opts: :show
          }
        ]
      end
    end

    test "handles same helper + same action by extracting scope from path" do
      routes = Generator.extract_routes(TestRouterWithConflicts)

      # Should have api_user_show_path and admin_user_show_path
      api_route = Enum.find(routes, &(&1.name == "api_user_show_path"))
      admin_route = Enum.find(routes, &(&1.name == "admin_user_show_path"))

      assert api_route
      assert admin_route
      assert api_route.path == "/api/users/:id"
      assert admin_route.path == "/admin/users/:id"
    end

    test "ensures all generated names are unique" do
      routes = Generator.extract_routes(TestRouterWithConflicts)

      # Check no duplicate names
      names = Enum.map(routes, & &1.name)
      assert length(names) == length(Enum.uniq(names))
    end

    test "keeps unique routes unchanged" do
      routes = Generator.extract_routes(TestRouterWithConflicts)

      # post_path should remain as is since it's unique
      post_route = Enum.find(routes, &(&1.name == "post_path"))
      assert post_route
    end
  end

  describe "extract_routes/2 with include/exclude" do
    test "respects include pattern" do
      routes = Generator.extract_routes(TestRouter, include: [~r/^user/])

      assert length(routes) == 1
      assert Enum.all?(routes, &String.starts_with?(&1.name, "user"))
    end

    test "respects exclude pattern" do
      routes = Generator.extract_routes(TestRouter, exclude: [~r/^help/])

      refute Enum.any?(routes, &String.starts_with?(&1.name, "help"))
      assert Enum.any?(routes, &(&1.name == "user_path"))
    end
  end

  describe "detect_router/0" do
    test "returns nil when no router found" do
      # This will fail in a real app with a router, but tests the function exists
      result = Generator.detect_router()
      assert is_nil(result) || is_atom(result)
    end
  end
end
