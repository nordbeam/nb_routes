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
      # New resource mode defaults
      assert config.style == :classic
      assert config.output_dir == "assets/js/routes"
      assert config.include_live == true
      assert config.include_index == true
      assert config.group_by == :resource
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

    test "creates resource mode configuration" do
      config =
        Configuration.new(
          style: :resource,
          output_dir: "assets/js/custom",
          include_live: false,
          include_index: false,
          group_by: :scope
        )

      assert config.style == :resource
      assert config.output_dir == "assets/js/custom"
      assert config.include_live == false
      assert config.include_index == false
      assert config.group_by == :scope
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

    test "rejects invalid style" do
      config = %Configuration{style: :invalid}
      assert {:error, msg} = Configuration.validate(config)
      assert msg =~ "Invalid style"
    end

    test "accepts valid style :classic" do
      config = %Configuration{style: :classic}
      assert Configuration.validate(config) == :ok
    end

    test "accepts valid style :resource" do
      config = %Configuration{style: :resource}
      assert Configuration.validate(config) == :ok
    end

    test "rejects invalid group_by" do
      config = %Configuration{group_by: :invalid}
      assert {:error, msg} = Configuration.validate(config)
      assert msg =~ "Invalid group_by"
    end

    test "accepts valid group_by options" do
      assert Configuration.validate(%Configuration{group_by: :resource}) == :ok
      assert Configuration.validate(%Configuration{group_by: :scope}) == :ok
      assert Configuration.validate(%Configuration{group_by: :controller}) == :ok
    end
  end

  describe "resource mode helpers" do
    test "is_resource_mode?/1 returns true for resource style" do
      config = Configuration.new(style: :resource)
      assert Configuration.is_resource_mode?(config) == true
    end

    test "is_resource_mode?/1 returns false for classic style" do
      config = Configuration.new(style: :classic)
      assert Configuration.is_resource_mode?(config) == false
    end
  end
end
