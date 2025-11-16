defmodule NbRoutes.CodeGeneratorTest do
  use ExUnit.Case
  doctest NbRoutes.CodeGenerator

  alias NbRoutes.{CodeGenerator, Configuration, Route}

  describe "generate/2 with simple mode" do
    test "generates simple route helpers" do
      routes = [
        %Route{
          name: "users_path",
          verb: :GET,
          path: "/users",
          segments: ["/users"],
          required_params: [],
          optional_params: []
        }
      ]

      config = %Configuration{variant: :simple}
      code = CodeGenerator.generate(routes, config)

      assert code =~ "const users_path = /*#__PURE__*/ _builder.route("
      refute code =~ "const users_path = Object.assign("
      refute code =~ "function _buildUrl"
    end

    test "generates route with parameters" do
      routes = [
        %Route{
          name: "user_path",
          verb: :GET,
          path: "/users/:id",
          segments: ["/users/", :id],
          required_params: ["id"],
          optional_params: []
        }
      ]

      config = %Configuration{variant: :simple}
      code = CodeGenerator.generate(routes, config)

      assert code =~ "const user_path = /*#__PURE__*/ _builder.route("
      # Simple mode uses _builder.route, not the params directly in the helper
      refute code =~ "const user_path = Object.assign("
    end
  end

  describe "generate/2 with rich mode" do
    test "generates Object.assign pattern" do
      routes = [
        %Route{
          name: "users_path",
          verb: :GET,
          path: "/users",
          segments: ["/users"],
          required_params: [],
          optional_params: []
        }
      ]

      config = %Configuration{variant: :rich, with_methods: true}
      code = CodeGenerator.generate(routes, config)

      assert code =~ "const users_path = Object.assign("
      assert code =~ "function(options)"
      assert code =~ ~s|return {\n      url: _buildUrl("/users", {}, options),|
      assert code =~ ~s|method: "get"|
    end

    test "generates route with parameters in rich mode" do
      routes = [
        %Route{
          name: "user_path",
          verb: :GET,
          path: "/users/:id",
          segments: ["/users/", :id],
          required_params: ["id"],
          optional_params: []
        }
      ]

      config = %Configuration{variant: :rich, with_methods: true}
      code = CodeGenerator.generate(routes, config)

      assert code =~ "const user_path = Object.assign("
      assert code =~ "function(id, options)"
      assert code =~ ~s|_buildUrl("/users/:id", { id }, options)|
      assert code =~ ~s|method: "get"|
    end

    test "generates method variants when with_methods is true" do
      routes = [
        %Route{
          name: "user_path",
          verb: :GET,
          path: "/users/:id",
          segments: ["/users/", :id],
          required_params: ["id"],
          optional_params: []
        }
      ]

      config = %Configuration{variant: :rich, with_methods: true}
      code = CodeGenerator.generate(routes, config)

      # Check for .get variant
      assert code =~ "get: function(id, options)"
      # Check for .head variant
      assert code =~ "head: function(id, options)"
      # Check for .url variant
      assert code =~ "url: function(id, options)"
      assert code =~ ~s|return _buildUrl("/users/:id", { id }, options);|
    end

    test "does not generate method variants when with_methods is false" do
      routes = [
        %Route{
          name: "user_path",
          verb: :GET,
          path: "/users/:id",
          segments: ["/users/", :id],
          required_params: ["id"],
          optional_params: []
        }
      ]

      config = %Configuration{variant: :rich, with_methods: false}
      code = CodeGenerator.generate(routes, config)

      assert code =~ "Object.assign("
      refute code =~ "get: function"
      refute code =~ "head: function"
    end

    test "includes _buildUrl helper in rich mode" do
      routes = [
        %Route{
          name: "users_path",
          verb: :GET,
          path: "/users",
          segments: ["/users"],
          required_params: [],
          optional_params: []
        }
      ]

      config = %Configuration{variant: :rich}
      code = CodeGenerator.generate(routes, config)

      assert code =~ "function _buildUrl(pattern, params = {}, options = {})"
      assert code =~ "Replace :param placeholders"
      assert code =~ "Handle query parameters"
      assert code =~ "Handle anchor"
    end

    test "generates correct method for POST routes" do
      routes = [
        %Route{
          name: "create_user_path",
          verb: :POST,
          path: "/users",
          segments: ["/users"],
          required_params: [],
          optional_params: []
        }
      ]

      config = %Configuration{variant: :rich, with_methods: true}
      code = CodeGenerator.generate(routes, config)

      # Main function should have POST method
      assert code =~ ~s|method: "post"|
      # Should have .post variant
      assert code =~ "post: function(options)"
    end

    test "generates correct method for PATCH routes" do
      routes = [
        %Route{
          name: "update_user_path",
          verb: :PATCH,
          path: "/users/:id",
          segments: ["/users/", :id],
          required_params: ["id"],
          optional_params: []
        }
      ]

      config = %Configuration{variant: :rich, with_methods: true}
      code = CodeGenerator.generate(routes, config)

      # Main function should have PATCH method
      assert code =~ ~s|method: "patch"|
      # Should have .patch variant
      assert code =~ "patch: function(id, options)"
    end

    test "exports _buildUrl and visitRoute in ESM mode" do
      routes = []
      config = %Configuration{variant: :rich, module_type: :esm}
      code = CodeGenerator.generate(routes, config)

      assert code =~ "export { _buildUrl, visitRoute };"
    end

    test "does not export _buildUrl in simple mode" do
      routes = []
      config = %Configuration{variant: :simple, module_type: :esm}
      code = CodeGenerator.generate(routes, config)

      refute code =~ "export { _buildUrl };"
    end
  end

  describe "generate/2 with multiple parameters" do
    test "generates routes with multiple required params in rich mode" do
      routes = [
        %Route{
          name: "user_post_path",
          verb: :GET,
          path: "/users/:user_id/posts/:id",
          segments: ["/users/", :user_id, "/posts/", :id],
          required_params: ["user_id", "id"],
          optional_params: []
        }
      ]

      config = %Configuration{variant: :rich}
      code = CodeGenerator.generate(routes, config)

      assert code =~ "function(user_id, id, options)"
      assert code =~ ~s|_buildUrl("/users/:user_id/posts/:id", { user_id, id }, options)|
    end
  end

  describe "generate/2 with forms enabled" do
    test "generates form helpers for mutation routes" do
      routes = [
        %Route{
          name: "update_user_path",
          verb: :PATCH,
          path: "/users/:id",
          segments: ["/users/", :id],
          required_params: ["id"],
          optional_params: []
        }
      ]

      config = %Configuration{variant: :rich, with_forms: true}
      code = CodeGenerator.generate(routes, config)

      # Should have .form property
      assert code =~ "form: Object.assign("

      # Should have main form function
      assert code =~ ~s|action: _buildFormAction("/users/:id", { id }, "patch", options)|
      assert code =~ ~s|method: "post"|

      # Should have method-specific form variants
      assert code =~ "patch: function(id, options)"
      assert code =~ "put: function(id, options)"
      assert code =~ "delete: function(id, options)"
    end

    test "does not generate form helpers for GET routes" do
      routes = [
        %Route{
          name: "user_path",
          verb: :GET,
          path: "/users/:id",
          segments: ["/users/", :id],
          required_params: ["id"],
          optional_params: []
        }
      ]

      config = %Configuration{variant: :rich, with_forms: true}
      code = CodeGenerator.generate(routes, config)

      # GET routes should not have .form property
      refute code =~ "form: Object.assign("
      # But _buildFormAction helper is still included in runtime for other routes
      assert code =~ "function _buildFormAction"
    end

    test "generates form helpers for POST routes" do
      routes = [
        %Route{
          name: "create_user_path",
          verb: :POST,
          path: "/users",
          segments: ["/users"],
          required_params: [],
          optional_params: []
        }
      ]

      config = %Configuration{variant: :rich, with_forms: true}
      code = CodeGenerator.generate(routes, config)

      assert code =~ "form: Object.assign("
      assert code =~ ~s|action: _buildFormAction("/users", {}, "post", options)|
    end

    test "includes _buildFormAction helper when forms enabled" do
      routes = [
        %Route{
          name: "update_user_path",
          verb: :PATCH,
          path: "/users/:id",
          segments: ["/users/", :id],
          required_params: ["id"],
          optional_params: []
        }
      ]

      config = %Configuration{variant: :rich, with_forms: true}
      code = CodeGenerator.generate(routes, config)

      assert code =~
               "function _buildFormAction(pattern, params = {}, method = 'post', options = {})"

      assert code =~ "Method spoofing for non-GET/POST methods"
      assert code =~ "_method="
    end

    test "does not include _buildFormAction when forms disabled" do
      routes = [
        %Route{
          name: "update_user_path",
          verb: :PATCH,
          path: "/users/:id",
          segments: ["/users/", :id],
          required_params: ["id"],
          optional_params: []
        }
      ]

      config = %Configuration{variant: :rich, with_forms: false}
      code = CodeGenerator.generate(routes, config)

      refute code =~ "function _buildFormAction"
      refute code =~ "form: Object.assign("
    end
  end
end
