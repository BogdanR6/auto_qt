#!/bin/zsh

SRC_DIR=src
SRC_CMAKE=${SRC_DIR}/CMakeLists.txt
BUILD_DIR=build

generate_root_cmake() {
  [[ -f CMakeLists.txt ]] && return

  local project_name=$1

  cat > CMakeLists.txt << EOF 
cmake_minimum_required(VERSION 3.20)
set(CMAKE_CXX_COMPILER clang++)
project(${project_name} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_BUILD_TYPE "Debug")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_compile_options(-Wall -Wextra -Wpedantic -Wconversion)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY \${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY \${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY \${CMAKE_BINARY_DIR}/lib)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Widgets Gui)

add_subdirectory(${SRC_DIR})
EOF
}

generate_main_file() {
  cat > ${SRC_DIR}/main.cpp << EOF
#include <QApplication>

int main(int argc, char **argv) {
  QApplication app(argc, argv);
  return app.exec();
}
EOF
}

generate_src_cmake() {
  cat > ${SRC_CMAKE} << EOF
# Create the executable
add_executable(main main.cpp)

# Link Qt libraries
target_link_libraries(main PRIVATE Qt6::Widgets Qt6::Core Qt6::Gui)

# Link My Libraries
target_link_libraries(main PRIVATE)
EOF
}

build_and_compile() {
  if [[ ! -d $BUILD_DIR ]]; then
    cmake -S . -B ${BUILD_DIR} -G Ninja
  fi
  cmake --build ${BUILD_DIR}
}

generate_cmake_for_dir() {
  local dir=$1
  local cmake_file="${dir}/CMakeLists.txt"

  [[ -f $cmake_file ]] && return

  local has_code_files=false
  local subdirs=()

  for item in "$dir"/*; do
    [[ -d $item ]] && subdirs+=("${item##*/}")
    [[ $item == *.cpp || $item == *.h || $item == *.hpp ]] && has_code_files=true
  done

  if $has_code_files; then
    cat  > "$cmake_file" << EOF
# Library for $dir
add_library(${dir##*/} STATIC)

target_sources(${dir##*/}
  PRIVATE
    \$\{CMAKE_CURRENT_SOURCE_DIR\}/*.cpp
    \$\{CMAKE_CURRENT_SOURCE_DIR\}/*.h
)

target_link_libraries(${dir##*/} PRIVATE Qt6::Core Qt6::Widgets Qt6::Gui)
EOF
  else
    cat > "$cmake_file" << EOF 
# Interface library for $dir
add_library(${dir##*/} INTERFACE)

target_include_directories(${dir##*/} INTERFACE \$\{CMAKE_CURRENT_SOURCE_DIR\})

# Add subdirectories
EOF

    for sub in "${subdirs[@]}"; do
      echo "add_subdirectory(${sub})" >> "$cmake_file"
      echo "target_link_libraries(${dir##*/} INTERFACE ${sub})" >> "$cmake_file"
    done
  fi

  for sub in "${subdirs[@]}"; do
    generate_cmake_for_dir "$dir/$sub"
  done
}

# check if the root CMakeLists exists
main () {
  if [ ! -f CMakeLists.txt ]; then
    if [ -z $1 ]; then
      echo "You must provide the project name"
      exit 1
    fi
    generate_root_cmake $1

  fi
  # get the project name
  # PROJECT_NAME=$(awk '/^project\(/ { gsub(/[()]/, " ", $0); print $2; exit }' CMakeLists.txt)

  if [ ! -d ${SRC_DIR} ]; then
    mkdir -p "$SRC_DIR"
    ls -ld "$SRC_DIR"
  fi

  if [ ! -f ${SRC_DIR}/main.cpp ]; then
    generate_main_file
  fi

  if [ ! -f ${SRC_CMAKE} ]; then
    generate_src_cmake
  fi

  src_dirs=("${(@f)$(find src/ -maxdepth 1 -type d)}")
  for dir in "${src_dirs[@]}"; do
    generate_cmake_for_dir "$dir"
  done

  build_and_compile

  # create symlink for lsp
  if [ ! -L compiler_commands.json ]; then
    ln -s ${BUILD_DIR}/compiler_commands.json .
  fi
}

main "$@"
