set(HEAPPATCH_DEPENDENCY_CACHE_DIR "${PROJECT_SOURCE_DIR}/thirdparty/cache" CACHE PATH "Downloaded dependency cache")
set(VC_LTL_Root "${HEAPPATCH_DEPENDENCY_CACHE_DIR}/VC-LTL-5.3.1" CACHE PATH "VC-LTL binary package root")
set(METAHOOK_SOURCE_PATH "$ENV{METAHOOK_SOURCE_PATH}" CACHE PATH "MetaHook source tree; empty fetches the pinned SDK")
set(CAPSTONE_INCLUDE_DIRS "$ENV{CAPSTONE_INCLUDE_DIRS}" CACHE STRING "External Capstone include directories; empty prefers MetaHook's own capstone fork and otherwise fetches the pinned commit")

# The plugin compiles part of the SDK and includes its public headers, so an
# external tree must provide both the sources and the interfaces it uses.
function(heappatch_validate_metahook_source source)
    foreach(required include/metahook.h include/HLSDK/common/interface.cpp
        include/HLSDK/common/cvardef.h include/Interface/IPlugins.h)
        if(NOT EXISTS "${source}/${required}" OR IS_DIRECTORY "${source}/${required}")
            message(FATAL_ERROR "METAHOOK_SOURCE_PATH is missing ${required}: ${source}")
        endif()
    endforeach()
endfunction()

# Download a pinned dependency into the build tree. Only the source is
# populated: the caller keeps its add_subdirectory() call so subprojects are
# configured at the same point and with the same options as an explicit path.
function(heappatch_fetch_source name url tag out_var)
    include(FetchContent)
    FetchContent_Populate(${name}
        GIT_REPOSITORY "${url}"
        GIT_TAG "${tag}"
        GIT_SUBMODULES ""
        SOURCE_DIR "${CMAKE_BINARY_DIR}/_deps/${name}-src")
    string(TOLOWER "${name}" name_lower)
    set(${out_var} "${${name_lower}_SOURCE_DIR}" PARENT_SCOPE)
endfunction()

function(heappatch_prepare_dependencies)
    set(capstone_includes)
    set(capstone_header_found FALSE)
    foreach(directory IN LISTS CAPSTONE_INCLUDE_DIRS)
        get_filename_component(directory "${directory}" ABSOLUTE BASE_DIR "${PROJECT_SOURCE_DIR}")
        if(NOT IS_DIRECTORY "${directory}")
            message(FATAL_ERROR "CAPSTONE_INCLUDE_DIRS directory does not exist: ${directory}")
        endif()
        # Accept either include/ or include/capstone/ from a Capstone source/install tree.
        if(EXISTS "${directory}/capstone.h")
            set(capstone_header_found TRUE)
        elseif(EXISTS "${directory}/capstone/capstone.h")
            string(APPEND directory "/capstone")
            set(capstone_header_found TRUE)
        endif()
        list(APPEND capstone_includes "${directory}")
    endforeach()
    if(CAPSTONE_INCLUDE_DIRS AND NOT capstone_header_found)
        message(FATAL_ERROR "CAPSTONE_INCLUDE_DIRS must provide capstone.h or capstone/capstone.h")
    endif()
    if(DEFINED CAPSTONE_LIBRARY_DIRS)
        message(STATUS "CAPSTONE_LIBRARY_DIRS is ignored: HeapPatch uses Capstone headers through the MetaHook API and does not link Capstone.")
    endif()

    # External trees are read-only inputs; validate explicit paths before downloading anything.
    if(METAHOOK_SOURCE_PATH)
        get_filename_component(metahook_source "${METAHOOK_SOURCE_PATH}" ABSOLUTE BASE_DIR "${PROJECT_SOURCE_DIR}")
    else()
        include(FetchContent)
        FetchContent_Declare(heappatch_metahook
            GIT_REPOSITORY https://github.com/MetaHookSv/MetaHook
            GIT_TAG 4d23b6fecd79dc949aabc2e145480cd1328d4a35
            GIT_SUBMODULES ""
            # This SDK directory has no CMakeLists.txt: populate without building the launcher.
            SOURCE_SUBDIR include
        )
        FetchContent_MakeAvailable(heappatch_metahook)
        set(metahook_source "${heappatch_metahook_SOURCE_DIR}")
    endif()
    heappatch_validate_metahook_source("${metahook_source}")
    set(METAHOOK_SOURCE_PATH "${metahook_source}" PARENT_SCOPE)
    message(STATUS "METAHOOK_SOURCE_PATH: ${metahook_source}")

    if(NOT CAPSTONE_INCLUDE_DIRS)
        # Prefer the host's own Capstone checkout: these headers describe types
        # crossing the MetaHook API boundary and must match the instance the host
        # loads at runtime. A host fetched without submodules leaves
        # thirdparty/capstone_fork empty, so fall back to the pinned commit.
        set(host_capstone "${metahook_source}/thirdparty/capstone_fork/include/capstone")
        if(EXISTS "${host_capstone}/capstone.h")
            set(capstone_includes "${host_capstone}")
        else()
            heappatch_fetch_source(heappatch_capstone
                "https://github.com/hzqst/capstone"
                "e81e390f621ee59d14f70e16fe065dd00f78ee71" capstone_source)
            set(capstone_includes "${capstone_source}/include/capstone")
        endif()
    endif()
    set(HEAPPATCH_CAPSTONE_INCLUDE_DIRS "${capstone_includes}" PARENT_SCOPE)
    message(STATUS "Capstone headers: ${capstone_includes}")

    include("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/VCLTL.cmake")
    heappatch_prepare_vcltl()
endfunction()
