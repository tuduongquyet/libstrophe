# - Find c-ares
# Find the c-ares includes and library
# This module defines
#  CARES_INCLUDE_DIR, where to find ares.h, etc.
#  CARES_LIBRARIES, the libraries needed to use c-ares.
#  CARES_FOUND, If false, do not try to use c-ares.
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
else()
  set(CARES_FOUND "NO")
endif()


if(CARES_FOUND)
  if(NOT CARES_FIND_QUIETLY)
    message(STATUS "Found c-ares: ${CARES_LIBRARIES}")
  endif()
else()
  if(CARES_FIND_REQUIRED)
    message(FATAL_ERROR "Could not find c-ares library")
  endif()
endif()

mark_as_advanced(
  CARES_LIBRARY
  CARES_INCLUDE_DIR
  )

## Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
## file Copyright.txt or https://cmake.org/licensing for details.
#
##[=======================================================================[.rst:
#FindCARES
#-----------
#
#Find the XML processing library (libcares).
#
#IMPORTED Targets
#^^^^^^^^^^^^^^^^
#
#The following :prop_tgt:`IMPORTED` targets may be defined:
#
#``c-ares::cares``
#  If the libcares library has been found
#``c-ares::xmllint``
#  If the xmllint command-line executable has been found
#
#Result variables
#^^^^^^^^^^^^^^^^
#
#This module will set the following variables in your project:
#
#``c-ares_FOUND``
#  true if libcares headers and libraries were found
#``CARES_INCLUDE_DIR``
#  the directory containing c-ares headers
#``CARES_INCLUDE_DIRS``
#  list of the include directories needed to use c-ares
#``CARES_LIBRARIES``
#  c-ares libraries to be linked
#``CARES_DEFINITIONS``
#  the compiler switches required for using c-ares
#``CARES_XMLLINT_EXECUTABLE``
#  path to the XML checking tool xmllint coming with c-ares
#``CARES_VERSION_STRING``
#  the version of c-ares found (since CMake 2.8.8)
#
#Cache variables
#^^^^^^^^^^^^^^^
#
#The following cache variables may also be set:
#
#``CARES_INCLUDE_DIR``
#  the directory containing c-ares headers
#``CARES_LIBRARY``
#  path to the c-ares library
##]=======================================================================]
#
## use pkg-config to get the directories and then use these values
## in the find_path() and find_library() calls
#find_package(PkgConfig QUIET)
#PKG_CHECK_MODULES(PC_CARES QUIET libcares)
#
#find_path(CARES_INCLUDE_DIR NAMES ares.h
#        HINTS
#        ${PC_CARES_INCLUDEDIR}
#        ${PC_CARES_INCLUDE_DIRS}
#        )
#message("PC_CARES_INCLUDE_DIRS: ${PC_CARES_INCLUDE_DIRS}")
#message("PC_CARES_LIBRARY_DIRS: ${PC_CARES_LIBRARY_DIRS}")
#message("")
## CMake 3.9 and below used 'CARES_LIBRARIES' as the name of
## the cache entry storing the find_library result.  Use the
## value if it was set by the project or user.
#if(DEFINED CARES_LIBRARIES AND NOT DEFINED CARES_LIBRARY)
#  set(CARES_LIBRARY ${CARES_LIBRARIES})
#endif()
#
#find_library(CARES_LIBRARY NAMES cares libcares
#        HINTS
#        ${PC_CARES_LIBDIR}
#        ${PC_CARES_LIBRARY_DIRS}
#        )
#
#set(CARES_INCLUDE_DIRS ${CARES_INCLUDE_DIR})
#set(CARES_LIBRARIES ${CARES_LIBRARY})
#
## Did we find the same installation as pkg-config?
## If so, use additional information from it.
#unset(CARES_DEFINITIONS)
#foreach(libcares_pc_lib_dir IN LISTS PC_CARES_LIBDIR PC_CARES_LIBRARY_DIRS)
#  if (CARES_LIBRARY MATCHES "^${libcares_pc_lib_dir}")
#    list(APPEND CARES_INCLUDE_DIRS ${PC_CARES_INCLUDE_DIRS})
#    set(CARES_DEFINITIONS ${PC_CARES_CFLAGS_OTHER})
#    break()
#  endif()
#endforeach()
#
#include(FindPackageHandleStandardArgs)
#FIND_PACKAGE_HANDLE_STANDARD_ARGS(cares
#        REQUIRED_VARS CARES_LIBRARY CARES_INCLUDE_DIR
#        VERSION_VAR CARES_VERSION)
#message("CARES_VERSION: ${CARES_VERSION}")
#
#mark_as_advanced(CARES_INCLUDE_DIR CARES_LIBRARY CARES_XMLLINT_EXECUTABLE)
#
#if(CARES_FOUND AND NOT TARGET c-ares::cares)
#  add_library(c-ares::cares UNKNOWN IMPORTED)
#  set_target_properties(c-ares::cares PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${CARES_INCLUDE_DIRS}")
#  set_target_properties(c-ares::cares PROPERTIES INTERFACE_COMPILE_OPTIONS "${CARES_DEFINITIONS}")
#  set_property(TARGET c-ares::cares APPEND PROPERTY IMPORTED_LOCATION "${CARES_LIBRARY}")
#endif()
#
#if(CARES_XMLLINT_EXECUTABLE AND NOT TARGET c-ares::xmllint)
#  add_executable(c-ares::xmllint IMPORTED)
#  set_target_properties(c-ares::xmllint PROPERTIES IMPORTED_LOCATION "${CARES_XMLLINT_EXECUTABLE}")
#endif()