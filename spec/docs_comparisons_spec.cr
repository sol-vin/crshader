require "./spec_helper"
require "jasper"

describe "CrShader::Docs Side-by-Side Comparison Atlas" do
  atlas_path = File.expand_path("../docs_src/05_output_comparisons/01_side_by_side_comparisons.yml", __DIR__)

  it "validates the entire comparison atlas YAML and renders CommonMark-safe side-by-side HTML" do
    File.exists?(atlas_path).should be_true
    res = Jasper::Validator.validate_dir(File.expand_path("../docs_src", __DIR__))
    res.errors.should be_empty

    doc = Jasper::DocDocument.from_yaml(File.read(atlas_path))
    doc.id.should eq("A_SIDE_BY_SIDE_COMPARISONS")
    doc.sections.size.should eq(12)

    total_cards = 0
    doc.sections.each do |sec|
      cmps = sec.comparisons.should_not be_nil
      cmps.empty?.should be_false
      total_cards += cmps.size

      rendered = Jasper::ComparisonRenderer.render_to_doc_comments(cmps, indent_level: 4)
      rendered.should contain("class=\"jasper-comparison\"")

      # Verify CommonMark HTML block safety: no blank lines inside `<div class="jasper-comparison">`
      lines = rendered.lines
      in_div = false
      depth = 0
      lines.each do |line|
        body = line.sub(/^\s*#\s?/, "")
        if body.includes?("<div ")
          in_div = true
          depth += body.scan("<div ").size
        end
        if in_div
          body.empty?.should be_false
        end
        if body.includes?("</div>")
          depth -= body.scan("</div>").size
          in_div = false if depth <= 0
        end
      end
    end

    (total_cards >= 15).should be_true
  end

  it "compiles every standalone .crshader source column in the atlas without errors" do
    doc = Jasper::DocDocument.from_yaml(File.read(atlas_path))
    compiled_count = 0

    doc.sections.each do |sec|
      sec.comparisons.try &.each do |cmp|
        src_col = cmp.columns.first
        src_code = src_col.code

        # Split multi-snippet showcase columns (`# --- A: ... ---`) into individual compilable shaders
        snippets = if src_code.includes?("# --- ")
                     src_code.split(/^# --- [^\n]+ ---\n/m).reject(&.strip.empty?)
                   else
                     [src_code]
                   end

        snippets.each do |snippet|
          compiler = CrShader::Compiler.new
          out = compiler.compile_source(snippet, filename: "atlas_verify.crshader")
          out.strip.empty?.should be_false
          compiled_count += 1
        end
      end
    end

    (compiled_count >= 15).should be_true
  end
end
