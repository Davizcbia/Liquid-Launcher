cmake_minimum_required(VERSION 3.21)
project(ProjectGlass LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2)
qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(ProjectGlass
    main.cpp
    MacWindowMetrics.h
)

if(APPLE)
    enable_language(OBJCXX)
    target_sources(ProjectGlass PRIVATE MacWindow.mm)
    set_source_files_properties(MacWindow.mm PROPERTIES COMPILE_FLAGS "-fobjc-arc")
    target_link_libraries(ProjectGlass PRIVATE "-framework Cocoa")
endif()

qt_add_qml_module(ProjectGlass
    URI ProjectGlass
    VERSION 1.0
    QML_FILES Main.qml GlassLab.qml DownloadData.qml DownloadLogic.js
)

target_link_libraries(ProjectGlass
    PRIVATE Qt6::Quick Qt6::QuickControls2
)

set_target_properties(ProjectGlass PROPERTIES
    OUTPUT_NAME "ProjectGlassApp"
)
