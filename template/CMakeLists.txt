cmake_minimum_required(VERSION 3.16)
project(SpaceInvaders CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# tutti i .cpp in src/ (anche quelli aggiunti dopo), gli header in include/
file(GLOB SOURCES CONFIGURE_DEPENDS src/*.cpp)
add_executable(spaceinvaders ${SOURCES})
target_include_directories(spaceinvaders PRIVATE include)
target_compile_options(spaceinvaders PRIVATE -Wall -Wextra)

if(WIN32)
    # Windows (MSYS2 UCRT64): PDCurses
    find_path(CURSES_INCLUDE_DIR curses.h PATH_SUFFIXES pdcurses REQUIRED)
    # la versione per console (libpdcurses.a apre una finestra sua), statica: l'eseguibile parte senza DLL accanto
    find_library(CURSES_LIBRARY libpdcurses_wincon.a REQUIRED)
    target_include_directories(spaceinvaders PRIVATE ${CURSES_INCLUDE_DIR})
    # la PDCurses di MSYS2 è compilata in UTF-8: senza questa define non si linka
    target_compile_definitions(spaceinvaders PRIVATE PDC_FORCE_UTF8)
    # winmm: PDCurses la usa per beep()
    target_link_libraries(spaceinvaders PRIVATE ${CURSES_LIBRARY} winmm -static)
else()
    # Linux e macOS: ncurses
    find_package(Curses REQUIRED)
    target_include_directories(spaceinvaders PRIVATE ${CURSES_INCLUDE_DIRS})
    target_link_libraries(spaceinvaders PRIVATE ${CURSES_LIBRARIES})
endif()
