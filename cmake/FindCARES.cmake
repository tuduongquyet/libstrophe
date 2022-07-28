# - Find c-ares
# Find the c-ares includes and library
# This module defines
# CARES_INCLUDE_DIR, where to find ares.h, etc.
# CARES_LIBRARIES, the libraries needed to use c-ares.
# CARES_FOUND, If false, do not try to use c-ares.
# also defined, but not for general use are
# CARES_LIBRARY, where to find the c-ares library.

find_path(CARES_INCLUDE_DIR ares.h
  /usr/local/include
  /usr/include
)

set(CARES_NAMES ${CARES_NAMES} cares)
find_library(CARES_LIBRARY
  NAMES ${CARES_NAMES}
  PATHS /usr/lib /usr/local/lib
)

if(CARES_LIBRARY AND CARES_INCLUDE_DIR)
  set(CARES_LIBRARIES ${CARES_LIBRARY})
  set(CARES_FOUND "YES")
else(CARES_LIBRARY AND CARES_INCLUDE_DIR)
  set(CARES_FOUND "NO")
endif(CARES_LIBRARY AND CARES_INCLUDE_DIR)

if(CARES_INCLUDE_DIR)
  set(_version_regex "^#define[ \t]+ARES_VERSION_STR[ \t]+\"([^\"]+)\".*")
  file(STRINGS "${CARES_INCLUDE_DIR}/ares_version.h" CARES_VERSION REGEX "${_version_regex}")
  string(REGEX REPLACE "${_version_regex}" "\\1" CARES_VERSION "${CARES_VERSION}")
  unset(_version_regex)
endif()

if(CARES_FOUND)
  if(NOT CARES_FIND_QUIETLY)
    message(STATUS "Found c-ares: ${CARES_LIBRARIES}")
  endif(NOT CARES_FIND_QUIETLY)
else(CARES_FOUND)
  if(CARES_FIND_REQUIRED)
    message(FATAL_ERROR "Could not find c-ares library")
  endif(CARES_FIND_REQUIRED)
endif(CARES_FOUND)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(CARES
  REQUIRED_VARS CARES_LIBRARY CARES_INCLUDE_DIR
  VERSION_VAR CARES_VERSION)

mark_as_advanced(
  CARES_LIBRARY
  CARES_INCLUDE_DIR
  CARES_VERSION
)
