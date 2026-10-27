find_package(Qt6 6.8 REQUIRED GLOBAL COMPONENTS Qml Quick QuickControls2)
target_compile_definitions(Launcher_logic PRIVATE PROJECTGLASS_NATIVE_FRONTEND)
target_sources(${Launcher_Name} PRIVATE Frontend.cpp PrismBridge.h InstanceEditorFiles.h ModrinthInstallTask.h MacWindowMetrics.h)
target_include_directories(${Launcher_Name} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(${Launcher_Name} PRIVATE Qt6::Quick Qt6::QuickControls2)
if(APPLE)
    target_sources(${Launcher_Name} PRIVATE MacWindow.mm NativeCanvas.inc NativePages.inc NativeDownloadRow.inc)
    set_source_files_properties(MacWindow.mm PROPERTIES COMPILE_FLAGS "-fobjc-arc")
    target_link_libraries(${Launcher_Name} PRIVATE "-framework Cocoa" "-framework QuartzCore")
endif()
qt_add_qml_module(${Launcher_Name} URI ProjectGlass VERSION 1.0 RESOURCE_PREFIX /qt/qml NO_GENERATE_QMLTYPES
    QML_FILES Main.qml GlassLab.qml DownloadData.qml DownloadLogic.js CanvasLayout.js InstanceData.js)

if(APPLE)
    target_compile_options(${Launcher_Name} PRIVATE "$<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>")
endif()

qt_add_resources(${Launcher_Name} project_glass_art PREFIX "/qt/qml/ProjectGlass" FILES
    assets/version-grass.png
    assets/default-account.svg
    assets/default-fabric.svg
    assets/default-forge.png
    assets/default-neoforge.svg
    assets/default-quilt.svg
    assets/default-vanilla.png
    assets/test-adventure.svg
    assets/test-builders.svg
    assets/test-creative.svg
    assets/test-explorer.svg
    assets/test-fabric.svg
    assets/test-factory.svg
    assets/test-hardcore.svg
    assets/test-legacy.svg
    assets/test-neoforge.svg
    assets/test-quilt.svg
    assets/test-rebirth.svg
    assets/test-redstone.svg
    assets/test-skyblock.svg
    assets/test-vanilla.svg
)
