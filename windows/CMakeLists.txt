cmake_minimum_required(VERSION 3.15)
set(PROJECT_NAME "tray_manager_winui")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "tray_manager_winui_plugin")

# Option to enable WinUI 3 (requires NuGet, Windows App SDK 1.3+)
option(TRAY_MANAGER_WINUI_USE_WINUI "Enable WinUI 3 context menu" ON)

set(TRAY_MANAGER_WINUI_BUNDLED_LIBS "")

if(TRAY_MANAGER_WINUI_USE_WINUI)
  # NuGet package setup
  set(WINUI_PACKAGES_DIR "${CMAKE_CURRENT_BINARY_DIR}/winui_packages")
  set(WindowsAppSDK_VER "1.5.240311000")
  set(CppWinRT_VER "2.0.240405.15")

  find_program(NUGET_EXE nuget PATHS ENV PATH)
  find_program(NUGET_EXE nuget.exe PATHS ENV PATH)

  if(NUGET_EXE)
    set(WindowsAppSDK_DIR "${WINUI_PACKAGES_DIR}/Microsoft.WindowsAppSDK.${WindowsAppSDK_VER}")
    set(CppWinRT_DIR "${WINUI_PACKAGES_DIR}/Microsoft.Windows.CppWinRT.${CppWinRT_VER}")
    set(GENERATED_FILES_DIR "${CMAKE_CURRENT_BINARY_DIR}/GeneratedFiles")

    if(NOT EXISTS "${WindowsAppSDK_DIR}")
      execute_process(
        COMMAND "${NUGET_EXE}" install Microsoft.WindowsAppSDK -Version ${WindowsAppSDK_VER} -OutputDirectory "${WINUI_PACKAGES_DIR}"
        RESULT_VARIABLE NUGET_RESULT
        ERROR_VARIABLE NUGET_ERROR
      )
      if(NOT NUGET_RESULT EQUAL 0)
        message(WARNING "tray_manager_winui: NuGet install Microsoft.WindowsAppSDK failed: ${NUGET_ERROR}")
        set(TRAY_MANAGER_WINUI_USE_WINUI OFF)
      endif()
    endif()

    if(TRAY_MANAGER_WINUI_USE_WINUI AND NOT EXISTS "${CppWinRT_DIR}")
      execute_process(
        COMMAND "${NUGET_EXE}" install Microsoft.Windows.CppWinRT -Version ${CppWinRT_VER} -OutputDirectory "${WINUI_PACKAGES_DIR}"
        RESULT_VARIABLE NUGET_RESULT
        ERROR_VARIABLE NUGET_ERROR
      )
      if(NOT NUGET_RESULT EQUAL 0)
        message(WARNING "tray_manager_winui: NuGet install Microsoft.Windows.CppWinRT failed: ${NUGET_ERROR}")
        set(TRAY_MANAGER_WINUI_USE_WINUI OFF)
      endif()
    endif()

    if(TRAY_MANAGER_WINUI_USE_WINUI AND EXISTS "${WindowsAppSDK_DIR}" AND EXISTS "${CppWinRT_DIR}")
      if(NOT EXISTS "${GENERATED_FILES_DIR}/winrt/Microsoft.UI.Xaml.Controls.h")
        file(MAKE_DIRECTORY "${GENERATED_FILES_DIR}")
        execute_process(
          COMMAND "${CppWinRT_DIR}/bin/cppwinrt.exe" -optimize
            -input "${WindowsAppSDK_DIR}/lib/uap10.0"
            -input "${WindowsAppSDK_DIR}/lib/uap10.0.18362"
            -input sdk
            -output "${GENERATED_FILES_DIR}"
          RESULT_VARIABLE CPPWINRT_RESULT
        )
        if(NOT CPPWINRT_RESULT EQUAL 0)
          message(WARNING "tray_manager_winui: cppwinrt.exe failed")
          set(TRAY_MANAGER_WINUI_USE_WINUI OFF)
        endif()
      endif()

      if(TRAY_MANAGER_WINUI_USE_WINUI)
        if(CMAKE_SYSTEM_PROCESSOR MATCHES "AMD64|x86_64")
          set(WINUI_RUNTIME_ARCH "win10-x64")
        elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64")
          set(WINUI_RUNTIME_ARCH "win10-arm64")
        else()
          set(WINUI_RUNTIME_ARCH "win10-x86")
        endif()
        set(TRAY_MANAGER_WINUI_BOOTSTRAP_DLL
          "${WindowsAppSDK_DIR}/runtimes/${WINUI_RUNTIME_ARCH}/native/Microsoft.WindowsAppRuntime.Bootstrap.dll")
        list(APPEND TRAY_MANAGER_WINUI_BUNDLED_LIBS "${TRAY_MANAGER_WINUI_BOOTSTRAP_DLL}")
      endif()
    endif()
  else()
    message(STATUS "tray_manager_winui: NuGet not found - using stub (no WinUI menu)")
    set(TRAY_MANAGER_WINUI_USE_WINUI OFF)
  endif()
endif()

add_library(${PLUGIN_NAME} SHARED
  "tray_manager_winui_plugin.cpp"
  "winui_context_menu.cpp"
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

if(TRAY_MANAGER_WINUI_USE_WINUI)
  target_compile_definitions(${PLUGIN_NAME} PRIVATE TRAY_MANAGER_WINUI_USE_WINUI=1)
  target_include_directories(${PLUGIN_NAME} PRIVATE
    "${WindowsAppSDK_DIR}/include"
    "${GENERATED_FILES_DIR}")
  target_link_directories(${PLUGIN_NAME} PRIVATE
    "${WindowsAppSDK_DIR}/lib/${WINUI_RUNTIME_ARCH}")
  target_link_libraries(${PLUGIN_NAME} PRIVATE
    flutter flutter_wrapper_plugin
    Microsoft.WindowsAppRuntime.Bootstrap
    Microsoft.WindowsAppRuntime
    WindowsApp
    ole32 oleaut32)
  add_custom_command(TARGET ${PLUGIN_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      "${TRAY_MANAGER_WINUI_BOOTSTRAP_DLL}"
      "$<TARGET_FILE_DIR:${PLUGIN_NAME}>"
    COMMENT "Copying Microsoft.WindowsAppRuntime.Bootstrap.dll")
else()
  target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)
endif()

set(tray_manager_winui_bundled_libraries
  ${TRAY_MANAGER_WINUI_BUNDLED_LIBS}
  PARENT_SCOPE
)
