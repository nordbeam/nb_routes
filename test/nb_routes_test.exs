defmodule NbRoutesTest do
  use ExUnit.Case
  doctest NbRoutes

  alias NbRoutes.Configuration

  defmodule ResourceRouter do
    @moduledoc false

    def __routes__ do
      [
        %{helper: "user", verb: :GET, path: "/users/:id", plug_opts: :show}
      ]
    end
  end

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

    test "resource generation removes stale generated modules" do
      output_dir =
        Path.join(System.tmp_dir!(), "nb_routes_resource_#{System.unique_integer([:positive])}")

      on_exit(fn -> File.rm_rf!(output_dir) end)
      File.mkdir_p!(output_dir)
      File.write!(Path.join(output_dir, "stale.ts"), "export const stale = true;\n")

      written = NbRoutes.generate!(output_dir, ResourceRouter, style: :resource)

      refute File.exists?(Path.join(output_dir, "stale.ts"))
      assert Path.join(output_dir, "users.ts") in written
      assert File.exists?(Path.join(output_dir, "users.ts"))
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
