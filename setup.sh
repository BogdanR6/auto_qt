#!/bin/zsh

SRC_DIR=src
SRC_CMAKE=${SRC_DIR}/CMakeLists.txt
BUILD_DIR=build
PROJECT_NAME=''

echo ${PROJECT_NAME}
# check if the root CMakeLists exists
if [ ! -f CMakeLists.txt ]; then
  PROJECT_NAME=$1

  if [ -z ${PROJECT_NAME} ]; then
    echo "You must provide the project name"
    exit 1
  fi
  cat > CMakeLists.txt << EOF
cmake_minimum_required(VERSION 3.20)
set(CMAKE_CXX_COMPILER clang++)
project(${PROJECT_NAME} LANGUAGES CXX)

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

else
  # get the project name
  PROJECT_NAME=$(awk '/^project\(/ { gsub(/[()]/, " ", $0); print $2; exit }' CMakeLists.txt)
fi

if [ ! -d ${SRC_DIR} ]; then
  mkdir ${SRC_DIR}
fi

if [ ! -f ${SRC_DIR}/main.cpp ]; then
  cat > ${SRC_DIR}/main.cpp << EOF
#include <QApplication>

int main(int argc, char **argv) {
  QApplication app(argc, argv);
  return app.exec();
}
EOF

fi

if [ ! -f ${SRC_CMAKE} ]; then
  cat > ${SRC_CMAKE} << EOF
# Create the executable
add_executable(main main.cpp)

# Link Qt libraries
target_link_libraries(main PRIVATE Qt6::Widgets Qt6::Core Qt6::Gui)

# Link My Libraries
target_link_libraries(main PRIVATE)
EOF

fi

# create cmake files for all directories
# WARNING: it only supports two layers of deepness inside src folders and 
# it assumes that a folder with folders will create an interface and the folders will create libraries
# DIRS_TO_COMPILE=(`find src/ -type d -maxdepth 1`)
# for DIR in $DIRS_TO_COMPILE
# do
#   DIR_NAME=$DIR
#   FILES_TO_COMPILE=(`find ${DIR} -type f -maxdepth 1 -name '*.cpp'`)
#   if [[ -z $FILES_TO_COMPILE ]]; then
#     NEW_DIRS_TO_COMPILE=(`find ${DIR} -type d -maxdepth 1`)
#     DIRS_TO_COMPILE+=$NEW_DIRS_TO_COMPILE
#     echo "" > dir/CMakeLists.txt
#     for SUBDIR in $NEW_DIRS_TO_COMPILE
#     do
#       echo "add_subdirectory(${SUBDIR})" >> dir/CMakeLists.txt
#     done
# 
#     echo "" >> dir/CMakeLists.txt # just a new line for aesthetics
#     echo "add_library(${DIR_NAME} INTERFACE)"
#     echo "" >> dir/CMakeLists.txt # just a new line for aesthetics
#     echo "target_link_libraries(${DIR} INTERFACE ${NEW_DIRS_TO_COMPILE} Qt6::Core Qt6::Widgets Qt6::Gui)"
#   else
#     echo "add_library(${DIR_NAME} PUBLIC ${FILES_TO_COMPILE})"
#   fi
# 
# done

cmake -S . -B ${BUILD_DIR} -G Ninja
cmake --build ${BUILD_DIR}

# create symlink for compiler
if [ ! -L ${BUILD_DIR}/compiler_commands.json ]; then
  ln -s ${BUILD_DIR}/compiler_commands.json .
fi
