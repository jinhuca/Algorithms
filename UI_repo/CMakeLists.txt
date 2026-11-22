# UiKit — shared Qt 6 / QML UI module: design tokens (colours, fonts, dimensions,
# populated from Figma) + generic styled controls. Consumed by app repos (e.g.
# graph_algo's graph_visualizer) via add_subdirectory, and buildable on its own.
cmake_minimum_required(VERSION 3.21)

# Standalone open: define a project + find Qt. When add_subdirectory'd by an app
# that already found Qt6, this block is skipped (mirrors ga::core's guard).
if (NOT TARGET Qt6::Quick)
    project(UiKit LANGUAGES CXX)
    set(CMAKE_CXX_STANDARD 20)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)
    find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2)
    qt_standard_project_setup(REQUIRES 6.5)
endif()

qt_add_library(UiKit STATIC)

# Token singletons must be marked before qt_add_qml_module registers them.
set_source_files_properties(
    qml/UiPrimitives.qml qml/UiPalette.qml qml/Typography.qml qml/Metrics.qml
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
qt_policy(SET QTP0004 NEW)

qt_add_qml_module(UiKit
    URI UiKit
    VERSION 1.0
    QML_FILES
        qml/UiPrimitives.qml
        qml/UiPalette.qml
        qml/Typography.qml
        qml/Metrics.qml
        qml/UiButton.qml
        qml/UiToggleButton.qml
        qml/UiComboBox.qml
        qml/UiMessagePopup.qml
)

target_link_libraries(UiKit PUBLIC Qt6::Quick Qt6::QuickControls2)
