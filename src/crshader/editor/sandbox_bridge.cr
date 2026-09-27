module CrShader
  # =============================================================================
  # SandboxBridge - Cross-App State Transfer
  # =============================================================================
  # Allows seamless transitions between the Showcase Viewer and the Live Sandbox.
  # When inspecting any shader preset in the Viewer, clicking "⚡ Edit in Sandbox"
  # transfers the shader's active source code and title to the Sandbox environment.
  class SandboxBridge
    @@pending_source : String? = nil
    @@pending_title : String? = nil
    @@from_viewer : Bool = false

    def self.send_to_sandbox(source : String, title : String = "Shader") : Void
      @@pending_source = source
      @@pending_title = title
      @@from_viewer = true
    end

    def self.has_pending? : Bool
      !@@pending_source.nil?
    end

    def self.consume_pending : Tuple(String?, String?)
      src = @@pending_source
      title = @@pending_title
      @@pending_source = nil
      @@pending_title = nil
      {src, title}
    end

    def self.from_viewer? : Bool
      @@from_viewer
    end

    def self.clear : Void
      @@pending_source = nil
      @@pending_title = nil
      @@from_viewer = false
    end
  end
end
