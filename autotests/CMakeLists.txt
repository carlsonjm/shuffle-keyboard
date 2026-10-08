# SPDX-FileCopyrightText: 2026 Aleix Pol <aleixpol@kde.org>
# SPDX-License-Identifier: BSD-2-Clause

find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS Test Widgets)
find_package(Qt6WaylandCompositor ${QT_MIN_VERSION} QUIET)
include(ECMAddTests)

if(TARGET Qt6::WaylandCompositor)
    file(GENERATE
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/mockinputmethodcompositor_config.h
        CONTENT "#pragma once\n#define PLASMA_KEYBOARD_BINARY_PATH \"$<TARGET_FILE:plasma-keyboard>\"\n"
    )

    ecm_add_test(mockinputmethodcompositor.cpp LINK_LIBRARIES
        KF6::ConfigCore
        PkgConfig::XKBCommon
        Qt::Core
        Qt::Gui
        Qt::GuiPrivate
        Qt::Test
        Qt::WaylandCompositor
        Wayland::Server
    )

    qt6_generate_wayland_protocol_server_sources(mockinputmethodcompositor
        FILES
            ${WaylandProtocols_DATADIR}/unstable/input-method/input-method-unstable-v1.xml
            ${Wayland_DATADIR}/wayland.xml
    )
else()
    message(STATUS "Qt WaylandCompositor is unavailable; skipping the mock compositor test")
endif()

# When the keys are drawn light, without a theme to read.
ecm_add_test(keysthemetest.cpp LINK_LIBRARIES Qt::Gui Qt::Test)
target_include_directories(keysthemetest PRIVATE ${CMAKE_SOURCE_DIR}/src)

qt_add_executable(shuffle-geometry-target geometrytarget.cpp)
target_link_libraries(shuffle-geometry-target PRIVATE Qt::Widgets)

# The key field's layout and gestures, driven by touch in an offscreen window.
find_package(Qt6 ${QT_MIN_VERSION} QUIET COMPONENTS QuickTest)
if(TARGET Qt6::QuickTest)
    qt_add_executable(keyfieldtest keyfieldtest.cpp)
    target_link_libraries(keyfieldtest PRIVATE Qt::QuickTest)
    add_test(NAME keyfield COMMAND keyfieldtest -input ${CMAKE_CURRENT_SOURCE_DIR}/qml)
    set_tests_properties(keyfield PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
else()
    message(STATUS "Qt QuickTest is unavailable; skipping the key field test")
endif()
