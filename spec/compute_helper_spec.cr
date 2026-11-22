require "./spec_helper"
require "../src/crshader/compute/compute_helper"

describe "CrShader::ComputeHelper" do
  it "initializes without errors when RenderingDevice is nil" do
    helper = CrShader::ComputeHelper.new(nil)
    helper.shader_rid.should eq(0_i64)
    helper.pipeline_rid.should eq(0_i64)
    helper.uniform_set_dirty.should be_true
  end

  it "tracks image, sampler+texture, texture, UBO, and storage buffer bindings with Godot 4 UniformType IDs" do
    helper = CrShader::ComputeHelper.new(nil)
    helper.bind_image(0, 1001_i64)
    helper.bind_texture(1, 1002_i64)
    helper.bind_storage_buffer(2, 1003_i64)
    helper.bind_sampler_with_texture(3, 1004_i64, linear: false)
    helper.bind_uniform_buffer(0, 1005_i64, set_index: 1)
    helper.set_push_constant(Bytes[1_u8, 2_u8, 3_u8, 4_u8])

    helper.bindings.size.should eq(4)
    helper.bindings[0].rid.should eq(1001_i64)
    helper.bindings[0].uniform_type.should eq(3) # UNIFORM_TYPE_IMAGE
    helper.bindings[1].rid.should eq(1002_i64)
    helper.bindings[1].uniform_type.should eq(2) # UNIFORM_TYPE_TEXTURE
    helper.bindings[2].rid.should eq(1003_i64)
    helper.bindings[2].uniform_type.should eq(8) # UNIFORM_TYPE_STORAGE_BUFFER
    helper.bindings[3].rid.should eq(1004_i64)
    helper.bindings[3].uniform_type.should eq(1) # UNIFORM_TYPE_SAMPLER_WITH_TEXTURE

    helper.set_bindings[1][0].rid.should eq(1005_i64)
    helper.set_bindings[1][0].uniform_type.should eq(7)  # UNIFORM_TYPE_UNIFORM_BUFFER
    helper.push_constant_bytes.try(&.size).should eq(16) # Aligned to 16 bytes for Vulkan

    helper.uniform_set_dirty.should be_true
  end

  it "avoids marking uniform set dirty on redundant identical bindings" do
    helper = CrShader::ComputeHelper.new(nil)
    helper.bind_image(0, 5001_i64)
    helper.uniform_set_dirty = false

    # Binding the same RID again shouldn't re-dirty
    helper.bind_image(0, 5001_i64)
    helper.uniform_set_dirty.should be_false

    # Binding a different RID must dirty
    helper.bind_image(0, 5002_i64)
    helper.uniform_set_dirty.should be_true
  end

  it "calculates correct workgroup divisions" do
    # 1920x1080 with 8x8 workgroups
    width = 1920
    height = 1080
    local_x = 8
    local_y = 8

    groups_x = (width + local_x - 1) // local_x
    groups_y = (height + local_y - 1) // local_y

    groups_x.should eq(240)
    groups_y.should eq(135)

    # 1921x1081 with 8x8 workgroups requires +1 group on edges
    width2 = 1921
    height2 = 1081
    groups_x2 = (width2 + local_x - 1) // local_x
    groups_y2 = (height2 + local_y - 1) // local_y

    groups_x2.should eq(241)
    groups_y2.should eq(136)
  end
end
