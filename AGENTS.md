# AGENTS.md - HeapPatch Project Guide

## Project Overview

**HeapPatch** is a utility plugin for MetaHookSV that raises the hard-coded engine heap limit of GoldSrc / SvEngine. It resolves the gamedata PATCH records numbered `Sys_InitMemory_HeapLimitPatches_0..N`, decodes the instruction at each resolved address, and rewrites the DWORD immediate operand to a larger byte value (256 MB by default), mitigating out-of-memory failures caused by the fixed cap in `Sys_InitMemory`.

The plugin is tiny and self-contained: three translation units, one patch pipeline, no UI, no test suite. Read the sources directly instead of hunting for more documents.

- **Project type**: Native C++ plugin (Windows DLL), MSVC x86 only
- **Engine**: GoldSrc / SvEngine
- **Framework**: MetaHookSV Plugin API (`IPluginsV4`, API 110 or newer)
- **Main dependencies**: MetaHook SDK (public API + `include/HLSDK/common/interface.cpp`) and Capstone headers. No third-party library is linked

## Project Structure

```
HeapPatch/
├── src/
│   ├── plugins.cpp            # IPluginsV4 lifecycle: Init / LoadEngine / LoadClient / ExitGame
│   ├── plugins.h              # Engine + plugin globals, MHPluginName, Sys_Error wrapper
│   ├── privatehook.cpp        # The whole patch pipeline: resolve, decode, rewrite
│   ├── privatehook.h          # Engine_FillAddress / Engine_InstallHooks / Engine_UninstallHooks
│   ├── exportfuncs.cpp/.h     # Shared cl_enginefunc_t gEngfuncs instance
│   └── enginedef.h            # MetaHook include shim
├── cmake/
│   ├── Sources.cmake          # Explicit compile list
│   ├── Dependencies.cmake     # Source-path resolution and FetchContent fallback
│   ├── LaunchGame.cmake       # Optional F5 deploy support
│   └── VCLTL.cmake            # VC-LTL 5.3.1
├── scripts/
│   ├── build-HeapPatch-x86-{Debug,Release}.bat
│   ├── manifests/heappatch.json   # Gamedata manifest (patch symbol + numberedPatchSets)
│   ├── sync-gamedata.py           # Prunes the upstream catalog into the build tree
│   └── validate-gamedata.py       # Validates it before the plugin target builds
├── thirdparty/cache/          # Ignored VC-LTL binary cache
├── build/x86/<configuration>/    # Ignored build output
├── install/x86/<configuration>/  # Ignored install output
└── CMakeLists.txt             # Windows MSVC x86 build and install rules
```

## Core Module: the patch pipeline (`src/privatehook.cpp`)

### Lifecycle

`src/plugins.cpp` implements `IPluginsV4` and exports it through
`EXPOSE_SINGLE_INTERFACE(IPluginsV4, IPluginsV4, METAHOOK_PLUGIN_API_VERSION_V4)`:

- `Init`: stores the host API / interface / engine save
- `LoadEngine`: collects the file system (`FileSystem` or `FileSystem_HL25`), engine type, buildnum and `g_EngineDLLInfo.ImageBase`, copies `cl_enginefunc_t`, then runs `Engine_FillAddress()` followed by `Engine_InstallHooks()`
- `LoadClient`: only copies the export table
- `ExitGame`: calls `Engine_UninstallHooks()`, which is empty — see below

### Address resolution (`Engine_FillAddress`)

Patch sites come **only** from gamedata:

1. Format `Sys_InitMemory_HeapLimitPatches_%d` and check `IsGameSymbolAvailable`
2. Resolve each hit with `ResolveGameSymbol(engineBase, name, MH_GAMESYMBOL_KIND_PATCH, &address)`
3. Index 0 is required; the first `MH_GAMESYMBOL_SYMBOL_NOT_FOUND` after it ends the enumeration; any other status is fatal
4. Every failure path reports symbol, module, engine buildnum, CRC64 and the status string through `Sys_Error`

The number of patch sites is never hard-coded: the plugin walks indices until the first gap, so the upstream catalog decides how many immediates are rewritten.

### Immediate rewrite (`Engine_InstallHooks`)

- Default heap limit is **256 MB**; `-heaplimit_override` (via `gEngfuncs.CheckParm`) overrides it and is clamped to `[32, 1024]` MB
- `FindHeapLimitImmediate` decodes exactly one instruction with `DisasmSingleInstruction` and accepts only `MOV` / `CMP` whose second operand is a DWORD immediate (`imm_size == sizeof(DWORD)`, immediate inside the instruction length)
- The written address is `instruction + imm_offset` — the PATCH address is the **instruction** address, not the immediate address
- Every collected site receives the same value via `WriteDWORD`, regardless of its original immediate and of engine type
- `Engine_UninstallHooks` is intentionally empty: the writes are a one-time patch and the original immediates are not restored at shutdown

## Key Code Flow

```
Host loader: CreateInterface V4 + Init
    ↓
IPluginsV4::LoadEngine
    ↓
Copy engine funcs, file system, buildnum, engine image base
    ↓
Engine_FillAddress
    ↓
IsGameSymbolAvailable("Sys_InitMemory_HeapLimitPatches_N")
    ├── index 0 missing              → Sys_Error: patch set missing
    ├── SYMBOL_NOT_FOUND after index 0 → enumeration complete
    ├── other status                 → Sys_Error
    └── OK → ResolveGameSymbol(MH_GAMESYMBOL_KIND_PATCH) → collect instruction address
    ↓
Engine_InstallHooks
    ↓
Read -heaplimit_override, clamp to 32..1024 MB (default 256)
    ↓
Per site: DisasmSingleInstruction → one MOV/CMP with DWORD immediate
    ↓
WriteDWORD at instruction + imm_offset
```

## Build Instructions

Requirements: Windows, Visual Studio 2022, CMake 3.21 or newer, Python 3.8 or newer, MSVC x86 (`-A Win32`), static CRT and VC-LTL 5.3.1.

```bat
scripts\build-HeapPatch-x86-Release.bat
scripts\build-HeapPatch-x86-Debug.bat
```

The scripts configure, build and install. Debug compiles at `/W0`, Release at `/W3` with the SDK's known warnings suppressed plus interprocedural optimization. Output stays in `build/x86/<configuration>/`; the DLL, its PDB and the gamedata catalog are installed to `install/x86/<configuration>/svencoop/metahook/`. Nothing is deployed to the game automatically.

### Dependencies

- **MetaHook SDK**: fetched automatically from the latest `main`; pass `-DMETAHOOK_SOURCE_PATH=D:\MetaHook` or export the same environment variable to build against a local tree. The path is the repository root providing `include/metahook.h`, `include/HLSDK`, `include/Interface` and `include/SourceSDK`
- **Capstone headers**: consumed through the MetaHook API for instruction parsing (`cs_insn`, `X86_INS_MOV` / `X86_INS_CMP`, `x86.encoding`). **Capstone is not linked**, so `CAPSTONE_LIBRARY_DIRS` is ignored. Headers resolve from `CAPSTONE_INCLUDE_DIRS`, else the MetaHook tree's `thirdparty/capstone_fork`, else a pinned commit
- **VC-LTL 5.3.1**: downloaded once into `thirdparty/cache`
- **No third-party library is linked.** MetaHook and Capstone are read-only build inputs

Keep `cmake/Sources.cmake` as the explicit compile list; `include/HLSDK/common/interface.cpp` is compiled in because `EXPOSE_SINGLE_INTERFACE` (which exports `CreateInterface`) lives there.

### gamedata

`scripts/manifests/heappatch.json` declares the single symbol `engine` / `Sys_InitMemory_HeapLimitPatches_0` as a `patch` record plus a `numberedPatchSets` entry with prefix `Sys_InitMemory_HeapLimitPatches`, which makes the synchronizer publish the whole numbered family for each listed game version.

`scripts/manifests/heappatch.json` → `scripts/sync-gamedata.py` → pruned catalog under `build/x86/<Configuration>/assets/svencoop/metahook/gamedata/heappatch`, validated by `scripts/validate-gamedata.py` before the plugin target builds. Disable with `-DHEAPPATCH_SYNC_GAMEDATA=OFF`. When gamedata usage changes, update the manifest in the same change, including `numberedPatchSets` when the numbered symbol family changes.

### Optional F5 debugging

```powershell
cmake -S . -B build/launch -G "Visual Studio 17 2022" -A Win32 -DMETAHOOKSV_ENABLE_LAUNCH_GAME=ON
```

Select **LaunchGame** and press F5; **DeployGame** builds, stages and copies the plugin DLL/PDB/resources into an existing MetaHook installation before the debugger attaches. The feature defaults OFF. See `README.md` for `METAHOOKSV_GAME_*` options.

## Engine Compatibility

Support is decided entirely by the shipped gamedata catalog (`scripts/manifests/heappatch.json`):

| Game build | Support |
| --- | --- |
| `hl-3248`, `hl-3266`, `hl-3329`, `hl-3647`, `hl-4554` | ✅ |
| `hl-6153` | ✅ |
| `hl-8684`, `hl-10210` | ✅ |
| `svencoop-8948`, `svencoop-10257` | ✅ |
| `cof-5936` (Cry of Fear) | ✅ |
| Any build absent from the catalog | ❌ fatal, never a silent no-op |

Catalog coverage is not a correctness statement: a listed build only means patch sites exist, not that they were verified in-game.

## Important Constants and Macros

```cpp
static_assert(METAHOOK_API_VERSION >= 110, ...);  // IsGameSymbolAvailable + MH_GAMESYMBOL_KIND_PATCH
#define MHPluginName "HeapPatch"

// src/privatehook.cpp, Engine_InstallHooks: the limit is a local, not a named constant
auto HeapLimitOverride = 256;                              // default, in MB
HeapLimitOverride = max(min(HeapLimitOverride, 1024), 32);  // clamp after -heaplimit_override
DWORD HeapLimitOverrideInBytes = (DWORD)HeapLimitOverride * 1024 * 1024;
```

Runtime configuration: `HeapPatch.dll` must be listed in the host's `metahook/configs/plugins.lst`, and `metahook/gamedata/heappatch` must stay next to it.

## Debugging Tips

1. **Console output**: `Sys_Error` reports the failing symbol, module, buildnum, CRC64 and status string — read it before anything else
2. **Breakpoint locations**: `Engine_FillAddress()` (resolution), `FindHeapLimitImmediate()` (decode), `Engine_InstallHooks()` (the `WriteDWORD` loop)
3. **Verify the write**: the PATCH address is the *instruction* address. The DWORD is written at `instruction + imm_offset`, so inspect that address, not the one printed by `Sys_Error`

## Repository Rules

- Preserve the MetaHook API, plugin exports and calling conventions. Match the naming, indentation and comment style of the files you touch
- Patch sites come only from gamedata and the host gamedata contract. **Do not** reintroduce signature search, hard-coded patch counts, fixed offsets or old-immediate matching; disassembly may only locate the immediate field inside an already-resolved instruction. When the gamedata pipeline is impossible, fail loudly (as `Sys_Error` does today) instead of adding a fallback
- Keep the `static_assert(METAHOOK_API_VERSION >= 110)` guard in sync with the APIs actually used
- Do not modify external or third-party sources; MetaHook and Capstone are read-only build inputs
- MSVC x86 only. Keep the static CRT / VC-LTL and warning-level settings in `CMakeLists.txt` in sync with the other standalone plugin repositories

## Related Links

- **MetaHookSV**: https://github.com/MetaHookSv/MetaHookSv
- **Capstone**: https://www.capstone-engine.org/
- **Gamedata symbol catalog**: https://hlnd2t.github.io/GoldSrc_VibeSignatures/
