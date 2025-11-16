defmodule NbRoutes.RouteTest do
  use ExUnit.Case
  doctest NbRoutes.Route

  alias NbRoutes.Route

  describe "generate_name/2" do
    test "generates standard path name" do
      assert Route.generate_name("user", []) == "user_path"
    end

    test "generates compact name" do
      assert Route.generate_name("user", compact: true) == "user"
    end

    test "generates camelCase name" do
      assert Route.generate_name("user", camel_case: true) == "userPath"
    end

    test "generates compact camelCase name" do
      assert Route.generate_name("user", compact: true, camel_case: true) == "user"
    end

    test "converts multi-word names to camelCase" do
      assert Route.generate_name("user_posts", camel_case: true) == "userPostsPath"
    end
  end

  describe "generate_url_name/2" do
    test "generates URL helper name" do
      assert Route.generate_url_name("user", []) == "user_url"
    end

    test "generates camelCase URL helper name" do
      assert Route.generate_url_name("user", camel_case: true) == "userUrl"
    end
  end
end
