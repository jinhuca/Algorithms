cmake_minimum_required(VERSION 3.21)

# Foundation core — header-only generic C++20 algorithms. Skeleton for now: one placeholder
# module (core/modules/foundation/placeholder.ixx), the single source of truth, with its
# header-only twin (core/include/fo/placeholder.hpp). The unified generator
# (scripts/gen_hpp.py, see the monorepo README) regenerates the twin from the .ixx.
add_library(fo_core INTERFACE)
add_library(fo::core ALIAS fo_core)
target_include_directories(fo_core INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_compile_features(fo_core INTERFACE cxx_std_20)

# Guard against .ixx/.hpp drift: fail the build if any header twin is stale, via the
# unified monorepo generator (../../scripts/gen_hpp.py). Skipped (with a notice) when no
# working Python3 is available. Mirrors the sa / se / ga cores.
find_package(Python3 COMPONENTS Interpreter QUIET)
set(_fo_python_ok FALSE)
if (Python3_FOUND)
    execute_process(COMMAND "${Python3_EXECUTABLE}" -I -c "pass"
        RESULT_VARIABLE _fo_py_rc OUTPUT_QUIET ERROR_QUIET)
    if (_fo_py_rc EQUAL 0)
        set(_fo_python_ok TRUE)
    endif()
endif()
if (_fo_python_ok)
    add_custom_target(fo_header_sync_check ALL
        COMMAND ${Python3_EXECUTABLE} -I
                "${CMAKE_CURRENT_SOURCE_DIR}/../../scripts/gen_hpp.py"
                --project "${CMAKE_CURRENT_SOURCE_DIR}/.." --ns fo --check
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/.."
        COMMENT "Checking foundation_algo/core/include/fo/*.hpp are in sync with their .ixx"
        VERBATIM)
else()
    message(STATUS "No working Python3 interpreter; skipping the fo .hpp<->.ixx sync check")
endif()
