defmodule NbRoutes.ConfigurationTest do
  use ExUnit.Case
  doctest NbRoutes.Configuration

  alias NbRoutes.Configuration

  describe "new/1" do
    test "creates configuration with defaults" do
      config = Configuration.new()
      assert config.module_type == :esm
      assert config.output_file == "assets/js/routes.js"
      assert config.types_file == nil
      assert config.include == []
      assert config.exclude == []
      assert config.camel_case == false
      assert config.url_helpers == false
      assert config.compact == false
      assert config.default_url_options == %{}
      assert config.documentation == true
      assert config.router == nil
    end

    test "creates configuration with custom options" do
      config =
        Configuration.new(
          module_type: :cjs,
          output_file: "public/routes.js",
          camel_case: true
        )

      assert config.module_type == :cjs
      assert config.output_file == "public/routes.js"
      assert config.camel_case == true
    end
  end

  describe "merge/2" do
    test "merges options into existing configuration" do
      config = Configuration.new(module_type: :esm)
      merged = Configuration.merge(config, camel_case: true, compact: true)

      assert merged.module_type == :esm
      assert merged.camel_case == true
      assert merged.compact == true
    end
  end

  describe "types_file/1" do
    test "derives types file from output file when not set" do
      config = Configuration.new(output_file: "assets/js/routes.js")
      assert Configuration.types_file(config) == "assets/js/routes.d.ts"
    end

    test "uses explicit types file when set" do
      config = Configuration.new(types_file: "types/routes.d.ts")
      assert Configuration.types_file(config) == "types/routes.d.ts"
    end
  end

  describe "validate/1" do
    test "validates valid configuration" do
      config = Configuration.new()
      assert Configuration.validate(config) == :ok
    end

    test "rejects invalid module_type" do
      config = %Configuration{module_type: :invalid}
      assert {:error, msg} = Configuration.validate(config)
      assert msg =~ "Invalid module_type"
    end

    test "rejects non-list include" do
      config = %Configuration{include: "invalid"}
      assert {:error, msg} = Configuration.validate(config)
      assert msg =~ "must be a list"
    end

    test "rejects non-list exclude" do
      config = %Configuration{exclude: "invalid"}
      assert {:error, msg} = Configuration.validate(config)
      assert msg =~ "must be a list"
    end
  end
end
