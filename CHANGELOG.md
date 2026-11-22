# CARBON CHANGELOG
## [0.1.65] - 2026-11-21
### ✨ Features & Improvements
- ✦ **[DSL,STD]** add outline & artist stdlibs, shader builder, variant cache, gdshaderinc emitter, and spatial/compute interop ([`c5a4ee4`](https://github.com/sol-vin/crshader/commit/c5a4ee4))
- ✦ **[EDITOR]** add Godot 4.8 Shader Editor tab integration, emit_target multi-output compilation, and crshader/addon entrypoint ([`ad76bd8`](https://github.com/sol-vin/crshader/commit/ad76bd8))

### 🐛 Bug Fixes
- ✓ **[VALIDATOR]** allow source_color hint on Sampler2D and Vec3 uniforms in Spatial shaders ([`f00e5ac`](https://github.com/sol-vin/crshader/commit/f00e5ac))
- ✓ **[TRANSPILER]** deduplicate gdshaderinc helpers, fix setter/return ternaries, struct .color fields, and gdshaderinc varyings ([`f0a81e0`](https://github.com/sol-vin/crshader/commit/f0a81e0))
- ✓ **[GDSHADER]** emit varying before flat/smooth interpolation qualifier per Godot 4 grammar ([`975e249`](https://github.com/sol-vin/crshader/commit/975e249))
- ✓ **[PALETTES]** emit native Godot 4 flat PackedColorArray floats in ColorPalette .tres resources ([`401f4d4`](https://github.com/sol-vin/crshader/commit/401f4d4))
- ✓ **[EDITOR]** normalize Windows backslashes before Dir.glob in ShaderEditorIntegration ([`b33a928`](https://github.com/sol-vin/crshader/commit/b33a928))
- ✓ **[EDITOR]** prioritize explicit emit_target declarations before stem fallback in find_companion_crshader ([`3f37e6c`](https://github.com/sol-vin/crshader/commit/3f37e6c))

### 🛠️ Chores & Tooling
- • **[DEPS]** upgrade Lapis and Godot target to 4.8-beta1 (v0.1.11) ([`3a57bc2`](https://github.com/sol-vin/crshader/commit/3a57bc2))
- • **[DEPS]** upgrade Lapis to Godot 4.8-beta2 ([`5678209`](https://github.com/sol-vin/crshader/commit/5678209))
- • use GNU ld.bfd for Linux shared libraries and macOS arm64 Godot 4.8-beta2 fallback ([`f2e5d40`](https://github.com/sol-vin/crshader/commit/f2e5d40))
- • **[SPEC]** update ci_workflow_spec and avoid match macro order sensitivity ([`0787b7d`](https://github.com/sol-vin/crshader/commit/0787b7d))
- • **[SPEC]** align ci_workflow_spec with test matrix key ([`ec38ebd`](https://github.com/sol-vin/crshader/commit/ec38ebd))
- • **[DEPS]** update lapis shard.lock to finalized 4.8-beta2 (56c198f) ([`0e5a4ad`](https://github.com/sol-vin/crshader/commit/0e5a4ad))
- • **[DEPS]** update Lapis dependency to v0.2.3 (Godot 4.8-beta2) ([`f801ad0`](https://github.com/sol-vin/crshader/commit/f801ad0))
- • **[DEPS]** lock lapis v0.3.7 on 4.8-beta3 ([`1ee7b4f`](https://github.com/sol-vin/crshader/commit/1ee7b4f))
- • **[DEPS]** lock lapis v0.4.1 on 4.8-beta4 ([`042d709`](https://github.com/sol-vin/crshader/commit/042d709))
- • **[EXAMPLES]** sync compiled example shaders with v0.1.59 transpiler output ([`01711e3`](https://github.com/sol-vin/crshader/commit/01711e3))

---
## [0.1.64] - 2026-11-21
### ✨ Features & Improvements
- ✦ **[DSL,STD]** add outline & artist stdlibs, shader builder, variant cache, gdshaderinc emitter, and spatial/compute interop ([`c5a4ee4`](https://github.com/sol-vin/crshader/commit/c5a4ee4))
- ✦ **[EDITOR]** add Godot 4.8 Shader Editor tab integration, emit_target multi-output compilation, and crshader/addon entrypoint ([`ad76bd8`](https://github.com/sol-vin/crshader/commit/ad76bd8))

### 🐛 Bug Fixes
- ✓ **[VALIDATOR]** allow source_color hint on Sampler2D and Vec3 uniforms in Spatial shaders ([`f00e5ac`](https://github.com/sol-vin/crshader/commit/f00e5ac))
- ✓ **[TRANSPILER]** deduplicate gdshaderinc helpers, fix setter/return ternaries, struct .color fields, and gdshaderinc varyings ([`f0a81e0`](https://github.com/sol-vin/crshader/commit/f0a81e0))
- ✓ **[GDSHADER]** emit varying before flat/smooth interpolation qualifier per Godot 4 grammar ([`975e249`](https://github.com/sol-vin/crshader/commit/975e249))
- ✓ **[PALETTES]** emit native Godot 4 flat PackedColorArray floats in ColorPalette .tres resources ([`401f4d4`](https://github.com/sol-vin/crshader/commit/401f4d4))
- ✓ **[EDITOR]** normalize Windows backslashes before Dir.glob in ShaderEditorIntegration ([`b33a928`](https://github.com/sol-vin/crshader/commit/b33a928))

### 🛠️ Chores & Tooling
- • **[DEPS]** upgrade Lapis and Godot target to 4.8-beta1 (v0.1.11) ([`3a57bc2`](https://github.com/sol-vin/crshader/commit/3a57bc2))
- • **[DEPS]** upgrade Lapis to Godot 4.8-beta2 ([`5678209`](https://github.com/sol-vin/crshader/commit/5678209))
- • use GNU ld.bfd for Linux shared libraries and macOS arm64 Godot 4.8-beta2 fallback ([`f2e5d40`](https://github.com/sol-vin/crshader/commit/f2e5d40))
- • **[SPEC]** update ci_workflow_spec and avoid match macro order sensitivity ([`0787b7d`](https://github.com/sol-vin/crshader/commit/0787b7d))
- • **[SPEC]** align ci_workflow_spec with test matrix key ([`ec38ebd`](https://github.com/sol-vin/crshader/commit/ec38ebd))
- • **[DEPS]** update lapis shard.lock to finalized 4.8-beta2 (56c198f) ([`0e5a4ad`](https://github.com/sol-vin/crshader/commit/0e5a4ad))
- • **[DEPS]** update Lapis dependency to v0.2.3 (Godot 4.8-beta2) ([`f801ad0`](https://github.com/sol-vin/crshader/commit/f801ad0))
- • **[DEPS]** lock lapis v0.3.7 on 4.8-beta3 ([`1ee7b4f`](https://github.com/sol-vin/crshader/commit/1ee7b4f))
- • **[DEPS]** lock lapis v0.4.1 on 4.8-beta4 ([`042d709`](https://github.com/sol-vin/crshader/commit/042d709))
- • **[EXAMPLES]** sync compiled example shaders with v0.1.59 transpiler output ([`01711e3`](https://github.com/sol-vin/crshader/commit/01711e3))

---
## [0.1.63] - 2026-11-21
### ✨ Features & Improvements
- ✦ **[DSL,STD]** add outline & artist stdlibs, shader builder, variant cache, gdshaderinc emitter, and spatial/compute interop ([`c5a4ee4`](https://github.com/sol-vin/crshader/commit/c5a4ee4))
- ✦ **[EDITOR]** add Godot 4.8 Shader Editor tab integration, emit_target multi-output compilation, and crshader/addon entrypoint ([`ad76bd8`](https://github.com/sol-vin/crshader/commit/ad76bd8))

### 🐛 Bug Fixes
- ✓ **[VALIDATOR]** allow source_color hint on Sampler2D and Vec3 uniforms in Spatial shaders ([`f00e5ac`](https://github.com/sol-vin/crshader/commit/f00e5ac))
- ✓ **[TRANSPILER]** deduplicate gdshaderinc helpers, fix setter/return ternaries, struct .color fields, and gdshaderinc varyings ([`f0a81e0`](https://github.com/sol-vin/crshader/commit/f0a81e0))
- ✓ **[GDSHADER]** emit varying before flat/smooth interpolation qualifier per Godot 4 grammar ([`975e249`](https://github.com/sol-vin/crshader/commit/975e249))
- ✓ **[PALETTES]** emit native Godot 4 flat PackedColorArray floats in ColorPalette .tres resources ([`401f4d4`](https://github.com/sol-vin/crshader/commit/401f4d4))

### 🛠️ Chores & Tooling
- • **[DEPS]** upgrade Lapis and Godot target to 4.8-beta1 (v0.1.11) ([`3a57bc2`](https://github.com/sol-vin/crshader/commit/3a57bc2))
- • **[DEPS]** upgrade Lapis to Godot 4.8-beta2 ([`5678209`](https://github.com/sol-vin/crshader/commit/5678209))
- • use GNU ld.bfd for Linux shared libraries and macOS arm64 Godot 4.8-beta2 fallback ([`f2e5d40`](https://github.com/sol-vin/crshader/commit/f2e5d40))
- • **[SPEC]** update ci_workflow_spec and avoid match macro order sensitivity ([`0787b7d`](https://github.com/sol-vin/crshader/commit/0787b7d))
- • **[SPEC]** align ci_workflow_spec with test matrix key ([`ec38ebd`](https://github.com/sol-vin/crshader/commit/ec38ebd))
- • **[DEPS]** update lapis shard.lock to finalized 4.8-beta2 (56c198f) ([`0e5a4ad`](https://github.com/sol-vin/crshader/commit/0e5a4ad))
- • **[DEPS]** update Lapis dependency to v0.2.3 (Godot 4.8-beta2) ([`f801ad0`](https://github.com/sol-vin/crshader/commit/f801ad0))
- • **[DEPS]** lock lapis v0.3.7 on 4.8-beta3 ([`1ee7b4f`](https://github.com/sol-vin/crshader/commit/1ee7b4f))
- • **[DEPS]** lock lapis v0.4.1 on 4.8-beta4 ([`042d709`](https://github.com/sol-vin/crshader/commit/042d709))
- • **[EXAMPLES]** sync compiled example shaders with v0.1.59 transpiler output ([`01711e3`](https://github.com/sol-vin/crshader/commit/01711e3))

---
## [0.1.62] - 2026-11-21
### ✨ Features & Improvements
- ✦ **[DSL,STD]** add outline & artist stdlibs, shader builder, variant cache, gdshaderinc emitter, and spatial/compute interop ([`c5a4ee4`](https://github.com/sol-vin/crshader/commit/c5a4ee4))
- ✦ **[EDITOR]** add Godot 4.8 Shader Editor tab integration, emit_target multi-output compilation, and crshader/addon entrypoint ([`ad76bd8`](https://github.com/sol-vin/crshader/commit/ad76bd8))

### 🐛 Bug Fixes
- ✓ **[VALIDATOR]** allow source_color hint on Sampler2D and Vec3 uniforms in Spatial shaders ([`f00e5ac`](https://github.com/sol-vin/crshader/commit/f00e5ac))
- ✓ **[TRANSPILER]** deduplicate gdshaderinc helpers, fix setter/return ternaries, struct .color fields, and gdshaderinc varyings ([`f0a81e0`](https://github.com/sol-vin/crshader/commit/f0a81e0))
- ✓ **[GDSHADER]** emit varying before flat/smooth interpolation qualifier per Godot 4 grammar ([`975e249`](https://github.com/sol-vin/crshader/commit/975e249))

### 🛠️ Chores & Tooling
- • **[DEPS]** upgrade Lapis and Godot target to 4.8-beta1 (v0.1.11) ([`3a57bc2`](https://github.com/sol-vin/crshader/commit/3a57bc2))
- • **[DEPS]** upgrade Lapis to Godot 4.8-beta2 ([`5678209`](https://github.com/sol-vin/crshader/commit/5678209))
- • use GNU ld.bfd for Linux shared libraries and macOS arm64 Godot 4.8-beta2 fallback ([`f2e5d40`](https://github.com/sol-vin/crshader/commit/f2e5d40))
- • **[SPEC]** update ci_workflow_spec and avoid match macro order sensitivity ([`0787b7d`](https://github.com/sol-vin/crshader/commit/0787b7d))
- • **[SPEC]** align ci_workflow_spec with test matrix key ([`ec38ebd`](https://github.com/sol-vin/crshader/commit/ec38ebd))
- • **[DEPS]** update lapis shard.lock to finalized 4.8-beta2 (56c198f) ([`0e5a4ad`](https://github.com/sol-vin/crshader/commit/0e5a4ad))
- • **[DEPS]** update Lapis dependency to v0.2.3 (Godot 4.8-beta2) ([`f801ad0`](https://github.com/sol-vin/crshader/commit/f801ad0))
- • **[DEPS]** lock lapis v0.3.7 on 4.8-beta3 ([`1ee7b4f`](https://github.com/sol-vin/crshader/commit/1ee7b4f))
- • **[DEPS]** lock lapis v0.4.1 on 4.8-beta4 ([`042d709`](https://github.com/sol-vin/crshader/commit/042d709))
- • **[EXAMPLES]** sync compiled example shaders with v0.1.59 transpiler output ([`01711e3`](https://github.com/sol-vin/crshader/commit/01711e3))

---
## [0.1.61] - 2026-11-21
### ✨ Features & Improvements
- ✦ **[DSL,STD]** add outline & artist stdlibs, shader builder, variant cache, gdshaderinc emitter, and spatial/compute interop ([`c5a4ee4`](https://github.com/sol-vin/crshader/commit/c5a4ee4))

### 🐛 Bug Fixes
- ✓ **[VALIDATOR]** allow source_color hint on Sampler2D and Vec3 uniforms in Spatial shaders ([`f00e5ac`](https://github.com/sol-vin/crshader/commit/f00e5ac))
- ✓ **[TRANSPILER]** deduplicate gdshaderinc helpers, fix setter/return ternaries, struct .color fields, and gdshaderinc varyings ([`f0a81e0`](https://github.com/sol-vin/crshader/commit/f0a81e0))
- ✓ **[GDSHADER]** emit varying before flat/smooth interpolation qualifier per Godot 4 grammar ([`975e249`](https://github.com/sol-vin/crshader/commit/975e249))

### 🛠️ Chores & Tooling
- • **[DEPS]** upgrade Lapis and Godot target to 4.8-beta1 (v0.1.11) ([`3a57bc2`](https://github.com/sol-vin/crshader/commit/3a57bc2))
- • **[DEPS]** upgrade Lapis to Godot 4.8-beta2 ([`5678209`](https://github.com/sol-vin/crshader/commit/5678209))
- • use GNU ld.bfd for Linux shared libraries and macOS arm64 Godot 4.8-beta2 fallback ([`f2e5d40`](https://github.com/sol-vin/crshader/commit/f2e5d40))
- • **[SPEC]** update ci_workflow_spec and avoid match macro order sensitivity ([`0787b7d`](https://github.com/sol-vin/crshader/commit/0787b7d))
- • **[SPEC]** align ci_workflow_spec with test matrix key ([`ec38ebd`](https://github.com/sol-vin/crshader/commit/ec38ebd))
- • **[DEPS]** update lapis shard.lock to finalized 4.8-beta2 (56c198f) ([`0e5a4ad`](https://github.com/sol-vin/crshader/commit/0e5a4ad))
- • **[DEPS]** update Lapis dependency to v0.2.3 (Godot 4.8-beta2) ([`f801ad0`](https://github.com/sol-vin/crshader/commit/f801ad0))
- • **[DEPS]** lock lapis v0.3.7 on 4.8-beta3 ([`1ee7b4f`](https://github.com/sol-vin/crshader/commit/1ee7b4f))
- • **[DEPS]** lock lapis v0.4.1 on 4.8-beta4 ([`042d709`](https://github.com/sol-vin/crshader/commit/042d709))
- • **[EXAMPLES]** sync compiled example shaders with v0.1.59 transpiler output ([`01711e3`](https://github.com/sol-vin/crshader/commit/01711e3))

---
## [0.1.60] - 2026-11-21
### ✨ Features & Improvements
- ✦ **[DSL,STD]** add outline & artist stdlibs, shader builder, variant cache, gdshaderinc emitter, and spatial/compute interop ([`c5a4ee4`](https://github.com/sol-vin/crshader/commit/c5a4ee4))

### 🐛 Bug Fixes
- ✓ **[VALIDATOR]** allow source_color hint on Sampler2D and Vec3 uniforms in Spatial shaders ([`f00e5ac`](https://github.com/sol-vin/crshader/commit/f00e5ac))
- ✓ **[TRANSPILER]** deduplicate gdshaderinc helpers, fix setter/return ternaries, struct .color fields, and gdshaderinc varyings ([`f0a81e0`](https://github.com/sol-vin/crshader/commit/f0a81e0))
- ✓ **[GDSHADER]** emit varying before flat/smooth interpolation qualifier per Godot 4 grammar ([`975e249`](https://github.com/sol-vin/crshader/commit/975e249))

### 🛠️ Chores & Tooling
- • **[DEPS]** upgrade Lapis and Godot target to 4.8-beta1 (v0.1.11) ([`3a57bc2`](https://github.com/sol-vin/crshader/commit/3a57bc2))
- • **[DEPS]** upgrade Lapis to Godot 4.8-beta2 ([`5678209`](https://github.com/sol-vin/crshader/commit/5678209))
- • use GNU ld.bfd for Linux shared libraries and macOS arm64 Godot 4.8-beta2 fallback ([`f2e5d40`](https://github.com/sol-vin/crshader/commit/f2e5d40))
- • **[SPEC]** update ci_workflow_spec and avoid match macro order sensitivity ([`0787b7d`](https://github.com/sol-vin/crshader/commit/0787b7d))
- • **[SPEC]** align ci_workflow_spec with test matrix key ([`ec38ebd`](https://github.com/sol-vin/crshader/commit/ec38ebd))
- • **[DEPS]** update lapis shard.lock to finalized 4.8-beta2 (56c198f) ([`0e5a4ad`](https://github.com/sol-vin/crshader/commit/0e5a4ad))
- • **[DEPS]** update Lapis dependency to v0.2.3 (Godot 4.8-beta2) ([`f801ad0`](https://github.com/sol-vin/crshader/commit/f801ad0))
- • **[DEPS]** lock lapis v0.3.7 on 4.8-beta3 ([`1ee7b4f`](https://github.com/sol-vin/crshader/commit/1ee7b4f))
- • **[DEPS]** lock lapis v0.4.1 on 4.8-beta4 ([`042d709`](https://github.com/sol-vin/crshader/commit/042d709))

---
## [0.1.59] - 2026-11-21
### ✨ Features & Improvements
- ✦ **[DSL,STD]** add outline & artist stdlibs, shader builder, variant cache, gdshaderinc emitter, and spatial/compute interop ([`c5a4ee4`](https://github.com/sol-vin/crshader/commit/c5a4ee4))

### 🐛 Bug Fixes
- ✓ **[VALIDATOR]** allow source_color hint on Sampler2D and Vec3 uniforms in Spatial shaders ([`f00e5ac`](https://github.com/sol-vin/crshader/commit/f00e5ac))
- ✓ **[TRANSPILER]** deduplicate gdshaderinc helpers, fix setter/return ternaries, struct .color fields, and gdshaderinc varyings ([`f0a81e0`](https://github.com/sol-vin/crshader/commit/f0a81e0))

### 🛠️ Chores & Tooling
- • **[DEPS]** upgrade Lapis and Godot target to 4.8-beta1 (v0.1.11) ([`3a57bc2`](https://github.com/sol-vin/crshader/commit/3a57bc2))
- • **[DEPS]** upgrade Lapis to Godot 4.8-beta2 ([`5678209`](https://github.com/sol-vin/crshader/commit/5678209))
- • use GNU ld.bfd for Linux shared libraries and macOS arm64 Godot 4.8-beta2 fallback ([`f2e5d40`](https://github.com/sol-vin/crshader/commit/f2e5d40))
- • **[SPEC]** update ci_workflow_spec and avoid match macro order sensitivity ([`0787b7d`](https://github.com/sol-vin/crshader/commit/0787b7d))
- • **[SPEC]** align ci_workflow_spec with test matrix key ([`ec38ebd`](https://github.com/sol-vin/crshader/commit/ec38ebd))
- • **[DEPS]** update lapis shard.lock to finalized 4.8-beta2 (56c198f) ([`0e5a4ad`](https://github.com/sol-vin/crshader/commit/0e5a4ad))
- • **[DEPS]** update Lapis dependency to v0.2.3 (Godot 4.8-beta2) ([`f801ad0`](https://github.com/sol-vin/crshader/commit/f801ad0))
- • **[DEPS]** lock lapis v0.3.7 on 4.8-beta3 ([`1ee7b4f`](https://github.com/sol-vin/crshader/commit/1ee7b4f))
- • **[DEPS]** lock lapis v0.4.1 on 4.8-beta4 ([`042d709`](https://github.com/sol-vin/crshader/commit/042d709))

---
## [0.1.58] - 2026-11-21
### ✨ Features & Improvements
- ✦ **[DSL,STD]** add outline & artist stdlibs, shader builder, variant cache, gdshaderinc emitter, and spatial/compute interop ([`c5a4ee4`](https://github.com/sol-vin/crshader/commit/c5a4ee4))

### 🐛 Bug Fixes
- ✓ **[VALIDATOR]** allow source_color hint on Sampler2D and Vec3 uniforms in Spatial shaders ([`f00e5ac`](https://github.com/sol-vin/crshader/commit/f00e5ac))

### 🛠️ Chores & Tooling
- • **[DEPS]** upgrade Lapis and Godot target to 4.8-beta1 (v0.1.11) ([`3a57bc2`](https://github.com/sol-vin/crshader/commit/3a57bc2))
- • **[DEPS]** upgrade Lapis to Godot 4.8-beta2 ([`5678209`](https://github.com/sol-vin/crshader/commit/5678209))
- • use GNU ld.bfd for Linux shared libraries and macOS arm64 Godot 4.8-beta2 fallback ([`f2e5d40`](https://github.com/sol-vin/crshader/commit/f2e5d40))
- • **[SPEC]** update ci_workflow_spec and avoid match macro order sensitivity ([`0787b7d`](https://github.com/sol-vin/crshader/commit/0787b7d))
- • **[SPEC]** align ci_workflow_spec with test matrix key ([`ec38ebd`](https://github.com/sol-vin/crshader/commit/ec38ebd))
- • **[DEPS]** update lapis shard.lock to finalized 4.8-beta2 (56c198f) ([`0e5a4ad`](https://github.com/sol-vin/crshader/commit/0e5a4ad))
- • **[DEPS]** update Lapis dependency to v0.2.3 (Godot 4.8-beta2) ([`f801ad0`](https://github.com/sol-vin/crshader/commit/f801ad0))
- • **[DEPS]** lock lapis v0.3.7 on 4.8-beta3 ([`1ee7b4f`](https://github.com/sol-vin/crshader/commit/1ee7b4f))
- • **[DEPS]** lock lapis v0.4.1 on 4.8-beta4 ([`042d709`](https://github.com/sol-vin/crshader/commit/042d709))

---
## [0.1.57] - 2026-11-21
### ✨ Features & Improvements
- ✦ **[DSL,STD]** add outline & artist stdlibs, shader builder, variant cache, gdshaderinc emitter, and spatial/compute interop ([`c5a4ee4`](https://github.com/sol-vin/crshader/commit/c5a4ee4))

### 🛠️ Chores & Tooling
- • **[DEPS]** upgrade Lapis and Godot target to 4.8-beta1 (v0.1.11) ([`3a57bc2`](https://github.com/sol-vin/crshader/commit/3a57bc2))
- • **[DEPS]** upgrade Lapis to Godot 4.8-beta2 ([`5678209`](https://github.com/sol-vin/crshader/commit/5678209))
- • use GNU ld.bfd for Linux shared libraries and macOS arm64 Godot 4.8-beta2 fallback ([`f2e5d40`](https://github.com/sol-vin/crshader/commit/f2e5d40))
- • **[SPEC]** update ci_workflow_spec and avoid match macro order sensitivity ([`0787b7d`](https://github.com/sol-vin/crshader/commit/0787b7d))
- • **[SPEC]** align ci_workflow_spec with test matrix key ([`ec38ebd`](https://github.com/sol-vin/crshader/commit/ec38ebd))
- • **[DEPS]** update lapis shard.lock to finalized 4.8-beta2 (56c198f) ([`0e5a4ad`](https://github.com/sol-vin/crshader/commit/0e5a4ad))
- • **[DEPS]** update Lapis dependency to v0.2.3 (Godot 4.8-beta2) ([`f801ad0`](https://github.com/sol-vin/crshader/commit/f801ad0))
- • **[DEPS]** lock lapis v0.3.7 on 4.8-beta3 ([`1ee7b4f`](https://github.com/sol-vin/crshader/commit/1ee7b4f))
- • **[DEPS]** lock lapis v0.4.1 on 4.8-beta4 ([`042d709`](https://github.com/sol-vin/crshader/commit/042d709))

---
## [0.1.56] - 2026-11-21
### 🛠️ Chores & Tooling
- • **[DEPS]** upgrade Lapis and Godot target to 4.8-beta1 (v0.1.11) ([`3a57bc2`](https://github.com/sol-vin/crshader/commit/3a57bc2))
- • **[DEPS]** upgrade Lapis to Godot 4.8-beta2 ([`5678209`](https://github.com/sol-vin/crshader/commit/5678209))
- • use GNU ld.bfd for Linux shared libraries and macOS arm64 Godot 4.8-beta2 fallback ([`f2e5d40`](https://github.com/sol-vin/crshader/commit/f2e5d40))
- • **[SPEC]** update ci_workflow_spec and avoid match macro order sensitivity ([`0787b7d`](https://github.com/sol-vin/crshader/commit/0787b7d))
- • **[SPEC]** align ci_workflow_spec with test matrix key ([`ec38ebd`](https://github.com/sol-vin/crshader/commit/ec38ebd))
- • **[DEPS]** update lapis shard.lock to finalized 4.8-beta2 (56c198f) ([`0e5a4ad`](https://github.com/sol-vin/crshader/commit/0e5a4ad))
- • **[DEPS]** update Lapis dependency to v0.2.3 (Godot 4.8-beta2) ([`f801ad0`](https://github.com/sol-vin/crshader/commit/f801ad0))
- • **[DEPS]** lock lapis v0.3.7 on 4.8-beta3 ([`1ee7b4f`](https://github.com/sol-vin/crshader/commit/1ee7b4f))
- • **[DEPS]** lock lapis v0.4.1 on 4.8-beta4 ([`042d709`](https://github.com/sol-vin/crshader/commit/042d709))

---
## [0.1.55] - 2026-11-21
### 🛠️ Chores & Tooling
- • **[DEPS]** upgrade Lapis and Godot target to 4.8-beta1 (v0.1.11) ([`3a57bc2`](https://github.com/sol-vin/crshader/commit/3a57bc2))
- • **[DEPS]** upgrade Lapis to Godot 4.8-beta2 ([`5678209`](https://github.com/sol-vin/crshader/commit/5678209))
- • use GNU ld.bfd for Linux shared libraries and macOS arm64 Godot 4.8-beta2 fallback ([`f2e5d40`](https://github.com/sol-vin/crshader/commit/f2e5d40))
- • **[SPEC]** update ci_workflow_spec and avoid match macro order sensitivity ([`0787b7d`](https://github.com/sol-vin/crshader/commit/0787b7d))
- • **[SPEC]** align ci_workflow_spec with test matrix key ([`ec38ebd`](https://github.com/sol-vin/crshader/commit/ec38ebd))
- • **[DEPS]** update lapis shard.lock to finalized 4.8-beta2 (56c198f) ([`0e5a4ad`](https://github.com/sol-vin/crshader/commit/0e5a4ad))
- • **[DEPS]** update Lapis dependency to v0.2.3 (Godot 4.8-beta2) ([`f801ad0`](https://github.com/sol-vin/crshader/commit/f801ad0))
- • **[DEPS]** lock lapis v0.3.7 on 4.8-beta3 ([`1ee7b4f`](https://github.com/sol-vin/crshader/commit/1ee7b4f))

---
## [0.1.54] - 2026-11-19
### 🛠️ Chores & Tooling
- • **[DEPS]** upgrade Lapis and Godot target to 4.8-beta1 (v0.1.11) ([`3a57bc2`](https://github.com/sol-vin/crshader/commit/3a57bc2))
- • **[DEPS]** upgrade Lapis to Godot 4.8-beta2 ([`5678209`](https://github.com/sol-vin/crshader/commit/5678209))
- • use GNU ld.bfd for Linux shared libraries and macOS arm64 Godot 4.8-beta2 fallback ([`f2e5d40`](https://github.com/sol-vin/crshader/commit/f2e5d40))
- • **[SPEC]** update ci_workflow_spec and avoid match macro order sensitivity ([`0787b7d`](https://github.com/sol-vin/crshader/commit/0787b7d))
- • **[SPEC]** align ci_workflow_spec with test matrix key ([`ec38ebd`](https://github.com/sol-vin/crshader/commit/ec38ebd))
- • **[DEPS]** update lapis shard.lock to finalized 4.8-beta2 (56c198f) ([`0e5a4ad`](https://github.com/sol-vin/crshader/commit/0e5a4ad))
- • **[DEPS]** update Lapis dependency to v0.2.3 (Godot 4.8-beta2) ([`f801ad0`](https://github.com/sol-vin/crshader/commit/f801ad0))

---
## [0.1.53] - 2026-11-06
### 🛠️ Chores & Tooling
- • **[DEPS]** upgrade Lapis and Godot target to 4.8-beta1 (v0.1.11) ([`3a57bc2`](https://github.com/sol-vin/crshader/commit/3a57bc2))
- • **[DEPS]** upgrade Lapis to Godot 4.8-beta2 ([`5678209`](https://github.com/sol-vin/crshader/commit/5678209))
- • use GNU ld.bfd for Linux shared libraries and macOS arm64 Godot 4.8-beta2 fallback ([`f2e5d40`](https://github.com/sol-vin/crshader/commit/f2e5d40))
- • **[SPEC]** update ci_workflow_spec and avoid match macro order sensitivity ([`0787b7d`](https://github.com/sol-vin/crshader/commit/0787b7d))
- • **[SPEC]** align ci_workflow_spec with test matrix key ([`ec38ebd`](https://github.com/sol-vin/crshader/commit/ec38ebd))
- • **[DEPS]** update lapis shard.lock to finalized 4.8-beta2 (56c198f) ([`0e5a4ad`](https://github.com/sol-vin/crshader/commit/0e5a4ad))

---
## [0.1.52] - 2026-11-04
### 🛠️ Chores & Tooling
- • **[DEPS]** upgrade Lapis and Godot target to 4.8-beta1 (v0.1.11) ([`3a57bc2`](https://github.com/sol-vin/crshader/commit/3a57bc2))
- • **[DEPS]** upgrade Lapis to Godot 4.8-beta2 ([`5678209`](https://github.com/sol-vin/crshader/commit/5678209))
- • use GNU ld.bfd for Linux shared libraries and macOS arm64 Godot 4.8-beta2 fallback ([`f2e5d40`](https://github.com/sol-vin/crshader/commit/f2e5d40))
- • **[SPEC]** update ci_workflow_spec and avoid match macro order sensitivity ([`0787b7d`](https://github.com/sol-vin/crshader/commit/0787b7d))
- • **[SPEC]** align ci_workflow_spec with test matrix key ([`ec38ebd`](https://github.com/sol-vin/crshader/commit/ec38ebd))

---
## [0.1.51] - 2026-11-04
### 🛠️ Chores & Tooling
- • **[DEPS]** upgrade Lapis and Godot target to 4.8-beta1 (v0.1.11) ([`3a57bc2`](https://github.com/sol-vin/crshader/commit/3a57bc2))
- • **[DEPS]** upgrade Lapis to Godot 4.8-beta2 ([`5678209`](https://github.com/sol-vin/crshader/commit/5678209))
- • use GNU ld.bfd for Linux shared libraries and macOS arm64 Godot 4.8-beta2 fallback ([`f2e5d40`](https://github.com/sol-vin/crshader/commit/f2e5d40))
- • **[SPEC]** update ci_workflow_spec and avoid match macro order sensitivity ([`0787b7d`](https://github.com/sol-vin/crshader/commit/0787b7d))

---
## [0.1.50] - 2026-11-04
### 🛠️ Chores & Tooling
- • **[DEPS]** upgrade Lapis and Godot target to 4.8-beta1 (v0.1.11) ([`3a57bc2`](https://github.com/sol-vin/crshader/commit/3a57bc2))
- • **[DEPS]** upgrade Lapis to Godot 4.8-beta2 ([`5678209`](https://github.com/sol-vin/crshader/commit/5678209))
- • use GNU ld.bfd for Linux shared libraries and macOS arm64 Godot 4.8-beta2 fallback ([`f2e5d40`](https://github.com/sol-vin/crshader/commit/f2e5d40))

---
## [0.1.49] - 2026-11-04
### 🛠️ Chores & Tooling
- • **[DEPS]** upgrade Lapis and Godot target to 4.8-beta1 (v0.1.11) ([`3a57bc2`](https://github.com/sol-vin/crshader/commit/3a57bc2))
- • **[DEPS]** upgrade Lapis to Godot 4.8-beta2 ([`5678209`](https://github.com/sol-vin/crshader/commit/5678209))

---
## [0.1.48] - 2026-11-04
### 🛠️ Chores & Tooling
- • **[DEPS]** upgrade Lapis and Godot target to 4.8-beta1 (v0.1.11) ([`3a57bc2`](https://github.com/sol-vin/crshader/commit/3a57bc2))

---
## [0.1.47] - 2026-10-28
---
## [0.1.46] - 2026-10-13
---
## [0.1.45] - 2026-10-13
### ✨ Features & Improvements
- ✦ **[COMPUTE]** expand CRShader with Two-Tier Compute Shader Particle Simulation engine, declarative builder, std/particles library, and ComputeParticles node generator

---
## [0.1.44] - 2026-10-12
### 🐛 Bug Fixes
- ✓ **[CI]** prevent Windows smoke test hang, fix macOS GDExtension type hierarchy, and correct benchmark shard imports ([`0d9165e`](https://github.com/sol-vin/crshader/commit/0d9165e))
- ✓ **[RESOURCES]** provide explicit pointer constructor and initialize to satisfy Godot.create dispatch on macOS ([`b921d63`](https://github.com/sol-vin/crshader/commit/b921d63))

### 🛠️ Chores & Tooling
- • **[LAPIS]** upgrade to Godot 4.8-dev7 and update workflow configurations ([`657d798`](https://github.com/sol-vin/crshader/commit/657d798))
- • **[LAPIS]** upgrade to Lapis 4.8-dev7, adopt Carbon & Jasper tooling, and modernize CI workflows ([`9654a2b`](https://github.com/sol-vin/crshader/commit/9654a2b))

---
## [0.1.43] - 2026-10-12
### 🐛 Bug Fixes
- ✓ **[CI]** prevent Windows smoke test hang, fix macOS GDExtension type hierarchy, and correct benchmark shard imports ([`0d9165e`](https://github.com/sol-vin/crshader/commit/0d9165e))

### 🛠️ Chores & Tooling
- • **[LAPIS]** upgrade to Godot 4.8-dev7 and update workflow configurations ([`657d798`](https://github.com/sol-vin/crshader/commit/657d798))
- • **[LAPIS]** upgrade to Lapis 4.8-dev7, adopt Carbon & Jasper tooling, and modernize CI workflows ([`9654a2b`](https://github.com/sol-vin/crshader/commit/9654a2b))

---
## [0.1.42] - 2026-10-12
### 🛠️ Chores & Tooling
- • **[LAPIS]** upgrade to Godot 4.8-dev7 and update workflow configurations ([`657d798`](https://github.com/sol-vin/crshader/commit/657d798))
- • **[LAPIS]** upgrade to Lapis 4.8-dev7, adopt Carbon & Jasper tooling, and modernize CI workflows ([`9654a2b`](https://github.com/sol-vin/crshader/commit/9654a2b))

---
## [0.1.41] - 2026-10-12
### 🛠️ Chores & Tooling
- • **[LAPIS]** upgrade to Godot 4.8-dev7 and update workflow configurations ([`657d798`](https://github.com/sol-vin/crshader/commit/657d798))
- • **[LAPIS]** upgrade to Lapis 4.8-dev7, adopt Carbon & Jasper tooling, and modernize CI workflows ([`a29bf46`](https://github.com/sol-vin/crshader/commit/a29bf46))

---
## [0.1.40] - 2026-10-12
### 🛠️ Chores & Tooling
- • **[LAPIS]** upgrade to Godot 4.8-dev7 and update workflow configurations ([`657d798`](https://github.com/sol-vin/crshader/commit/657d798))
- • **[LAPIS]** upgrade to Lapis 4.8-dev7, adopt Carbon & Jasper tooling, and modernize CI workflows ([`107699c`](https://github.com/sol-vin/crshader/commit/107699c))

---
## [0.1.39] - 2026-10-12
### 🛠️ Chores & Tooling
- • **[LAPIS]** upgrade to Godot 4.8-dev7 and update workflow configurations ([`657d798`](https://github.com/sol-vin/crshader/commit/657d798))
- • **[LAPIS]** upgrade to Lapis 4.8-dev7, adopt Carbon & Jasper tooling, and modernize CI workflows ([`107699c`](https://github.com/sol-vin/crshader/commit/107699c))

---
## [0.1.19] - 2026-10-12
### 🛠️ Chores & Tooling
- • **[LAPIS]** upgrade to Godot 4.8-dev7 and update workflow configurations ([`657d798`](https://github.com/sol-vin/crshader/commit/657d798))

---
## [0.1.38] - 2026-10-12
> Initial release
### 🛠️ Chores & Tooling
- • **[LAPIS]** upgrade to Godot 4.8-dev7 and update workflow configurations ([`657d798`](https://github.com/sol-vin/crshader/commit/657d798))

