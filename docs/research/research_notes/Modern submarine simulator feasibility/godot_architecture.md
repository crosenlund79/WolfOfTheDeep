# Godot 4 technical feasibility and architecture for a modern submarine command and career simulator

Research date: November 2026. Labels: **[Fact]** = confirmed by the cited source; **[Estimate]** = my arithmetic or approximation from cited figures; **[Inference]** = recommendation or reasoning that no source states outright. Project constraints come from `docs/GODOT_CLAUDE_GUIDELINES.md`, `assets/README.md` and `tests/README.md`: modules in `src/<module>/`, logic kept out of thin scene nodes, autoloads only with user approval, a runtime `custom/` override resolver for Windows/Linux, and no build or export infrastructure without approval. Unless a version is named, Godot documentation citations are to the "stable" docs, which showed "Godot Engine 4.7 documentation" when fetched in November 2026.

## 1. Current stable Godot 4.x, release cadence and what pinning a minor version implies

### Takeaway
As of November 2026, Godot 4.7 is the current stable minor. It was released in June 2026, and its newest patch I could confirm is 4.7.2 from August 2026. Godot 4.8 is in development, with Q4 2026 as an estimate. Minor releases come out about every 4–5 months. Patch releases are safe to take, but minors can break specific areas, so pinning a minor version and upgrading deliberately fits the project rule.

### Cited Findings
- [Fact] The official release-policy support table lists 4.8 (master) as "Q4 2026 (estimate)", in development. It lists 4.7 (June 2026) and 4.6 (January 2026) as supported with bug, security and platform fixes, and 4.5 (September 2025) as partial, with security and platform fixes only. 4.4 and older 4.x are end-of-life. — [Godot release policy](https://docs.godotengine.org/en/stable/about/release_policy.html)
- [Fact] Versioning is "loose" semver. Patch releases "are backwards compatible", and updating to them is "considered safe and strongly recommended". In minor versions, "Minor compatibility breakage in very specific areas *may* happen", especially in classes marked *experimental*, so minor upgrades should be judged case by case. — [Godot release policy](https://docs.godotengine.org/en/stable/about/release_policy.html)
- [Fact] Stable branches are supported "at least until the next stable branch is released and has received its first patch update". The team aims to publish minor releases "relatively frequently". For example, 4.1 came four months after 4.0, and 4.2 four months after 4.1. — [Godot release policy](https://docs.godotengine.org/en/stable/about/release_policy.html)
- [Fact] Godot 4.7 ("Director's Cut") was covered as released on June 18, 2026, with HDR output among its headline features. — [Phoronix](https://phoronix.com/news/godot-4.7-released); [Godot 4.7 release page](https://godotengine.org/releases/4.7/)
- [Fact] 4.7.1 and 4.7.2 maintenance releases exist. One report describes 4.7.2 as a recommended stability update dated August 18, 2026. — [Godot: maintenance release 4.7.2](https://godotengine.org/article/maintenance-release-godot-4-7-2/); [GameDev.net 4.7.2](https://gamedev.net/news/5172-godot-engine-472-stable-released/)
- [Fact] Godot 4.6 shipped in January 2026. Scenes now store Unique Node IDs, so the team recommends re-saving scenes with Project > Tools > Upgrade Project Files, which is an example of minor-version migration work. 4.6.1–4.6.3 followed. — [Godot 4.6 release page](https://godotengine.org/releases/4.6/); [Godot 4.6.3](https://godotengine.org/article/maintenance-release-godot-4-6-3/)
- [Fact] Godot 4.5 was released in September 2025. After 4.5.2, "the 4.5 branch switches to partial support". — [Godot 4.5.2](https://godotengine.org/article/maintenance-release-godot-4-5-2/); [Godot 4.5 release](https://godotengine.org/releases/4.5/)
- [Fact] Each GUT release line targets one specific Godot minor: 9.4.0 covers 4.3–4.4, 9.5.0 covers 4.5, 9.6.1 covers 4.6 and 9.7.1 covers 4.7. Pinning a Godot minor therefore also pins the test-framework version. — [GUT README](https://raw.githubusercontent.com/bitwes/Gut/main/README.md)

### Inferences
- [Inference] Pin **4.7.x** for a project starting now. It is the newest fully supported branch and has had two patch releases. It should stay supported at least until 4.8 ships and gets its first patch. Re-evaluate at 4.8.1 instead of chasing every minor.
- [Inference] Treat a minor upgrade as its own approved task: read the migration guide, re-save resources and scenes, bump the matched GUT or GdUnit4 version, and rerun the full test suite. Take patch upgrades inside the pinned minor freely.
- [Inference] Avoid relying on features the docs mark *experimental*, such as Jolt physics when it was integrated in 4.4. Those features carry the highest risk of breaking between minors.

### Gaps
- I could not confirm whether a 4.7.3 patch, or a 4.8 beta or stable, existed on 22 November 2026. Check godotengine.org/blog before pinning.

## 2. Language choice: GDScript vs C# vs GDExtension (C++/Rust)

### Takeaway
I found no rigorous head-to-head benchmark. Community evidence and official docs agree that GDScript is clearly slower than C# or native code for tight numeric loops, and the docs themselves steer per-sample audio generation to C# or GDExtension. C# supports all desktop platforms but needs the .NET editor build and cannot export to the web. GDExtension needs compiled binaries per platform. For this project, that means build infrastructure, which needs approval.

### Cited Findings
- [Fact] "Since Godot 4.2, projects written in C# support all desktop platforms (Windows, Linux, and macOS)". Android and iOS are experimental, and "projects written in C# cannot be exported to the web platform". The standard Godot executable lacks C# support, so a .NET editor build is required. — [Godot C# docs (4.7)](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/index.html)
- [Fact] AudioStreamGenerator: "Due to performance constraints, this class is best used from C# or from a compiled language via GDExtension". If GDScript is used, the docs suggest a lower mix rate such as 11,025 or 22,050 Hz. — [AudioStreamGenerator class ref (4.7)](https://docs.godotengine.org/en/stable/classes/class_audiostreamgenerator.html)
- [Fact] Godot 4.0-era forum figures put C# at roughly 4x GDScript in some naive cases, and a later reply says the gaps were shrinking. — [Godot Forum: GDScript vs C# in 4.0](https://forum.godotengine.org/t/state-of-gdscript-vs-c-performance-in-godot-4-0/5875)
- [Fact] One community benchmark summary found C# much faster than GDScript for bubble sort and A* pathfinding, but only slightly faster on an engine-API-access test. This is a single informal test. — [lilys.ai summary of video benchmark](https://lilys.ai/notes/824429)
- [Fact] One forum commenter reports that GDExtension via godot-rust pays a large FFI cost per engine API call ("almost 8x longer" than C#). Another commenter disputes this, so the evidence is anecdotal and conflicting. — [Godot Forum: native code vs GDScript](https://forum.godotengine.org/t/performance-implications-of-using-native-code-instead-of-gdscript/120365)
- [Fact] GDScript `float` is 64-bit by default, while `Vector2/3/4` are 32-bit unless the engine is built with double precision. — [Large world coordinates (4.7)](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html)
- [Fact] GDExtensions must be rebuilt for double-precision engine builds, which set `REAL_T_IS_DOUBLE`. — [Large world coordinates (4.7)](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html)
- [Fact] Godot 4.4 added typed dictionaries to the core, GDScript and other languages, and Godot 4.1 added `static var`. Both help write typed, data-oriented GDScript. — [Godot 4.4 release](https://godotengine.org/releases/4.4/); [Autoloads vs regular nodes (4.7)](https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html)
- [Fact] Testing: GdUnit4's Asset Library build v6.2.0 (listed 2026-07-30) is built on "Godot v4.5.stable.mono.official", and a separate gdUnit4Net project exists for C#. GUT is distributed as a GDScript addon. — [Asset Library: GdUnit4](https://godotengine.org/asset-library/asset/4390); [gdUnit4Net releases](https://www.github.com/MikeSchulze/gdUnit4Net/releases/latest); [GUT README](https://raw.githubusercontent.com/bitwes/Gut/main/README.md)

### Inferences
- [Inference] Start with **statically typed GDScript** for all simulation modules. It keeps one language, works with the GUT and GdUnit4 GDScript runners, needs no .NET SDK, and needs no compiled binaries. Hide performance-critical kernels (acoustic propagation, procedural sonar synthesis) behind narrow interfaces, for example a `PropagationModel` with `compute_transmission_loss(...)`, so they can later move to GDExtension or C# without touching callers.
- [Inference] Moving a kernel to GDExtension means compiling native libraries for Windows and Linux. Under guideline 4 that counts as build infrastructure, so the user must approve it as its own decision, and it should be considered only after profiling shows GDScript is insufficient.
- [Inference] Choosing C# from the start is viable for Windows and Linux, and probably gives several times faster numeric loops. The cost is the .NET editor, possible friction with GDScript-only test tooling (gdUnit4Net covers C#), and a closed door to web export. That last point does not matter while targets are Windows and Linux only. Record it as an explicit decision in `PROJECT_BRIEF.md`, not a default.
- [Inference] Keep hot loops out of engine API calls (no per-element Node access). This shrinks interop overhead in any language and keeps the simulation testable headless.

### Gaps
- I found no controlled, current (4.6/4.7) benchmark of GDScript vs C# vs GDExtension. The community project "godot-survivors-benchmark" exists, but I did not retrieve its numbers ([listing](https://awesome.ecosyste.ms/projects/github.com%2Fjerryshell%2Fgodot-survivors-benchmark)). Recommend a small in-project spike benchmark of the actual propagation kernel before committing to a language.
- I did not confirm which .NET version Godot 4.7 requires.

## 3. Decoupling a deterministic fixed-step simulation from rendering, time compression and save/load

### Takeaway
Godot's `Engine.time_scale` cannot deliver Silent-Hunter-style compression. It stretches `delta`, so each physics tick covers more simulated time and precision drops, but it does not add ticks. A plain RefCounted simulation core with its own `step(dt)`, driven by an accumulator and a per-frame step budget, is the right fit. It also matches the project's testable-logic rule. Interpolating between ticks for display is supported.

### Cited Findings
- [Fact] `Engine.time_scale` "affects Timer, SceneTreeTimer, and all other simulations that make use of delta time". It does not automatically adjust `physics_ticks_per_second`, and for values above 1.0 "physics simulation may become less precise". It "does not affect audio playback speed". — [Engine class ref (4.7)](https://docs.godotengine.org/en/stable/classes/class_engine.html)
- [Fact] `max_physics_steps_per_frame` exists to "prevent expensive physics simulations from triggering even more expensive simulations indefinitely". When the limit is hit, "the game will appear to slow down". — [Engine class ref (4.7)](https://docs.godotengine.org/en/stable/classes/class_engine.html)
- [Fact] `physics_jitter_fix` lets ticks drift from real time to smooth jitter. The docs suggest setting it to 0 for custom physics interpolation or networked games. — [Engine class ref (4.7)](https://docs.godotengine.org/en/stable/classes/class_engine.html)
- [Fact] `Engine.get_physics_interpolation_fraction()` "Returns the fraction through the current physics tick we are at the time of rendering the frame" and can be used for fixed-timestep interpolation. — [Engine class ref (4.7)](https://docs.godotengine.org/en/stable/classes/class_engine.html)
- [Fact] Godot 4.4 added 3D physics interpolation, alongside the 2D version added in 4.3. It is enabled in project settings. — [Godot 4.4 release](https://godotengine.org/releases/4.4/)
- [Fact] Save formats: the docs say JSON "may work" for simple state and is human-readable, but JSON "can't parse" `Vector2`, `Vector3`, `Color`, `Rect2` or `Quaternion`. Binary `FileAccess.store_var`/`get_var` "should produce smaller files than JSON" and needs less custom logic. `ConfigFile` is recommended for user settings. — [Saving games (4.7)](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)
- [Fact] Binary serialization only stores properties flagged `PROPERTY_USAGE_STORAGE`. — [Saving games (4.7)](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)
- [Fact] Text resources do not change between single- and double-precision builds, but binary resources saved by a double build do change on disk. — [Large world coordinates (4.7)](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html)

### Inferences
- [Inference] Architecture: a `SimulationWorld` (RefCounted, no Node) owns all state and exposes `step(dt: float)` with a constant `dt`. It is advanced by a thin `SimulationRunner` Node in `_process`, which accumulates `real_delta * compression` and runs `floor(acc / dt)` steps up to a wall-clock budget measured with `Time.get_ticks_usec()`. Do not use Godot physics bodies for vessel motion. Hand-written kinematics and hydrodynamics in doubles are cheaper and more deterministic, and they can be tested headless without a SceneTree.
- [Estimate] At 60 fps, 1000x compression needs about 16.7 s of simulated time per frame. That is about 167 steps at a 0.1 s step, or about 17 steps at a 1 s step. With 200 contacts and naive O(N²) sensor pair checks (40,000 pairs), the 0.1 s case would mean about 6.7 M pair evaluations per frame, which is not feasible in GDScript.
- [Inference] So use **multi-rate stepping**: kinematics at a fine step, sensor and acoustic detection at a coarser step (for example every 1–10 simulated seconds), and campaign or strategic travel at a much coarser step or analytic interpolation. Lower the allowed compression automatically when contacts are near or new detections appear (a common sim pattern; see Gaps).
- [Inference] Determinism: use a single seeded RNG owned by the simulation (Godot's `RandomNumberGenerator` with an explicit seed), fixed `dt`, and deterministic iteration order (sorted IDs). Keep the simulation off threads, or merge thread results in a fixed order, if bit-exact replays matter.
- [Inference] Save/load: serialize the plain simulation state with an explicit schema version, using a `to_dict()`/`from_dict()` per module. Use JSON for debuggability early, encoding vectors as arrays and keeping doubles as numbers, and switch to `store_var` if size matters. Rendering nodes are rebuilt from simulation state after load and are never saved themselves.
- [Inference] Rendering reads the simulation state and interpolates between the last two ticks using the fraction (accumulator / dt). The simulation never reads from nodes. That one-way dependency is the main module boundary.

### Gaps
- I did not find a citable source describing how Silent Hunter or Cold Waters implement time compression (for example, automatic drops on contact). The multi-rate pattern above is a recommendation, not a documented precedent.
- I did not find a Godot doc statement on cross-platform floating-point determinism of GDScript math (Windows vs Linux). Treat bit-exact cross-platform replay as unverified.

## 4. Data-driven design (Resources vs JSON/CSV), signals vs methods, and autoload trade-offs

### Takeaway
Custom Resources (`.tres`) give typed, inspector-editable definitions for vessel classes, sensors and weapons. JSON or CSV is easier to bulk-edit and diff, but loses Godot types. The official best-practices doc details the hidden-dependency and debugging costs of autoloads, which matches the project rule that autoloads need approval.

### Cited Findings
- [Fact] Autoload costs per the official docs: if one fails, "all the nodes calling it can break". Global access means "there's no longer an easy way to find the source of a bug". "An autoload is *not* necessarily a singleton." — [Autoloads versus regular nodes (4.7)](https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html)
- [Fact] Autoloads "can simplify your code for systems with a wide scope" when they manage only their own data. The suggested alternatives are `static func` and `static var` (4.1+) on `class_name` scripts, custom Resources for shared data, per-scene nodes, and custom node types. — [Autoloads versus regular nodes (4.7)](https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html)
- [Fact] Godot 4.4 added typed dictionaries, which the Inspector can edit directly. — [Godot 4.4 release](https://godotengine.org/releases/4.4/)
- [Fact] JSON cannot represent Godot types such as Vector2/3 or Color natively, and custom classes need hand-written encode and decode logic. — [Saving games (4.7)](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)
- [Fact] "Modifying a unique resource from multiple threads is not supported", but passing references across threads is. — [Thread-safe APIs (4.7)](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html)

### Inferences
- [Inference] Use **custom Resource classes** (`VesselClassDef`, `SensorDef`, `WeaponDef`) in `src/<module>/data/` as **read-only definitions**, and keep mutable runtime state in separate RefCounted instances. This prevents shared-Resource mutation bugs and the threading restriction above.
- [Inference] If the data volume grows large (dozens of real-world vessel classes with many numeric fields), consider CSV or JSON source tables plus a small loader that validates them in a test. That makes bulk editing and review in git easier. This is a trade-off for the user to decide, not a default.
- [Inference] Keep user-modifiable game data out of `custom/`. The `custom/` contract covers graphics and audio only. Loading `.tres` from user folders would be a separate, unapproved modding feature.
- [Inference] Between simulation modules, use **explicit method calls** with injected dependencies, for example `SonarModel.new(propagation, ocean_env)`. Synchronous calls are easier to unit-test and keep ordering deterministic. Use **signals** at the edge, where the simulation notifies the presentation layer (contact detected, torpedo launched). Rendering and UI can subscribe without the simulation knowing about them.
- [Inference] The simulation needs no autoload. One `SimulationWorld` instance owned by the game scene (or test) is enough. Propose an autoload only if the user approves a cross-scene service, for example career or campaign persistence across scene changes.

### Gaps
- I did not retrieve an official Godot statement on the security of loading `.tres` or `.res` files from untrusted locations. Community reports say Resources can embed scripts, but I did not verify this in this session.
- I found no published benchmark comparing Resource vs JSON load times for large definition sets.

## 5. Performance at scale: threading, large world coordinates and LOD

### Takeaway
`WorkerThreadPool.add_group_task` suits per-contact or per-bearing acoustic work, as long as workers touch only plain data, never the active scene tree. Double-precision engine builds require compiling a custom engine and export templates, which this project's no-build-infrastructure rule disfavours. Keeping world positions in 64-bit GDScript floats in the simulation and rendering relative to a local origin avoids both.

### Cited Findings
- [Fact] WorkerThreadPool is a singleton that starts worker threads at project startup. `add_group_task(action, elements, tasks_needed=-1, high_priority=false)` calls the Callable once per element index and can spread the work across all workers. "Every task must be waited for completion." Performance can drop when the distributed work is not expensive. — [WorkerThreadPool class ref (4.7)](https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html)
- [Fact] "Interacting with the active scene tree is not thread-safe". Use `call_deferred` or `set_deferred` instead. Building scene chunks outside the active tree is fine, ideally from a single loader thread. — [Thread-safe APIs (4.7)](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html)
- [Fact] Reading and writing GDScript array or dictionary elements from several threads is fine, but changing container size requires a mutex. AStar classes are not thread-safe. — [Thread-safe APIs (4.7)](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html)
- [Fact] Thread creation is slow, "especially on Windows", so create threads ahead of time. Always call `wait_to_finish()`. — [Using multiple threads (4.7)](https://docs.godotengine.org/en/stable/tutorials/performance/using_multiple_threads.html)
- [Fact] Large world coordinates require recompiling the editor and export templates with SCons `precision=double` and using them as custom export templates. The result costs performance and memory. "Only enable large world coordinates if you actually need them." — [Large world coordinates (4.7)](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html)
- [Fact] Single precision represents every integer up to ±16,777,216. The recommended limits run from 16,384–32,768 units for top-down 3D up to 32,768–65,536 for "any 3D game", and beyond that double precision is "usually required". 2D rendering does not benefit from double precision and "can snap starting from a few million pixels". In double builds, some shader features (triplanar mapping, `world_vertex_coords`, GPUParticles3D without local coords) still jitter. — [Large world coordinates (4.7)](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html)
- [Fact] The docs suggest "origin shifting" as the alternative. It works with single-precision floats but adds game-logic complexity. — [Large world coordinates (4.7)](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html)
- [Fact] Rendering and physics servers can be used from threads only if thread-safe operation is enabled in project settings. — [Thread-safe APIs (4.7)](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html)

### Estimates
- [Estimate] float32 spacing near a coordinate value x is about 2^(floor(log2 x) − 23). That gives about 0.008 m at 100 km, about 0.06 m at 1,000 km and about 0.25–0.5 m at 3,000–4,000 km from the origin. A single-precision `Vector3` therefore cannot hold ocean-basin positions accurately enough for close-quarters torpedo geometry or smooth 3D rendering.

### Inferences
- [Inference] Keep **simulation positions** as 64-bit scalars (GDScript `float`, or `PackedFloat64Array` for bulk arrays), either geodetic (lat/lon/depth) or local tangent-plane metres in doubles. Never use `Vector3` for world-scale positions in the simulation.
- [Inference] The **3D view** (periscope, external camera) renders only a local bubble of a few tens of km around the player and converts double positions to `Vector3` relative to the player each frame. This is an origin-shifting scheme confined to the presentation layer, so no custom engine build is needed. It is consistent with guideline 4.
- [Inference] The **2D tactical map** likewise draws relative to the view centre, so canvas coordinates stay small. That avoids the documented 2D snapping at millions of pixels.
- [Inference] **Threading plan**: run acoustic detection as `add_group_task` over contacts (or contact × sensor pairs). Workers read an immutable snapshot and write into a preallocated per-index results array, and the main thread waits and merges in index order to keep things deterministic. Introduce this only after profiling. Single-threaded code is simpler to test and deterministic by default.
- [Inference] **LOD for simulation**: give distant, undetected contacts a coarse "strategic" representation (waypoint interpolation, low update rate) and promote them to full kinematics and acoustics inside a tactical radius. This keeps hundreds of contacts affordable.

### Gaps
- I did not retrieve the project setting name or default for the WorkerThreadPool thread count.
- No measured figures for how many contacts GDScript can update per millisecond in Godot 4.7. This needs an in-project benchmark.

## 6. Rendering: ocean surface, underwater, periscope, mid-range PC, 2D tactical map and instruments

### Takeaway
Several FFT ocean projects target Godot 4. The most popular, 2Retr0/GodotOceanWaves, is MIT-licensed but describes itself as an experiment with known artifacts and no releases. Newer 4.7-era options have unverified licences. Instrument-heavy UI is a good fit for Control nodes with cached custom `_draw()`. A small but credible commercial precedent exists for instrument-driven sims in Godot (PVKK, see Section 10).

### Cited Findings
- [Fact] **2Retr0/GodotOceanWaves** is "FFT-based ocean-wave rendering, implemented in Godot": a Stockham FFT on compute shaders through RenderingDevice, a TMA (JONSWAP-based) spectrum, Jacobian foam, multiple cascades and GPUParticles3D sea spray. It has an MIT licence, about 3.4k stars, 18 commits and no published releases. Its listed issues include tiling artifacts at distance, stutter on frames when the wave pipeline runs, and uncertain cascade phase offsetting. Buoyancy and underwater rendering are not mentioned. — [GitHub: 2Retr0/GodotOceanWaves](https://github.com/2Retr0/GodotOceanWaves)
- [Fact] A search summary reported one forum user who saw no waves in Godot 4.5+ with the original GodotOceanWaves until using a fixed fork. Treat this as a single user report. — [GitHub: sebbasim/GodotOceanWaves (fork)](https://github.com/sebbasim/GodotOceanWaves)
- [Fact] Other options: **tessarakkt/godot4-oceanfft** (Tessendorf FFT waves plus buoyancy, using compute shaders; licence not confirmed), **OceanPro 1.0** (GPU FFT ocean for Godot 4.7), **Swell** (free FFT/Gerstner preview for 4.7.2+) and **Boujie Water Shader** (MIT, Gerstner vertex waves). — [relatedrepos: godot4-oceanfft](https://relatedrepos.com/gh/tessarakkt/godot4-oceanfft); [Forum: OceanPro 1.0](https://forum.godotengine.org/t/oceanpro-1-0-gpu-fft-ocean-system-for-godot-4-7/144004); [Forum: Swell](https://forum.godotengine.org/t/swell-a-free-water-system-for-godot-4-7-2-some-4-8-features/146916); [Asset Library: Boujie Water Shader](https://godotengine.org/asset-library/asset/2070)
- [Fact] Custom drawing works on any CanvasItem, including Control. `_draw()` output is cached until `queue_redraw()` is called. `draw_multiline` batches many segments into one call. Custom drawing avoids the overhead of many nodes. Some draw methods lack an `antialiased` parameter, and 2D MSAA (2x/4x/8x) is the viewport-wide fallback at higher cost. — [Custom drawing in 2D (4.7)](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html)
- [Fact] Double-precision builds do not improve 2D rendering, which snaps at a few million pixels from the origin. — [Large world coordinates (4.7)](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html)
- [Fact] Godot 4.7 added HDR output on Windows, macOS, iOS, visionOS and Linux (Wayland). — [Godot 4.7 release coverage](https://phoronix.com/news/godot-4.7-released)

### Inferences
- [Inference] A submarine command sim spends most of its screen time on 2D instruments: tactical plot, sonar waterfall and BTR, TMA dot stacks and gauges. Make these **Control nodes with custom `_draw()`** that read from simulation state and redraw only on simulation ticks, not every frame. A sonar waterfall works best as an `Image` updated one row per tick and shown through an `ImageTexture` (update or scroll rows instead of redrawing thousands of primitives).
- [Inference] **Periscope view**: a `SubViewport` with its own `Camera3D` rendering the local ocean bubble, composited into the UI with a reticle overlay, is a standard Godot pattern. Rendering the periscope only while the periscope station is open keeps GPU cost bounded.
- [Inference] **Ocean choice**: treat any third-party ocean as replaceable presentation behind a small interface, for example `get_wave_height(x, z, t)` for periscope wash and surfaced handling, so the simulation never depends on it. Compute-shader FFT oceans need RenderingDevice, which is not available in the Compatibility renderer. Start with a simple Gerstner shader (Boujie, MIT) in an early milestone and evaluate an FFT ocean later. Check licence and maintenance on the version actually pinned.
- [Inference] **Underwater**: for a command sim, exterior underwater views are optional. If needed, depth fog (Environment fog or FogVolume) plus a low-pass audio bus is a cheap first approach.

### Gaps
- I did not find benchmark numbers (fps or GPU ms on mid-range GPUs) for any Godot 4 FFT ocean. Mid-range PC performance is unquantified.
- I did not confirm licences for godot4-oceanfft, OceanPro or Swell, or the minimum Godot version for GodotOceanWaves.
- I found no dedicated, maintained Godot 4 underwater-rendering addon, and did not research FogVolume underwater setups specifically.

## 7. Audio: procedural sonar (AudioStreamGenerator), bus effects and spatial audio for hydrophone listening

### Takeaway
Godot has what hydrophone listening needs: AudioStreamGenerator for synthesized tonals and broadband noise, and bus effects (LowPass, BandPass, Notch, EQ, Reverb, SpectrumAnalyzer) for shaping and analysing sound. Synthesis in GDScript is officially discouraged at full sample rates, so plan for low mix rates, pre-rendered loops, or a compiled kernel.

### Cited Findings
- [Fact] AudioStreamGenerator "expects a script to generate audio data", filled through `AudioStreamGeneratorPlayback.push_frame` with `get_frames_available()`. Defaults are `mix_rate` 44100 Hz and `buffer_length` 0.5 s. Lower buffer lengths reduce latency but raise CPU cost and the risk of crackling. The docs say lower sample rates such as 32,000 or 22,050 Hz may be usable for low-pitched sounds "with no loss in quality". — [AudioStreamGenerator class ref (4.7)](https://docs.godotengine.org/en/stable/classes/class_audiostreamgenerator.html)
- [Fact] "Due to performance constraints, this class is best used from C# or from a compiled language via GDExtension". From GDScript, the docs suggest 11,025 or 22,050 Hz. — [AudioStreamGenerator class ref (4.7)](https://docs.godotengine.org/en/stable/classes/class_audiostreamgenerator.html)
- [Fact] Bus effects in 4.7 include LowPass (the docs cite "underwater" muffling as a use), HighPass, BandPass, BandLimit, Notch, EQ6/EQ10/EQ21, Compressor (sidechain-capable), HardLimiter, Reverb, Delay, Distortion, Chorus, Phaser, PitchShift, Panner, StereoEnhance, Amplify, SpectrumAnalyzer (for visualizations), Capture (ring buffer) and Record. These effects do not work with `AudioSample` playback. — [Audio effects (4.7)](https://docs.godotengine.org/en/stable/tutorials/audio/audio_effects.html)
- [Fact] `Engine.time_scale` "does not affect audio playback speed". — [Engine class ref (4.7)](https://docs.godotengine.org/en/stable/classes/class_engine.html)

### Inferences
- [Inference] Model hydrophone audio as **non-spatial** (2D) playback driven by the simulation. For the steered bearing, the sonar module computes each contact's received level and frequency content, then sets per-contact player volume and filter cutoffs, or synthesizes a mix. 3D positional audio models a listener in air, not a beamformed array, so it is the wrong abstraction.
- [Inference] A cheap staged approach: (1) looped recorded or pre-synthesized noise and tonal samples per contact class, with volume, low-pass and band-pass driven by the sonar model; (2) later, AudioStreamGenerator synthesis at 11–22 kHz, which covers the low-frequency band where most submarine signatures live, moved to C# or GDExtension if profiling demands.
- [Inference] Drive visual sonar displays (waterfall, LOFAR) from the **simulation's** computed spectra, not from `AudioEffectSpectrumAnalyzer`. That keeps displays deterministic and testable headless. Use the analyzer only for cosmetic visualizers.
- [Inference] Time compression must mute or duck hydrophone audio, since audio does not scale with `time_scale` and the simulation runs faster than real time.

### Gaps
- I did not fetch the AudioStreamPlayer3D / spatial audio docs, and found no Godot precedent for sonar or hydrophone audio.
- No measured CPU cost for AudioStreamGenerator in GDScript at a given mix rate.

## 8. Testing: GUT vs GdUnit4 versions, Godot compatibility, headless CLI and CI

### Takeaway
Both frameworks are active and support Godot 4.7-era versions. GUT 9.7.1 explicitly targets 4.7.x and exits with code 1 on failure. GdUnit4 v6.x needs Godot 4.5+, has CLI scripts with richer exit codes and HTML/JUnit reports, and supports C#. Either works for headless logic tests. GUT's explicit per-minor version table makes pinning simpler, and GdUnit4 is the better choice if C# is chosen.

### Cited Findings
- [Fact] GUT compatibility: 9.7.1 → 4.7.x (godot_4_7 branch), 9.6.1 → 4.6.x, 9.5.0 → 4.5.x, 9.4.0 → 4.3–4.4. GUT is MIT-licensed. Features include full and partial doubles, stubs, spies, parameterized tests, inner test classes, a CLI and JUnit XML export. — [GUT README](https://raw.githubusercontent.com/bitwes/Gut/main/README.md)
- [Fact] GUT CLI: `godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd` with options such as `-gdir`, `-gtest`, `-gexit`, `-gexit_on_success` and `-gjunit_xml_file`. Config is read from `res://.gutconfig.json`. "`0` will be returned if all tests pass and `1` will be returned if any fail." — [GUT Command Line docs](https://gut.readthedocs.io/en/latest/Command-Line.html)
- [Fact] GdUnit4: v6.0.0 requires at least Godot 4.5. The Asset Library lists v6.2.0, built on Godot 4.5 .NET, dated 2026-07-30. The docs site offers v6.2.x, v6.1.x, v6.0.x and v5.1.x. — [GdUnit4 docs](https://mikeschulze.github.io/gdUnit4/latest); [Asset Library: GdUnit4](https://godotengine.org/asset-library/asset/4390); [GdUnit4 CLI docs](https://godot-gdunit-labs.github.io/gdUnit4/latest/advanced_testing/cmd/)
- [Fact] GdUnit4 CLI: `addons/gdUnit4/runtest.sh` (or `runtest.cmd`) with `GODOT_BIN` set, `-a <dir>` to add tests, `-i` to ignore, and `-c` to continue after failures (by default the run aborts on the first failure). Reports go to `res://reports` as HTML (`index.htm`) and JUnit XML (`results.xml`). Exit codes are 0 (pass), 100 (failures) and 101 (warnings). — [GdUnit4 CLI docs](https://godot-gdunit-labs.github.io/gdUnit4/latest/advanced_testing/cmd/)
- [Fact] gdUnit4Net provides C# test support. — [gdUnit4Net releases](https://www.github.com/MikeSchulze/gdUnit4Net/releases/latest)

### Inferences
- [Inference] The project's simulation-first architecture (RefCounted modules, no scene tree) makes almost every essential test a pure logic test, runnable headless by either framework. Only the asset-resolver and presentation smoke tests need a SceneTree.
- [Inference] For GDScript, **GUT** is the simpler pin: one version per Godot minor, plain 0/1 exit codes and JUnit output. For C#, **GdUnit4 + gdUnit4Net**. Record the choice and exact commands in `PROJECT_BRIEF.md` when the first module is implemented, as `tests/README.md` requires.
- [Inference] Write CI or command examples as documentation only. Guideline 4 forbids speculative CI build or export workflows, although a test-only CI job is not an export. Ask the user before adding any workflow file.

### Gaps
- I did not confirm that GdUnit4 v6.2.x is tested against Godot 4.7, nor its `--headless` flag requirements (older versions needed `--ignoreHeadlessMode`; not verified here). Check its release notes before pinning.
- GUT's docs page does not mention `--headless` or the need to import the project (`--import`) before the first CI run. Verify in practice.

## 9. Runtime loading of user override files (`custom/` contract), and bathymetry and geography data

### Takeaway
All APIs named in `assets/README.md` exist in 4.7. **Runtime WAV loading (`AudioStreamWAV.load_from_file`) was added in Godot 4.4.** It is missing from the 4.3 class reference and announced in the 4.4 release notes. So with a pinned 4.7, PNG, OGG Vorbis and WAV can all be supported overrides without custom parsers. For bathymetry, GEBCO (public domain with attribution) and NOAA ETOPO 2022 (CC0) are both freely usable in a commercial game, but the global 15-arc-second grids are multi-gigabyte and must be preprocessed offline.

### Cited Findings
- [Fact] Godot 4.7 runtime loading: `Image.load_from_file` (format by extension; buffer loaders for JPG, KTX, PNG, SVG, TGA, WebP, EXR), displayed with `ImageTexture.create_from_image`. Runtime audio supports Ogg Vorbis, MP3 and WAV (the example uses `AudioStreamOggVorbis.load_from_file`). Runtime loading should not be used for project resources. — [Runtime file loading and saving (4.7)](https://docs.godotengine.org/en/stable/tutorials/io/runtime_file_loading_and_saving.html)
- [Fact] Caveats in the same doc: ".ogg" files are not always Vorbis. Opus audio or Theora video will not load as audio. Call `generate_mipmaps()` on images used on 3D surfaces, and the doc recommends it for 2D downsampling too. — [Runtime file loading and saving (4.7)](https://docs.godotengine.org/en/stable/tutorials/io/runtime_file_loading_and_saving.html)
- [Fact] The Godot 4.3 AudioStreamWAV class reference lists only `save_to_wav` (no `load_from_file` or `load_from_buffer`), and the 4.3 runtime-loading tutorial said runtime WAV/MP3 loading was not supported. — [AudioStreamWAV (4.3)](https://docs.godotengine.org/en/4.3/classes/class_audiostreamwav.html); [Runtime loading (4.3)](https://docs.godotengine.org/en/4.3/tutorials/io/runtime_file_loading_and_saving.html)
- [Fact] The Godot 4.4 release notes state: "You can now load WAV files at runtime", "just like OGG Vorbis audio tracks already allowed". The 4.4 class reference documents `AudioStreamWAV.load_from_file(path, options)`, with option keys mirroring ResourceImporterWAV (for example `force/max_rate`). — [Godot 4.4 release](https://godotengine.org/releases/4.4/); [AudioStreamWAV (4.4)](https://docs.godotengine.org/en/4.4/classes/class_audiostreamwav.html)
- [Fact] The 4.7 runtime-loading doc contains no security warning about loading untrusted files. — [Runtime file loading and saving (4.7)](https://docs.godotengine.org/en/stable/tutorials/io/runtime_file_loading_and_saving.html)
- [Fact] **GEBCO**: the GEBCO Grid "is placed in the public domain and may be used free of charge". Users may copy, distribute, adapt and commercially exploit it, but must acknowledge the source, must not imply endorsement by GEBCO, IHO or IOC, and must not use it for navigation or safety at sea. The current release is GEBCO_2025, a 15-arc-second global terrain model. — [GEBCO terms of use](https://www.gebco.net/data-products/gridded-bathymetry/terms-of-use); [GEBCO_2025 Grid](https://www.gebco.net/data-products-gridded-bathymetry-data/gebco2025-grid)
- [Fact] Older or mirrored GEBCO terms differ: an older BODC copy mentions copyright and database rights, and a CEDA record lists UK OGL v3 for GEBCO_2020. The current gebco.net terms take precedence. — [BODC older terms](https://www.bodc.ac.uk/data/documents/nodb/289621/); [CEDA GEBCO_2020 record](https://catalogue.ceda.ac.uk/uuid/4ad3e42245174dee86ca27f8e1bb2e87/)
- [Fact] **NOAA ETOPO 2022** (15 arc-second global relief) is not under US copyright, and NOAA waives rights worldwide under CC0-1.0. The record adds that the user is responsible for results of any use other than the intended purpose. DOI 10.25921/fd45-gt74. — [NCEI ETOPO product page](https://www.ncei.noaa.gov/products/etopo-global-relief-model); [data.gov record](https://catalog.data.gov/dataset/etopo-2022-15-arc-second-global-relief-model); [DOI](https://doi.org/10.25921/Fd45-Gt74)

### Estimates
- [Estimate] A global 15-arc-second grid is 86,400 × 43,200 ≈ 3.7 billion cells. At 16 bits per cell that is about 7.5 GB uncompressed, far too large to ship or load whole.

### Inferences
- [Inference] With 4.7 pinned, the resolver can accept `.png` (graphics) and `.ogg`/`.wav` (audio) using only engine loaders, which satisfies the `assets/README.md` "WAV only if the pinned version supports it" condition. Treat a non-Vorbis `.ogg` as an *invalid* override: `push_warning` and fall back.
- [Inference] Bathymetry pipeline: preprocess offline (outside the game, a documented data-prep step) into regional tiles at game-appropriate resolution, for example 15″ only around theatres of operation and coarser elsewhere. Store them as 16-bit PNG/EXR or raw `PackedInt16Array` blobs in `res://`. Ship the GEBCO attribution in the credits. ETOPO 2022 (CC0) needs no attribution, but citing the DOI is good practice. A preprocessing script is tooling, so it needs user approval before it is added.
- [Inference] Keep bathymetry and sound-speed data access behind an `OceanEnvironment` module interface such as `depth_at(lat, lon)`. Acoustic propagation and navigation then stay testable with synthetic flat or sloped seabeds.

### Gaps
- I did not find the specific Godot pull request that added `AudioStreamWAV.load_from_file`. The 4.4 attribution rests on the 4.3 vs 4.4 class references plus the 4.4 release notes.
- Coastline vector sources (for example Natural Earth or GSHHG) and their licences were not researched in this session.
- Ocean-property datasets for acoustics (sound-speed profiles, temperature and salinity, for example the World Ocean Atlas) were not covered.

## 10. Precedents: games shipped with Godot 4, naval and sim titles, and reported pain points

### Takeaway
Godot now has major commercial successes, most notably Slay the Spire 2, plus credible sim-adjacent precedents: PVKK (an instrument-heavy cannon-operation sim from the Dome Keeper studio), ΔV: Rings of Saturn (hard-physics space sim, Godot 3) and Road to Vostok (realistic survival FPS ported to Godot). I found **no commercial naval or submarine simulator built in Godot**, only game-jam submarine titles. The reported pain points are minor-version regressions and performance. Shipped studios report compiling custom editors and investing in profiling.

### Cited Findings
- [Fact] Slay the Spire 2 (Mega Crit) moved from Unity to Godot after the 2023 runtime-fee controversy, entered Steam Early Access on March 5, 2026, and is described as the most popular game made with Godot. Mega Crit renewed sponsorship at Corporate Platinum level (about €36,000 per year) in April 2026. — [PC Gamer](https://pcgamer.com/games/card-games/slay-the-spire-2-ditched-unity-for-open-source-engine-godot-after-2-years-of-development); [GamesRadar](https://www.gamesradar.com/games/roguelike/steam-stats-for-slay-the-spire-2s-engine-godot-show-strong-signs-of-exponential-growth/); [GamingOnLinux](https://www.gamingonlinux.com/2026/04/godot-gets-a-funding-boost-from-slay-the-spire-2-devs-mega-crit)
- [Fact] **PVKK: Planetenverteidigungskanonenkommandant** (Bippinbits, the Dome Keeper developers) is built with Godot. The player manually operates a complex planetary-defence cannon from a bunker. Steam lists a planned release of 2027. A GodotCon 2024 talk by lead dev Raffaele Picca covered where Godot helped and where it posed challenges, including scene setup, post-processing and optimization. — [Godot showcase: PVKK](https://godotengine.org/showcase/planetenverteidigungskanonenkommandant/); [GodotCon 2024 talk](https://talks.godotengine.org/godotcon-24/talk/P339BT/); [PC Gamer](https://www.pcgamer.com/games/sim/pvkks-full-title-is-literally-too-big-for-our-website-and-the-devs-say-its-space-invaders-but-the-cannon-you-fire-is-really-complicated/); [Steam](https://store.steampowered.com/app/2956040)
- [Fact] **ΔV: Rings of Saturn** (Kodera Software) is a hard-sci-fi space sim with Newtonian physics built on Godot. It was ported to Godot 3.2.1 in 2020 and fully released on 21 July 2023, with modest minimum specs (i3, 4 GB RAM). It is a Godot 3, not Godot 4, precedent. — [Wikipedia](https://en.wikipedia.org/wiki/%CE%94V:_Rings_Of_Saturn); [Kodera devlog 0.163.7](https://koder.itch.io/dv-rings-of-saturn/devlog/130990/01637-tales-from-the-rings); [GamingOnLinux](https://www.gamingonlinux.com/2023/07/dv-rings-of-saturn/page=1/)
- [Fact] **Road to Vostok** (solo developer Antti Leinonen) was ported from Unity to Godot in three months, taking 615 hours. Sources disagree on whether the switch was announced in September or October 2023. — [PC Gamer](https://pcgamer.com/hardcore-survival-shooter-road-to-vostok-is-looking-really-good-after-switching-engines-from-unity-to-godot); [80.lv](https://80.lv/articles/this-upcoming-survival-shooter-game-switches-from-unity-to-godot); [Automaton](https://automaton-media.com/articles/newsjp/20230929-266624/)
- [Fact] **Halls of Torment**: a GodotFest 2025 talk (Paul Lawitzki, 2025-11-11) on "making commercial games in Godot" covers project structure, communication in modular entities, performance profiling, and "the benefits of compiling a custom Godot editor". — [media.ccc.de](https://media.ccc.de/v/godotfest2025-a-peek-under-the-hood-technical-learnings-from-halls-of-torment)
- [Fact] The official Godot showcase lists Slay the Spire 2, Halls of Torment, Brotato, Dome Keeper, Cassette Beasts, Buckshot Roulette, ΔV: Rings of Saturn and PVKK (coming soon), but no naval titles. — [Godot showcase](https://godotengine.org/showcase/)
- [Fact] Submarine games found in Godot are small itch.io jam or hobby projects, for example *Subseeker* (Godot 4.0.3) and *Himmelfahrt* (submarine commander). — [Subseeker](https://wingedadventurer.itch.io/subseeker); [Himmelfahrt](https://ewandos.itch.io/himmelfahrt)
- [Fact] Developer-reported pain points around Godot 4.1 include regressions and stability problems serious enough that teams considered switching engines. — [Alien Express devlog (Godot 4.1.1)](https://sangot.itch.io/alien-express/devlog/622796/problems-we-faced-with-godot-411-and-why-we-may-change-game-engine); [Techno Tabby devlog (Godot 4.1.3)](https://darngeek.itch.io/technotabbyrefuge/devlog/638669/godot-413-and-our-struggles)
- [Fact] The Godot Foundation has published an article titled "What's missing in Godot for AAA". I did not read its contents. — [Godot blog](https://godotengine.org/article/whats-missing-in-godot-for-aaa/)

### Inferences
- [Inference] Godot 4 has proven commercially viable for UI-heavy and systems-heavy games (Slay the Spire 2, PVKK). The submarine sim's riskiest parts are custom simulation code and data, not engine features. That supports a simulation-first staged plan: (1) headless simulation core with tests (kinematics, time compression, save/load); (2) 2D tactical plot and instruments; (3) sonar model plus simple audio; (4) bathymetry and environment; (5) the 3D periscope and ocean as late, replaceable presentation; (6) career and campaign layers.
- [Inference] The 4.1-era complaints are about regressions in a then-young 4.x. The current policy of supported branches with patch releases, plus pinning a minor version, reduces that risk. "Compiling a custom editor" (Halls of Torment) is a power-user step this project should avoid unless the user explicitly approves it.

### Gaps
- No commercial naval, submarine or modern-military command simulator made in Godot was found. Engine identities of naval sims on Steam (Sails of Steel, Fleets of Valor, Battleship Command and others) were not stated in search results ([example](https://store.steampowered.com/app/3367430/Battleship_Command/)).
- I could not confirm the Godot major version used by PVKK, or the language (GDScript or C#) used by Slay the Spire 2.
- I did not retrieve the contents of the Halls of Torment and PVKK talks, so their specific lessons are not summarized here.
