cmake_minimum_required(VERSION 2.8.12)

set(STROPHE_VERSION "0.10.0")

if(CMAKE_VERSION VERSION_LESS "3.0")
    project(libstrophe C)
    set(PROJECT_VERSION ${STROPHE_VERSION})
else()
    cmake_policy(SET CMP0042 NEW)
    cmake_policy(SET CMP0048 NEW)
    project(libstrophe VERSION ${STROPHE_VERSION} LANGUAGES C)
endif()

set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake ${CMAKE_MODULE_PATH})
set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_MODULE_PATH})
set(CMAKE_PREFIX_PATH ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_PREFIX_PATH})

include(CheckCSourceCompiles)
include(CheckFunctionExists)
include(CheckLibraryExists)
include(CheckSymbolExists)
include(CheckIncludeFiles)
include(GNUInstallDirs)

set(STROPHE_REQUIRED_LIBRARIES "")
set(STROPHE_PC_REQUIRES "")
set(STROPHE_WARNING_FLAGS "")

if(NOT ANDROID)
    # Android does not need these settings because they are already set by toolchain file
    # PIE/PIC
    if(CMAKE_VERSION VERSION_GREATER 2.8.8)
        set(CMAKE_POSITION_INDEPENDENT_CODE TRUE)
        set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fPIE -pie")
    else()
        set(CMAKE_POSITION_INDEPENDENT_CODE FALSE)
        set(CMAKE_CXX_FLAGS "-fPIC ${CMAKE_CXX_FLAGS}")
        set(CMAKE_C_FLAGS "-fPIC ${CMAKE_C_FLAGS}")
    endif()
endif()

set(STROPHE_WARNING_FLAGS "-Wall")

if(CMAKE_SYSTEM_NAME MATCHES "Haiku")
    set(STROPHE_WARNING_FLAGS "$STROPHE_WARNING_FLAGS -Wextra -Wno-unused-parameter")
endif(CMAKE_SYSTEM_NAME MATCHES "Haiku")

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${STROPHE_WARNING_FLAGS}")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${STROPHE_WARNING_FLAGS}")

# ########## BUILD OPTIONS ##############################################################################################
# #######################################################################################################################
option(ENABLE_CARES "Enable c-ares for AsyncDNS" ON)
option(ENABLE_TLS "Enable TLS" ON)
option(USE_OPENSSL "Use OpenSSL for SSL option" ON)
option(USE_GNUTLS "Use GNUTLS for SSL option" OFF)
option(USE_SCHANNEL "Use OpenSSL for SSL option" OFF)
option(USE_LIBXML2 "Use LibXml2 as XML parser" OFF)
option(USE_EXPAT "Use LibExpat as XML parser" ON)
option(ENABLE_GETRANDOM "Enable usage of the getrandom() system call" OFF)
option(BUILD_SAMPLES "Option to test build" ON)
option(BUILD_TESTS "Option to test build" ON)
set(STROPHE__LIBRARY_TYPE "BOTH" CACHE STRING
    "Set library type to SHARED/STATIC/BOTH (default SHARED for MSVC, otherwise BOTH)")

if("${STROPHE__LIBRARY_TYPE}" STREQUAL "DEFAULT")
    if(${MSVC})
        set(STROPHE_LIBRARY_TYPE SHARED)
    else()
        set(STROPHE_LIBRARY_TYPE BOTH)
    endif()
else()
    string(TOUPPER "${STROPHE__LIBRARY_TYPE}" STROPHE_LIBRARY_TYPE)
endif()

if((${MSVC}) AND(${STROPHE_LIBRARY_TYPE} STREQUAL "BOTH"))
    message(WARNING
        "Building SHARED and STATIC is not supported for MSVC (due to conflicts in library name between STATIC library and IMPORTED library for SHARED libraries)")
endif()

set(STROPHE_LIBRARY_STATIC OFF)
set(STROPHE_LIBRARY_SHARED OFF)
message(STATUS "libstrophe build type (shared/static): ${STROPHE_LIBRARY_TYPE}")

if("${STROPHE_LIBRARY_TYPE}" STREQUAL "BOTH")
    set(STROPHE_LIBRARY_STATIC ON)
    set(STROPHE_LIBRARY_SHARED ON)
elseif("${STROPHE_LIBRARY_TYPE}" STREQUAL "STATIC")
    set(STROPHE_LIBRARY_STATIC ON)
elseif("${STROPHE_LIBRARY_TYPE}" STREQUAL "SHARED")
    set(STROPHE_LIBRARY_SHARED ON)
else()
    message(FATAL_ERROR "${STROPHE_LIBRARY_TYPE} is not supported")
endif()

if(CMAKE_SYSTEM_NAME MATCHES "Android")
    set(USE_LIBXML2 OFF)
    set(USE_EXPAT ON)
endif()

set(CMAKE_MACOSX_RPATH 1)

# ########## DEPENDENCIES ###############################################################################################
# #######################################################################################################################

# ########## XML PARSER #################################################################################################
if(USE_LIBXML2)
    if(WIN32)
        find_package(LibXml2Win REQUIRED)
    else()
        find_package(LibXml2 REQUIRED)
    endif(WIN32)

    if(LIBXML2_FOUND)
        set(CMAKE_REQUIRED_INCLUDES ${LIBXML2_INCLUDE_DIR} ${CMAKE_REQUIRED_INCLUDES})
        set(STROPHE_REQUIRED_LIBRARIES ${LIBXML2_LIBRARIES} ${STROPHE_REQUIRED_LIBRARIES})
        set(STROPHE_PC_REQUIRES libmxl2 ${STROPHE_PC_REQUIRES})
        set(STROPHE_PC_LIBS -lxml2 ${STROPHE_PC_LIBS})
    endif(LIBXML2_FOUND)

    message("Using ${LIBXML2_INCLUDE_DIR} ${LIBXML2_LIBRARIES}")
elseif(USE_EXPAT)
    find_package(EXPAT REQUIRED)

    if(EXPAT_FOUND)
        set(CMAKE_REQUIRED_INCLUDES ${EXPAT_INCLUDE_DIRS} ${CMAKE_REQUIRED_INCLUDES})
        set(STROPHE_REQUIRED_LIBRARIES ${EXPAT_LIBRARIES} ${STROPHE_REQUIRED_LIBRARIES})
        set(STROPHE_PC_REQUIRES expat ${STROPHE_PC_REQUIRES})
        set(STROPHE_PC_LIBS -lexpat ${STROPHE_PC_LIBS})
    endif(EXPAT_FOUND)

    message("Using ${EXPAT_INCLUDE_DIRS} ${EXPAT_LIBRARIES}")
endif()

# ########## OPENSSL ####################################################################################################
if(USE_OPENSSL)
    find_package(OpenSSL REQUIRED)

    # Depend on OpenSSL via imported targets if supported by the running
    # version of CMake.  This allows our dependents to get our dependencies
    # transitively.
    if(NOT CMAKE_VERSION VERSION_LESS 3.4)
        set(STROPHE_REQUIRED_LIBRARIES OpenSSL::SSL OpenSSL::Crypto ${STROPHE_REQUIRED_LIBRARIES})
    else()
        set(STROPHE_REQUIRED_LIBRARIES ${OPENSSL_LIBRARIES} ${STROPHE_REQUIRED_LIBRARIES})
    endif()

    set(CMAKE_REQUIRED_INCLUDES ${OPENSSL_INCLUDE_DIR} ${CMAKE_REQUIRED_INCLUDES})
    set(STROPHE_PC_REQUIRES openssl ${STROPHE_PC_REQUIRES})
    set(STROPHE_PC_LIBS -lssl -lcrypto ${STROPHE_PC_LIBS})
endif()

# ########## C-ARES #####################################################################################################
if(ENABLE_CARES)
    find_package(CARES REQUIRED)

    if(CARES_FOUND)
        set(CMAKE_REQUIRED_INCLUDES ${CARES_INCLUDE_DIR} ${CMAKE_REQUIRED_INCLUDES})
        set(STROPHE_REQUIRED_LIBRARIES ${CARES_LIBRARY} ${STROPHE_REQUIRED_LIBRARIES})
        set(STROPHE_PC_REQUIRES libcares ${STROPHE_PC_REQUIRES})
        set(STROPHE_PC_LIBS -lcares ${STROPHE_PC_LIBS})
        add_definitions(-DHAVE_CARES)
    endif(CARES_FOUND)
endif()

# ########## RESOLVER ###################################################################################################
if(CMAKE_SYSTEM_NAME MATCHES "FreeBSD|OpenBSD|NetBSD|Android")
    set(RESOLV_LIBS, "")
elseif(CMAKE_SYSTEM_NAME MATCHES "NTO|QNX")
    find_library(SOCKET_LIBRARY "socket")

    if(SOCKET_LIBRARY)
        list(APPEND RESOLV_LIBS ${SOCKET_LIBRARY})
        set(STROPHE_PC_LIBS -lsocket ${STROPHE_PC_LIBS})
    endif()
elseif(CMAKE_SYSTEM_NAME MATCHES "SunOS")
    find_library(RESOLV_LIBRARY NAMES resolv)

    if(RESOLV_LIBRARY)
        set(RESOLV_LIBS ${RESOLV_LIBS} ${RESOLV_LIBRARY})
        set(STROPHE_PC_LIBS -lresolv ${STROPHE_PC_LIBS})
    endif()

    find_library(SOCKET_LIBRARY "socket")

    if(SOCKET_LIBRARY)
        list(APPEND RESOLV_LIBS ${SOCKET_LIBRARY})
        set(STROPHE_PC_LIBS -lsocket ${STROPHE_PC_LIBS})
    endif()

    find_library(NSL_LIBRARY "nsl")

    if(NSL_LIBRARY)
        list(APPEND RESOLV_LIBS ${NSL_LIBRARY})
        set(STROPHE_PC_LIBS -lnsl ${STROPHE_PC_LIBS})
    endif()
elseif(CMAKE_SYSTEM_NAME MATCHES "Haiku")
    find_library(NETWORK_LIBRARY NAMES network)

    if(NETWORK_LIBRARY)
        list(APPEND RESOLV_LIBS ${NETWORK_LIBRARY})
        set(STROPHE_PC_LIBS -lnetwork ${STROPHE_PC_LIBS})
    endif()
else()
    find_library(RESOLV_LIBRARY NAMES resolv)

    if(RESOLV_LIBRARY)
        set(RESOLV_LIBS ${RESOLV_LIBS} ${RESOLV_LIBRARY})
        set(STROPHE_PC_LIBS -lresolv ${STROPHE_PC_LIBS})
    endif()
endif()

if(RESOLV_LIBS)
    check_library_exists(${RESOLV_LIBS} res_send "" RES_SEND_IN_LIBRESOLV)
    check_library_exists(${RESOLV_LIBS} __res_send "" __RES_SEND_IN_LIBRESOLV)

    if(RES_SEND_IN_LIBRESOLV OR __RES_SEND_IN_LIBRESOLV)
        set(HAVE_LIBRESOLV TRUE)
    endif()
endif()

check_function_exists(res_init HAVE_RES_INIT)
check_function_exists(__res_init HAVE___RES_INIT)

check_function_exists(res_ninit HAVE_RES_NINIT)
check_function_exists(__res_ninit HAVE___RES_NINIT)

if(RESOLV_LIBS)
    check_library_exists(${RESOLV_LIBS} res_ninit "" HAVE_RES_NINIT_IN_LIBRESOLV)
endif()

check_function_exists(res_close HAVE_RES_CLOSE)
check_function_exists(__res_close HAVE___RES_CLOSE)

check_function_exists(res_nclose HAVE_RES_NCLOSE)
check_function_exists(__res_nclose HAVE___RES_NCLOSE)

if(RESOLV_LIBS)
    check_library_exists(${RESOLV_LIBS} res_nclose "" HAVE_RES_NCLOSE_IN_LIBRESOLV)
endif()

check_function_exists(res_query HAVE_RES_QUERY)
check_function_exists(__res_query HAVE___RES_QUERY)

check_function_exists(res_nquery HAVE_RES_NQUERY)
check_function_exists(__res_nquery HAVE___RES_NQUERY)

# check_function_exists(res_search HAVE_RES_SEARCH)
# check_function_exists(__res_search HAVE___RES_SEARCH)
#
# check_function_exists(res_nsearch HAVE_RES_NSEARCH)
# check_function_exists(__res_nsearch HAVE___RES_NSEARCH)

# check_symbol_exists("getrandom" "sys/random.h" HAVE_GETRANDOM)
check_function_exists(getrandom HAVE_GETRANDOM)

macro(evaluate_detection_results use_ref have_ref thing_lower thing_title)
    if(${use_ref} AND NOT(${use_ref} STREQUAL "AUTO") AND NOT ${have_ref})
        message(SEND_ERROR
            "Use of ${thing_lower} was enforced by ${use_ref}=ON but it could not be found.")
    elseif(NOT ${use_ref} AND ${have_ref})
        message("${thing_title} was found but it will not be used due to ${use_ref}=OFF.")
        set(${have_ref} 0)
    endif()
endmacro()

if(NOT WIN32)
    evaluate_detection_results(ENABLE_GETRANDOM HAVE_GETRANDOM "function getrandom" "Function getrandom")
    evaluate_detection_results(ENABLE_GETRANDOM HAVE_SYSCALL_GETRANDOM "syscall SYS_getrandom" "Syscall SYS_getrandom")
endif()

if(WIN32)
    check_function_exists(_vsnprintf_s HAVE__VSNPRINTF_S)
    check_function_exists(_vsnprintf HAVE__VSNPRINTF)
    check_function_exists(_snprintf HAVE__SNPRINTF)
    check_function_exists(_snprintf_s HAVE__SNPRINTF_S)
    check_symbol_exists(snprintf stdio.h HAVE_SNPRINTF)
    check_symbol_exists(vsnprintf stdio.h HAVE_VSNPRINTF)
else(WIN32)
    check_function_exists(sprintf HAVE_SNPRINTF)
    check_function_exists(vsnprintf HAVE_VSNPRINTF)
endif(WIN32)

if(HAVE_VSNPRINTF)
    add_definitions(-DHAVE_SNPRINTF)
endif()

if(HAVE_VSNPRINTF)
    add_definitions(-DHAVE_VSNPRINTF)
endif()

check_include_files(stdarg.h HAVE_STDARG_H)
check_function_exists(va_copy HAVE_VA_COPY)
check_function_exists(__va_copy HAVE___VA_COPY)

if(HAVE_VA_COPY)
    add_definitions(-DHAVE_VA_COPY)
endif()

if(HAVE___VA_COPY)
    add_definitions(-DHAVE___VA_COPY)
endif()

check_c_source_compiles("
    #include <stdarg.h>
    void a(va_list* ap) {};
    int main() { va_list ap1, ap2; a(&ap1); ap2 = (va_list) ap1; return 0; }
    " VA_LIST_IS_ARRAY_TEST)

if(VA_LIST_IS_ARRAY_TEST)
    set(VA_LIST_IS_ARRAY FALSE)
else()
    set(VA_LIST_IS_ARRAY TRUE)
    add_definitions(-DVA_LIST_IS_ARRAY)
endif()

set(STROPHE_REQUIRED_LIBRARIES ${RESOLV_LIBS} ${STROPHE_REQUIRED_LIBRARIES})
include_directories(${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_REQUIRED_INCLUDES})

# ########## STROPHE #################################################################################################
# #######################################################################################################################
set(STROPHE_PC ${CMAKE_CURRENT_BINARY_DIR}/libstrophe.pc)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/libstrophe.pc.cmakein
    ${STROPHE_PC} @ONLY)

set(STROPHE_SRCS
    src/auth.c
    src/conn.c
    src/crypto.c
    src/ctx.c
    src/deprecated.c
    src/event.c
    src/handler.c
    src/hash.c
    src/jid.c
    src/md5.c
    src/rand.c
    src/resolver.c
    src/sasl.c
    src/scram.c
    src/sha1.c
    src/sha256.c
    src/sha512.c
    src/sock.c
    src/stanza.c
    src/tls.c
    src/util.c
    src/uuid.c
)

if(NOT HAVE_SNPRINTF OR NOT HAVE_VSNPRINTF)
    set(STROPHE_SRCS ${STROPHE_SRCS} src/snprintf.c)
endif()

if(ENABLE_TLS)
    if(USE_GNUTLS)
        set(STROPHE_SRCS ${STROPHE_SRCS} src/tls_gnutls.c)
    elseif(USE_SCHANNEL)
        set(STROPHE_SRCS ${STROPHE_SRCS} src/tls_schannel.c)
    else()
        set(STROPHE_SRCS ${STROPHE_SRCS} src/tls_openssl.c)
    endif()
else()
    set(STROPHE_SRCS ${STROPHE_SRCS} src/tls_dummy.c)
endif()

if(USE_LIBXML2)
    set(STROPHE_SRCS ${STROPHE_SRCS} src/parser_libxml2.c)
else()
    set(STROPHE_SRCS ${STROPHE_SRCS} src/parser_expat.c)
endif()

if(STROPHE_LIBRARY_SHARED)
    add_library(strophe-shared SHARED ${STROPHE_SRCS})
endif()

if(STROPHE_LIBRARY_STATIC)
    add_library(strophe-static STATIC ${STROPHE_SRCS})
endif()

if(STROPHE_LIBRARY_SHARED AND CMAKE_SYSTEM_NAME MATCHES "Linux" AND NOT LINUX_IS_TIZEN)
    set_target_properties(strophe-shared PROPERTIES VERSION ${STROPHE_VERSION} SOVERSION 0)
endif()

if(NOT CYGWIN)
    # This property causes shared libraries on Linux to have the full version
    # encoded into their final filename.  We disable this on Cygwin because
    # it causes cygz-${libstrophe_FULL_VERSION}.dll to be created when cygz.dll
    # seems to be the default.
    #
    # This has no effect with MSVC, on that platform the version info for
    # the DLL comes from the resource file win32/libstrophe3.rc
    if(STROPHE_LIBRARY_SHARED AND CMAKE_SYSTEM_NAME MATCHES "Linux" AND NOT LINUX_IS_TIZEN)
        set_target_properties(strophe-shared PROPERTIES VERSION ${STROPHE_VERSION})
    endif()
endif()

if(UNIX)
    # On unix-like platforms the library is almost always called libstrophe
    if(STROPHE_LIBRARY_SHARED)
        set_target_properties(strophe-shared PROPERTIES OUTPUT_NAME strophe)
    endif()

    if(STROPHE_LIBRARY_STATIC)
        set_target_properties(strophe-static PROPERTIES OUTPUT_NAME strophe)
    endif()
elseif(BUILD_SHARED_LIBS AND WIN32)
    # Creates strophe0.dll when building shared library version
    if(STROPHE_LIBRARY_SHARED)
        set_target_properties(strophe-shared PROPERTIES SUFFIX "0.dll")
    endif()
endif()

if(STROPHE_LIBRARY_SHARED)
    target_link_libraries(strophe-shared ${STROPHE_REQUIRED_LIBRARIES})
endif()

if(STROPHE_LIBRARY_STATIC)
    target_link_libraries(strophe-static ${STROPHE_REQUIRED_LIBRARIES})
endif()

if(STROPHE_LIBRARY_STATIC)
    install(TARGETS strophe-static
        RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
        ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
        LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}")
endif()

if(STROPHE_LIBRARY_SHARED)
    install(TARGETS strophe-shared
        RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
        ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
        LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}")
endif()

install(FILES strophe.h DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")

if(NOT SKIP_INSTALL_FILES AND NOT SKIP_INSTALL_ALL)
    install(FILES ${STROPHE_PC} DESTINATION "${CMAKE_INSTALL_LIBDIR}/pkgconfig")
endif()

# Indentify which target to use to link with tests and samples
if(STROPHE_LIBRARY_STATIC)
    set(STROPHE_LIBRARY_TARGET strophe-static)
else()
    set(STROPHE_LIBRARY_TARGET strophe-shared)
endif()

# ########## SAMPLES ####################################################################################################
if(BUILD_SAMPLES)
    set(examples
        active
        basic
        bot
        complex
        component
        perf
        register
        roster
        uuid
        vcard
    )

    foreach(exe ${examples})
        add_executable(${exe} examples/${exe}.c)
        target_link_libraries(${exe} PRIVATE ${STROPHE_LIBRARY_TARGET} ${STROPHE_REQUIRED_LIBRARIES})
        set_property(TARGET ${exe} PROPERTY FOLDER examples)
    endforeach()
endif()

# ########## TESTS ######################################################################################################
if(BUILD_TESTS)
    enable_testing()

    add_executable(check_parser tests/check_parser.c)
    target_link_libraries(check_parser ${STROPHE_LIBRARY_TARGET} ${STROPHE_REQUIRED_LIBRARIES})
    include_directories(src/)
    add_test(check_parser check_parser)

    add_executable(test_ctx tests/test_ctx.c)
    target_link_libraries(test_ctx ${STROPHE_LIBRARY_TARGET} ${STROPHE_REQUIRED_LIBRARIES})
    add_test(test_ctx test_ctx)

    add_executable(test_base64 tests/test_base64.c tests/test.c)
    target_link_libraries(test_base64 ${STROPHE_LIBRARY_TARGET} ${STROPHE_REQUIRED_LIBRARIES})
    add_test(test_base64 test_base64)

    add_executable(test_hash tests/test_hash.c)
    target_link_libraries(test_hash ${STROPHE_LIBRARY_TARGET} ${STROPHE_REQUIRED_LIBRARIES})
    add_test(test_hash test_hash)

    add_executable(test_jid tests/test_jid.c)
    target_link_libraries(test_jid ${STROPHE_LIBRARY_TARGET} ${STROPHE_REQUIRED_LIBRARIES})
    add_test(test_jid test_jid)

    add_executable(test_resolver tests/test_resolver.c)
    target_link_libraries(test_resolver ${STROPHE_LIBRARY_TARGET} ${STROPHE_REQUIRED_LIBRARIES})
    add_test(test_resolver test_resolver)

    add_executable(test_rand tests/test_rand.c tests/test.c src/sha1.c)
    target_link_libraries(test_rand ${STROPHE_LIBRARY_TARGET} ${STROPHE_REQUIRED_LIBRARIES})
    add_test(test_rand test_rand)

    add_executable(test_scram tests/test_scram.c tests/test.c src/sha1.c)
    target_link_libraries(test_scram ${STROPHE_LIBRARY_TARGET} ${STROPHE_REQUIRED_LIBRARIES})
    add_test(test_scram test_scram)

    add_executable(test_sha1 tests/test_sha1.c src/sha1.c)
    target_link_libraries(test_sha1 ${STROPHE_LIBRARY_TARGET} ${STROPHE_REQUIRED_LIBRARIES})
    add_test(test_sha1 test_sha1)

    add_executable(test_sha256 tests/test_sha256.c tests/test.c src/sha256.c)
    target_link_libraries(test_sha256 ${STROPHE_LIBRARY_TARGET} ${STROPHE_REQUIRED_LIBRARIES})
    add_test(test_sha256 test_sha256)

    add_executable(test_sha512 tests/test_sha512.c tests/test.c src/sha512.c)
    target_link_libraries(test_sha512 ${STROPHE_LIBRARY_TARGET} ${STROPHE_REQUIRED_LIBRARIES})
    add_test(test_sha512 test_sha512)

    add_executable(test_md5 tests/test_md5.c tests/test.c src/md5.c)
    target_link_libraries(test_md5 ${STROPHE_LIBRARY_TARGET} ${STROPHE_REQUIRED_LIBRARIES})
    add_test(test_md5 test_md5)

    add_executable(test_snprintf tests/test_snprintf.c)
    target_link_libraries(test_snprintf ${STROPHE_LIBRARY_TARGET} ${STROPHE_REQUIRED_LIBRARIES})
    add_test(test_snprintf test_snprintf)

    add_executable(test_string tests/test_string.c)
    target_link_libraries(test_string ${STROPHE_LIBRARY_TARGET} ${STROPHE_REQUIRED_LIBRARIES})
    add_test(test_string test_string)

    add_executable(test_stanza tests/test_stanza.c)
    target_link_libraries(test_stanza ${STROPHE_LIBRARY_TARGET} ${STROPHE_REQUIRED_LIBRARIES})
    add_test(test_stanza test_string)
endif(BUILD_TESTS)

# ########## BUILD CONFIGURATION SUMMARY ################################################################################
message(STATUS "")
message(STATUS "        ---( libstrophe " ${STROPHE_VERSION} " )---")
message(STATUS "")
message(STATUS "CMAKE_INSTALL_PREFIX:     ${CMAKE_INSTALL_PREFIX}")
message(STATUS "CMAKE_BINARY_DIR:         ${CMAKE_BINARY_DIR}")
message(STATUS "CMAKE_CURRENT_BINARY_DIR: ${CMAKE_CURRENT_BINARY_DIR}")
message(STATUS "CMAKE_SOURCE_DIR:         ${CMAKE_SOURCE_DIR}")
message(STATUS "CMAKE_CURRENT_SOURCE_DIR: ${CMAKE_CURRENT_SOURCE_DIR}")
message(STATUS "PROJECT_BINARY_DIR:       ${PROJECT_BINARY_DIR}")
message(STATUS "PROJECT_SOURCE_DIR:       ${PROJECT_SOURCE_DIR}")
message(STATUS "CMAKE_MODULE_PATH:        ${CMAKE_MODULE_PATH}")
message(STATUS "CMAKE_COMMAND:            ${CMAKE_COMMAND}")
message(STATUS "CMAKE_ROOT:               ${CMAKE_ROOT}")
message(STATUS "CMAKE_SYSTEM:             ${CMAKE_SYSTEM}")
message(STATUS "CMAKE_SYSTEM_NAME:        ${CMAKE_SYSTEM_NAME}")
message(STATUS "CMAKE_SYSTEM_VERSION:     ${CMAKE_SYSTEM_VERSION}")
message(STATUS "CMAKE_SYSTEM_PROCESSOR:   ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "CMAKE_SKIP_RPATH:         ${CMAKE_SKIP_RPATH}")
message(STATUS "CMAKE_VERBOSE_MAKEFILE:   ${CMAKE_VERBOSE_MAKEFILE}")
message(STATUS "CMAKE_BUILD_TYPE:         ${CMAKE_BUILD_TYPE}")
message(STATUS "CMAKE_C_COMPILER:         ${CMAKE_C_COMPILER} (id ${CMAKE_C_COMPILER_ID}, clang ${CLANG}, GNUC ${GNUC})")

if(CMAKE_COMPILER_IS_GNUCXX)
    message(STATUS "CMAKE_CXX_COMPILER:         ${CMAKE_CXX_COMPILER} (ver ${CMAKE_CXX_COMPILER_VERSION})")
else()
    message(STATUS "CMAKE_CXX_COMPILER:         ${CMAKE_CXX_COMPILER}")
endif()

message(STATUS "CMAKE_AR:                 ${CMAKE_AR}")
message(STATUS "CMAKE_RANLIB:             ${CMAKE_RANLIB}")
message(STATUS "CMAKE_CXX_FLAGS:          ${CMAKE_CXX_FLAGS}")
message(STATUS "C++ flags (Release):      ${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_RELEASE}")
message(STATUS "C++ flags (Debug):        ${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_DEBUG}")
message(STATUS "CMAKE_C_FLAGS:            ${CMAKE_C_FLAGS}")
message(STATUS "C flags (Release):        ${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_RELEASE}")
message(STATUS "C flags (Debug):          ${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_DEBUG}")

if(WIN32)
    message(STATUS "Linker flags (Release):  ${CMAKE_EXE_LINKER_FLAGS} ${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
    message(STATUS "Linker flags (Debug):    ${CMAKE_EXE_LINKER_FLAGS} ${CMAKE_EXE_LINKER_FLAGS_DEBUG}")
else()
    message(STATUS "Linker flags (Release):  ${CMAKE_SHARED_LINKER_FLAGS} ${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
    message(STATUS "Linker flags (Debug):    ${CMAKE_SHARED_LINKER_FLAGS} ${CMAKE_SHARED_LINKER_FLAGS_DEBUG}")
endif()

message(STATUS "STROPHE_REQUIRED_LIBRARIES:    ${STROPHE_REQUIRED_LIBRARIES}")
message(STATUS "")
