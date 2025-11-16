defmodule NbRoutes.SerializerTest do
  use ExUnit.Case
  doctest NbRoutes.Serializer

  alias NbRoutes.{Route, Serializer}

  describe "serialize/1" do
    test "serializes static route" do
      route = %Route{
        name: "users_path",
        verb: :GET,
        path: "/users",
        segments: ["/users/"],
        required_params: [],
        optional_params: []
      }

      assert Serializer.serialize(route) == ["/users/"]
    end

    test "serializes route with required parameter" do
      route = %Route{
        name: "user_path",
        verb: :GET,
        path: "/users/:id",
        segments: ["/users/", :id],
        required_params: ["id"],
        optional_params: []
      }

      assert Serializer.serialize(route) == ["/users/", [:param, "id"]]
    end

    test "serializes route with optional parameter" do
      route = %Route{
        name: "users_path",
        verb: :GET,
        path: "/users(.:format)",
        segments: ["/users", {:optional, [".", :format]}],
        required_params: [],
        optional_params: ["format"]
      }

      assert Serializer.serialize(route) == ["/users", [:optional, [".", [:param, "format"]]]]
    end

    test "serializes route with glob parameter" do
      route = %Route{
        name: "static_path",
        verb: :GET,
        path: "/*path",
        segments: [{:glob, :path}],
        required_params: ["path"],
        optional_params: []
      }

      assert Serializer.serialize(route) == [[:glob, "path"]]
    end
  end

  describe "serialize_params/1" do
    test "serializes required parameters" do
      route = %Route{
        name: "user_path",
        verb: :GET,
        path: "/users/:id",
        segments: [],
        required_params: ["id"],
        optional_params: [],
        defaults: %{}
      }

      assert Serializer.serialize_params(route) == %{
               "id" => %{required: true}
             }
    end

    test "serializes optional parameters" do
      route = %Route{
        name: "users_path",
        verb: :GET,
        path: "/users(.:format)",
        segments: [],
        required_params: [],
        optional_params: ["format"],
        defaults: %{}
      }

      assert Serializer.serialize_params(route) == %{
               "format" => %{}
             }
    end

    test "serializes optional parameters with defaults" do
      route = %Route{
        name: "users_path",
        verb: :GET,
        path: "/users(.:format)",
        segments: [],
        required_params: [],
        optional_params: ["format"],
        defaults: %{"format" => "json"}
      }

      assert Serializer.serialize_params(route) == %{
               "format" => %{default: "json"}
             }
    end

    test "serializes mixed required and optional parameters" do
      route = %Route{
        name: "user_posts_path",
        verb: :GET,
        path: "/users/:user_id/posts(.:format)",
        segments: [],
        required_params: ["user_id"],
        optional_params: ["format"],
        defaults: %{}
      }

      params = Serializer.serialize_params(route)
      assert params["user_id"] == %{required: true}
      assert params["format"] == %{}
    end
  end
end
