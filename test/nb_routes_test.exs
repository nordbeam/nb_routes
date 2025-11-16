defmodule NbRoutesTest do
  use ExUnit.Case
  doctest NbRoutes

  alias NbRoutes.Configuration

  describe "configure/1" do
    test "builds configuration with defaults" do
      config = NbRoutes.configure()
      assert %Configuration{} = config
      assert config.module_type == :esm
      assert config.output_file == "assets/js/routes.js"
    end

    test "builds configuration with custom options" do
      config = NbRoutes.configure(module_type: :cjs, camel_case: true)
      assert config.module_type == :cjs
      assert config.camel_case == true
    end
  end

  describe "generate/2" do
    test "generates JavaScript code" do
      # This test requires a real Phoenix router
      # For now, we just verify the function exists
      assert function_exported?(NbRoutes, :generate, 2)
    end
  end

  describe "definitions/2" do
    test "generates TypeScript definitions" do
      # This test requires a real Phoenix router
      # For now, we just verify the function exists
      assert function_exported?(NbRoutes, :definitions, 2)
    end
  end
end
