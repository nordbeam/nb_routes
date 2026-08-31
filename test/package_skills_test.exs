defmodule NbRoutes.PackageSkillsTest do
  use ExUnit.Case, async: true

  @package_root Path.expand("..", __DIR__)
  @skill_dir Path.join(@package_root, "usage-rules/skills/nb-routes")

  test "ships the prebuilt skill in the usage_rules layout" do
    assert File.regular?(Path.join(@skill_dir, "SKILL.md"))
    assert File.regular?(Path.join(@skill_dir, "agents/openai.yaml"))
    refute File.exists?(Path.join(@package_root, "skills/nb-routes/SKILL.md"))
  end

  test "documents package skill synchronization" do
    mix_exs = File.read!(Path.join(@package_root, "mix.exs"))
    readme = File.read!(Path.join(@package_root, "README.md"))

    assert mix_exs =~ "usage-rules.md"
    assert mix_exs =~ "usage-rules"
    assert readme =~ "mix igniter.install usage_rules"
    assert readme =~ "location: \".agents/skills\""
    assert readme =~ "package_skills: [:nb_routes]"
    assert readme =~ "mix usage_rules.sync"
  end
end
