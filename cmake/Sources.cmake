# Explicit compile list from HeapPatch.vcxproj. interface.cpp is provided by the
# MetaHook SDK because EXPOSE_SINGLE_INTERFACE, which exports CreateInterface, lives there.
set(HEAPPATCH_SOURCES
    "${PROJECT_SOURCE_DIR}/src/exportfuncs.cpp"
    "${PROJECT_SOURCE_DIR}/src/plugins.cpp"
    "${PROJECT_SOURCE_DIR}/src/privatehook.cpp"
    "${METAHOOK_SOURCE_PATH}/include/HLSDK/common/interface.cpp"
)
