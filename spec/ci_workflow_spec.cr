require "./spec_helper"
require "yaml"

describe "CRShader Addon CI Workflow" do
  it "validates multi-platform Addon CI matrix across Linux, Windows, and macOS" do
    workflow_path = File.expand_path("../.github/workflows/ci.yml", __DIR__)
    File.exists?(workflow_path).should be_true

    content = File.read(workflow_path)
    parsed = YAML.parse(content)

    jobs = parsed["jobs"].as_h
    job = jobs[YAML::Any.new("build-and-test")].as_h
    matrix = job[YAML::Any.new("strategy")].as_h[YAML::Any.new("matrix")].as_h[YAML::Any.new("include")].as_a
    matrix.size.should eq(3)
    content.includes?("4.8-beta2").should be_true
  end
end
