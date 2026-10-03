# HeapPatch

## Raise the GoldSrc / SvEngine engine heap limit

The engine's `Sys_InitMemory` caps its memory pool at a hard-coded limit that is too small for modern mods. HeapPatch rewrites every heap-limit immediate in `Sys_InitMemory` to **256 MB** by default, through the MetaHook gamedata symbol catalog.

# Install

1. Download and install [MetaHookSv](https://github.com/hzqst/MetaHookSv).

2. Build or download .dll, put it into `/SteamLibrary/steamapps/common/Sven Co-op/svencoop/metahook/plugins` directory.

3. Add `HeapPatch.dll` in `/SteamLibrary/steamapps/common/Sven Co-op/svencoop/metahook/configs/plugins.lst` as a newline.

4. Keep the `svencoop/metahook/gamedata/heappatch` directory shipped next to the plugin: it carries the `Sys_InitMemory_HeapLimitPatches` patch sites the plugin resolves at load time.

5. Enjoy.

# Launch Option

|Option|Value|Comment|
|---|---|---|
|-heaplimit_override|32~1024|heap limit in MB, default 256|

# Build

Requirements: Windows, Visual Studio 2022, CMake 3.21 or newer, Python 3.8 or newer. The first configure downloads VC-LTL 5.3.1 into `thirdparty/cache` and synchronizes the gamedata catalog.

1. Run `scripts\build-HeapPatch-x86-Release.bat` (or `scripts\build-HeapPatch-x86-Debug.bat`).

2. The plugin, its PDB and the gamedata catalog are installed to `install\x86\<Configuration>\svencoop\metahook`.

3. Copy `HeapPatch.dll` and `gamedata\heappatch` into `svencoop/metahook`, as described in Install.

The MetaHook SDK is fetched automatically at a pinned commit. To build against a local MetaHook source tree instead, pass it on the command line or export the same environment variable before configuring:

```
scripts\build-HeapPatch-x86-Release.bat -DMETAHOOK_SOURCE_PATH=D:\MetaHook
```

The path is the repository root that provides `include/metahook.h`, `include/HLSDK`, `include/Interface` and `include/SourceSDK`.

HeapPatch uses the Capstone headers through the MetaHook API and does not link Capstone. Capstone headers resolve from `CAPSTONE_INCLUDE_DIRS` when set, otherwise from the MetaHook tree's `thirdparty/capstone_fork` submodule, otherwise from a pinned commit. Pass `-DHEAPPATCH_SYNC_GAMEDATA=OFF` to build without downloading gamedata.
