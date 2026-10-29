require "./spec_helper"
require "yaml"

describe "CRShader Reusable Lapis Addon CI Workflow" do
  it "delegates CI execution to sol-vin/lapis/.github/workflows/build-addon.yml@4.8-beta1" do
    workflow_path = File.expand_path("../.github/workflows/ci.yml", __DIR__)
    File.exists?(workflow_path).should be_true

    content = File.read(workflow_path)
    parsed = YAML.parse(content)

    jobs = parsed["jobs"].as_h
    job = jobs[YAML::Any.new("crshader-addon-ci")].as_h
    job[YAML::Any.new("uses")].as_s.should eq("sol-vin/lapis/.github/workflows/build-addon.yml@4.8-beta1")

    with_params = job[YAML::Any.new("with")].as_h
    with_params[YAML::Any.new("addon-name")].as_s.should eq("crshader")
    with_params[YAML::Any.new("lapis-ref")].as_s.should eq("4.8-beta1")
    with_params[YAML::Any.new("godot-version")].as_s.should eq("4.8-beta1")
    with_params[YAML::Any.new("run-specs")].as_bool.should be_true
    with_params[YAML::Any.new("run-headless")].as_bool.should be_true
  end
end
