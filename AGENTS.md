# AGENTS.md

This file provides guidance and important rules working with code in this repository.

## When coding / building plan

- Use a progressive disclosure approach for agent coding in this repository: start from high-level
  information in the Basic Memory knowledge base first, and only locate/read specific files or
  symbols when necessary, instead of expanding a large amount of context at once.

#### Basic Memory knowledge base (project-scoped, `memory/`)

- Notes live in `memory/` (markdown with YAML frontmatter: `title`/`type`/`permalink`), tracked in git.
- This repository contains the standalone HeapPatch plugin, extracted from MetaHookSv
  `Plugins/HeapPatch`. Its notes were migrated from MetaHookSv and adapted to the CMake workspace; see
  `memory/project_overview.md` for scope and provenance.
- Basic Memory is registered as MCP server `basic-memory`, pinned to the `heappatch` project
  (project-level `.mcp.json`, mirrored by `.codex/config.toml`). The `metahooksv` project belongs to
  the source repository.
- Prefer Basic Memory MCP tools (`search_notes` / `read_note` / `write_note` / `edit_note`) only when
  their project resolves to this repository's `memory/` directory. Verify the project binding before
  writing; when no matching project is available, read and edit the local markdown files directly.
- Notes use the `heappatch/` permalink prefix to distinguish them from the source repository.
- Historical records are not current evidence: the migrated note retains MetaHookSv paths and refers
  to `src/metahook.cpp`, which belongs to the host loader, not to this repository. Do not extend an
  old statement to a new change without checking the code.

#### High-level information in this repository (read corresponding notes first)

- Project overview, provenance, patch pipeline and dependency boundaries: `project_overview`

#### When notes are insufficient: source entry points (query and read on demand)

- Build: `CMakeLists.txt`, `cmake/Sources.cmake` (explicit compile list), `cmake/Dependencies.cmake`
  (source-path resolution and FetchContent fallback), `cmake/VCLTL.cmake`,
  `scripts/build-HeapPatch-x86-{Debug,Release}.bat`
- Plugin sources: `src/`; lifecycle entry `src/plugins.cpp`, patch pipeline `src/privatehook.cpp`,
  shared globals `src/plugins.h`, engine function table `src/exportfuncs.cpp`
- Public API / interface: MetaHook's `include/metahook.h`, `include/Interface/` and
  `include/HLSDK/common/interface.cpp`, consumed as an SDK and never built as a host
- gamedata: `scripts/manifests/heappatch.json` (the `Sys_InitMemory_HeapLimitPatches_0` patch symbol
  plus the `numberedPatchSets` prefix), `scripts/sync-gamedata.py`, `scripts/validate-gamedata.py`;
  the build-time sync prunes the upstream catalog into the nested `metahook/gamedata/heappatch/`
  directory, which the host launcher merges
- Docs: `README.md` (installation, `-heaplimit_override`, build). There is no Chinese README, no
  `docs/` directory and no test suite in this repository
- External sources, all read-only inputs: `METAHOOK_SOURCE_PATH` (must provide `include/metahook.h`,
  `include/HLSDK/common/interface.cpp` and `include/Interface/IPlugins.h`) and
  `CAPSTONE_INCLUDE_DIRS` (headers only; `CAPSTONE_LIBRARY_DIRS` is ignored because the plugin does
  not link Capstone). Empty paths fall back to pinned FetchContent; VC-LTL 5.3.1 is downloaded into
  `thirdparty/cache`
- Build output: `build/x86/<configuration>/`; install output: `install/x86/<configuration>/`. Neither
  is tracked, and nothing is deployed to the game automatically

#### Progressive disclosure key points

- Read notes first, then locate a single file/symbol; do not read the whole repository at once.
- Prefer correctly scoped Basic Memory MCP tools for knowledge retrieval; otherwise use the local
  notes before reading source.
- Prefer Context7 for external dependency/library usage (query on demand).

## Repository rules

- Preserve the MetaHook API, plugin exports and calling conventions. Match the naming, indentation and
  comment style of the files you touch.
- Patch sites come only from gamedata and the host gamedata contract. Do not reintroduce signature
  search, hard-coded patch counts, fixed offsets or old-immediate matching; disassembly may only
  locate the immediate field inside an already-resolved instruction. When the new pipeline is
  impossible, fail loudly (as `Sys_Error` does today) instead of adding a fallback.
- Keep the `static_assert(METAHOOK_API_VERSION >= 110)` guard in sync with the APIs actually used;
  the plugin depends on `IsGameSymbolAvailable` and `MH_GAMESYMBOL_KIND_PATCH`.
- Do not modify external sources or third-party sources. MetaHook and Capstone are read-only build
  inputs; HeapPatch links no third-party library.
- The plugin builds for MSVC x86 only. Keep the static CRT / VC-LTL and warning-level settings in
  `CMakeLists.txt` in sync with the other standalone plugin repositories.
- When gamedata usage changes, update `scripts/manifests/heappatch.json` in the same change, including
  `numberedPatchSets` when the numbered symbol family changes.
- Verification distinguishes build checks from a real game run: there is no test suite here, so a
  successful configure/build says nothing about whether a patch site resolves or the heap limit
  actually increases at runtime. Claims about in-game behavior must not be made without evidence.
  Documentation changes need content, path and format checks, not a plugin rebuild.

## Explore SKILLs

- Project-level skills, when present, live in `.claude/skills` no matter what harness tool is being
  used.
