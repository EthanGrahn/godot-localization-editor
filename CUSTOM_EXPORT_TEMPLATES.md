# Building Minimal Custom Export Templates

Using `minimum_profile.gdbuild` with a custom-compiled Godot export template gives the smallest possible binary by stripping unused engine subsystems (3D, physics, navigation, XR) at compile time. These steps outline how to accomplish this.

**NOTE:** The GitHub release and workflow steps are only pertinent to maintainers.

## Step 1: Set up the build environment

Install the following on Windows:

1. **Python 3**
2. **SCons** — `pip install scons`
3. **Visual Studio 2022 Build Tools** — install the "Desktop development with C++" workload
4. **Git**

For the Linux template, use **WSL2 (Ubuntu)** — it is the simplest cross-compilation path from Windows.

## Step 2: Get the Godot \<version\> source

```powershell
git clone https://github.com/godotengine/godot.git --branch <version>-stable --depth 1
cd godot
```

The source version must match the editor version exactly.

## Step 3: Compile the Windows export template

From a **Developer PowerShell for VS 2022** (so MSVC is on PATH):

```powershell
scons platform=windows target=template_release arch=x86_64 `
  build_profile="<project path>\minimum_profile.gdbuild" `
  production=yes optimize=size accesskit=no d3d12=no
```

- `build_profile=` reads preset flag values from `minimum_profile.gdbuild`
- `production=yes` enables LTO, strips debug symbols, and statically links the C++ runtime
- `optimize=size` instructs the compiler to prefer binary size over speed
- `accesskit=no` disables AccessKit accessibility support, removing a large dependency
- `d3d12=no` disables Direct3D 12 support; this project only needs Vulkan/OpenGL

Output: `bin\godot.windows.template_release.x86_64.exe`

## Step 4: Compile the Linux export template

**In WSL2 (Ubuntu):**

Install dependencies:

```bash
sudo apt install build-essential scons python3 pkg-config libx11-dev libxcursor-dev \
  libxinerama-dev libgl1-mesa-dev libglu1-mesa-dev libasound2-dev libpulse-dev \
  libfreetype-dev libssl-dev libudev-dev
```

Compile:

```bash
scons platform=linuxbsd target=template_release arch=x86_64 \
  build_profile="/mnt/d/GodotProjects/godot-localization-editor/minimum_profile.gdbuild" \
  production=yes optimize=size accesskit=no d3d12=no
```

Output: `bin/godot.linuxbsd.template_release.x86_64`

## Step 5: Upload the templates to GitHub

The CI workflows download templates from a dedicated release titled "Custom Export Templates (\<Godot version\>)" in this repository. Upload the compiled binaries there with these exact filenames:

| File | Source |
|---|---|
| `godot.windows.template_release.x86_64.exe` | `bin\godot.windows.template_release.x86_64.exe` from the Godot source `bin\` directory |
| `godot.linuxbsd.template_release.x86_64` | `bin/godot.linuxbsd.template_release.x86_64` from the Godot source `bin/` directory |

Create or update the release in GitHub:

Title: Custom Export Templates (Godot \<Godot version\>) \
Description: Minimal custom export templates built with minimum_profile.gdbuild. \
Attached Files:
  - `bin\godot.windows.template_release.x86_64.exe`
  - `bin/godot.linuxbsd.template_release.x86_64`

## Step 6: Point each export preset to the custom templates

In the Godot editor, for each of the four export presets:

1. Open **Project → Export** and select the preset
2. Under **Custom Template**, set **Release** to the compiled binary:
   - Windows presets → `bin\godot.windows.template_release.x86_64.exe`
   - Linux presets → `bin/godot.linuxbsd.template_release.x86_64`

Do not commit these changes to the `export_presets.cfg` file. The CI automatically handles templates when it constructs the releases.

## Step 6: Export

```powershell
godot --export-release "Windows Desktop"        build/GodotLocalizationEditor.exe
godot --export-release "Windows Desktop (No Google)" build/GodotLocalizationEditor_NoGoogle.exe
godot --export-release "Linux/X11"              build/GodotLocalizationEditor.x86_64
godot --export-release "Linux/X11 (No Google)" build/GodotLocalizationEditor_NoGoogle.x86_64
```
