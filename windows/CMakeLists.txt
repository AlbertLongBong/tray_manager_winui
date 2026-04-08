cmake_minimum_required(VERSION 3.15)
set(PROJECT_NAME "tray_manager_winui")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "tray_manager_winui_plugin")

# Option to enable WinUI 3 (requires NuGet, Windows App SDK 1.8+)
option(TRAY_MANAGER_WINUI_USE_WINUI "Enable WinUI 3 context menu" ON)

set(TRAY_MANAGER_WINUI_BUNDLED_LIBS "")

if(TRAY_MANAGER_WINUI_USE_WINUI)
  # NuGet package setup
  # Since 1.8 the top-level Microsoft.WindowsAppSDK is a metapackage;
  # native headers/libs/DLLs live in the Foundation component package,
  # WinUI WinMD files (Microsoft.UI.Xaml) live in the WinUI component package,
  # Microsoft.UI core WinMDs (Interop, Dispatching) live in InteractiveExperiences.
  set(WINUI_PACKAGES_DIR "${CMAKE_CURRENT_BINARY_DIR}/winui_packages")
  set(WindowsAppSDK_Foundation_VER "1.8.260222000")
  set(WindowsAppSDK_InteractiveExp_VER "1.8.260125001")
  set(WindowsAppSDK_WinUI_VER "1.8.260224000")
  set(CppWinRT_VER "2.0.250303.1")

  find_program(NUGET_EXE nuget PATHS ENV PATH)
  find_program(NUGET_EXE nuget.exe PATHS ENV PATH)

  if(NUGET_EXE)
    set(WindowsAppSDK_DIR "${WINUI_PACKAGES_DIR}/Microsoft.WindowsAppSDK.Foundation.${WindowsAppSDK_Foundation_VER}")
    set(WindowsAppSDK_IE_DIR "${WINUI_PACKAGES_DIR}/Microsoft.WindowsAppSDK.InteractiveExperiences.${WindowsAppSDK_InteractiveExp_VER}")
    set(WindowsAppSDK_WinUI_DIR "${WINUI_PACKAGES_DIR}/Microsoft.WindowsAppSDK.WinUI.${WindowsAppSDK_WinUI_VER}")
    set(CppWinRT_DIR "${WINUI_PACKAGES_DIR}/Microsoft.Windows.CppWinRT.${CppWinRT_VER}")
    set(GENERATED_FILES_DIR "${CMAKE_CURRENT_BINARY_DIR}/GeneratedFiles")

    if(NOT EXISTS "${WindowsAppSDK_DIR}")
      execute_process(
        COMMAND "${NUGET_EXE}" install Microsoft.WindowsAppSDK.Foundation -Version ${WindowsAppSDK_Foundation_VER} -OutputDirectory "${WINUI_PACKAGES_DIR}"
        RESULT_VARIABLE NUGET_RESULT
        ERROR_VARIABLE NUGET_ERROR
      )
      if(NOT NUGET_RESULT EQUAL 0)
        message(WARNING "tray_manager_winui: NuGet install Microsoft.WindowsAppSDK.Foundation failed: ${NUGET_ERROR}")
        set(TRAY_MANAGER_WINUI_USE_WINUI OFF)
      endif()
    endif()

    if(TRAY_MANAGER_WINUI_USE_WINUI AND NOT EXISTS "${WindowsAppSDK_WinUI_DIR}")
      execute_process(
        COMMAND "${NUGET_EXE}" install Microsoft.WindowsAppSDK.WinUI -Version ${WindowsAppSDK_WinUI_VER} -OutputDirectory "${WINUI_PACKAGES_DIR}"
        RESULT_VARIABLE NUGET_RESULT
        ERROR_VARIABLE NUGET_ERROR
      )
      if(NOT NUGET_RESULT EQUAL 0)
        message(WARNING "tray_manager_winui: NuGet install Microsoft.WindowsAppSDK.WinUI failed: ${NUGET_ERROR}")
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

    if(TRAY_MANAGER_WINUI_USE_WINUI AND EXISTS "${WindowsAppSDK_DIR}" AND EXISTS "${WindowsAppSDK_WinUI_DIR}" AND EXISTS "${CppWinRT_DIR}")
      # WebView2 is a transitive dependency of the WinUI package; find it
      # dynamically so cppwinrt can resolve Microsoft.UI.Xaml → WebView2 refs.
      file(GLOB _webview2_dirs "${WINUI_PACKAGES_DIR}/Microsoft.Web.WebView2.*/lib")
      list(LENGTH _webview2_dirs _wv2_count)
      if(_wv2_count GREATER 0)
        list(GET _webview2_dirs 0 _webview2_lib_dir)
      else()
        set(_webview2_lib_dir "")
      endif()

      if(NOT EXISTS "${GENERATED_FILES_DIR}/winrt/Microsoft.UI.Xaml.Controls.h")
        file(MAKE_DIRECTORY "${GENERATED_FILES_DIR}")

        set(_cppwinrt_inputs
          -input "${WindowsAppSDK_DIR}/metadata"
          -input "${WindowsAppSDK_IE_DIR}/metadata/10.0.17763.0"
          -input "${WindowsAppSDK_IE_DIR}/metadata/10.0.18362.0"
          -input "${WindowsAppSDK_WinUI_DIR}/metadata"
        )
        if(_webview2_lib_dir)
          list(APPEND _cppwinrt_inputs -input "${_webview2_lib_dir}")
        endif()

        execute_process(
          COMMAND "${CppWinRT_DIR}/bin/cppwinrt.exe" -optimize
            ${_cppwinrt_inputs}
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
          set(WINUI_LIB_ARCH "x64")
          set(WINUI_RID "win-x64")
        elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64")
          set(WINUI_LIB_ARCH "arm64")
          set(WINUI_RID "win-arm64")
        else()
          set(WINUI_LIB_ARCH "x86")
          set(WINUI_RID "win-x86")
        endif()
        set(TRAY_MANAGER_WINUI_BOOTSTRAP_DLL
          "${WindowsAppSDK_DIR}/runtimes/${WINUI_RID}/native/Microsoft.WindowsAppRuntime.Bootstrap.dll")
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
    "${WindowsAppSDK_IE_DIR}/include"
    "${WindowsAppSDK_WinUI_DIR}/include"
    "${GENERATED_FILES_DIR}")
  target_link_directories(${PLUGIN_NAME} PRIVATE
    "${WindowsAppSDK_DIR}/lib/native/${WINUI_LIB_ARCH}")
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
