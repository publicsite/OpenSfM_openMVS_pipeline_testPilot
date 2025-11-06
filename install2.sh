#!/bin/sh

OLD_UMASK="$(umask)"
umask 0022

#Prepare and empty machine for building:
apt-get update && apt-get install
apt-get -y install git cmake libpng-dev libjpeg-dev libtiff-dev libglu1-mesa-dev libeigen3-dev

main_path="/source"
mkdir -p "$main_path"
cd "$main_path"

#Boost (Required)
apt-get -y install libboost-iostreams-dev libboost-program-options-dev libboost-system-dev libboost-serialization-dev

#OpenCV (Required)
apt-get -y install libopencv-dev

#CGAL (Required)
apt-get -y install libcgal-dev libcgal-qt5-dev

#VCGLib (Required)
git clone https://github.com/cdcseacave/VCG.git vcglib

#Ceres (Optional)
apt-get -y install libatlas-base-dev libsuitesparse-dev libceres-dev libceres1

#GLFW3 (Optional)
apt-get -y install freeglut3-dev libglew-dev libglfw3-dev

#OpenMVS
#git clone https://github.com/cdcseacave/openMVS.git -b develop openMVS
wget https://github.com/cdcseacave/openMVS/archive/500e808c951da2bcde73b9384fd42791cfc0eebd.tar.gz
tar -xf 500e808c951da2bcde73b9384fd42791cfc0eebd.tar.gz
mv openMVS-* openMVS

##PATCH TO REMOVE NON-FREE DEPENDENCIES
rm -rf openMVS/libs/Math/TRWS
rm -rf openMVS/libs/Math/IBFS
rm openMVS/COPYRIGHT.md
cp patches/openMVS/COPYRIGHT.md openMVS/COPYRIGHT.md
rm openMVS/libs/Math/CMakeLists.txt
cp patches/openMVS/libs/Math/CMakeLists.txt openMVS/libs/Math/CMakeLists.txt
rm openMVS/libs/MVS/Scene.h
cp patches/openMVS/libs/MVS/Scene.h openMVS/libs/MVS/Scene.h
rm openMVS/libs/MVS/SceneReconstruct.cpp
cp patches/openMVS/libs/MVS/SceneReconstruct.cpp openMVS/libs/MVS/SceneReconstruct.cpp
rm openMVS/libs/MVS/SceneDensify.h
cp patches/openMVS/libs/MVS/SceneDensify.h openMVS/libs/MVS/SceneDensify.h
rm openMVS/libs/MVS/SceneDensify.cpp
cp patches/openMVS/libs/MVS/SceneDensify.cpp openMVS/libs/MVS/SceneDensify.cpp
rm openMVS/apps/DensifyPointCloud/DensifyPointCloud.cpp
cp patches/openMVS/apps/DensifyPointCloud/DensifyPointCloud.cpp openMVS/apps/DensifyPointCloud/DensifyPointCloud.cpp

##Revert https://github.com/cdcseacave/openMVS/commit/cd73b4c39147fd26567c603a45d22b0c7fef33cb
##I get ...
#/source/openMVS/libs/MVS/Scene.cpp: In member function 'unsigned int MVS::Scene::Split(MVS::Scene::ImagesChunkArr&, float, int) const':
#/source/openMVS/libs/MVS/Scene.cpp:932:57: error: parameter may not have variably modified type 'float [idxImage]'
#  932 |    const float areaRatio(float(chunkImageAreas[idxImage])/float(imageAreas[idxImage]));
rm openMVS/libs/MVS/Scene.cpp
cp patches/openMVS/libs/MVS/Scene.cpp openMVS/libs/MVS/Scene.cpp

sed -i "s/OpenMVS_USE_CERES OFF/OpenMVS_USE_CERES ON/g" openMVS/CMakeLists.txt
sed -i "s/OpenMVS_USE_NONFREE ON/OpenMVS_USE_NONFREE OFF/g" openMVS/CMakeLists.txt

mkdir openMVS_build && cd openMVS_build
cmake . ../openMVS -DCMAKE_BUILD_TYPE=Release -DVCG_ROOT="$main_path/vcglib" -DBUILD_SHARED_LIBS=OFF -DCGAL_ROOT="/usr/lib/x86_64-linux-gnu/cmake/CGAL/"

#use this option instead for 32 bit
#-DCGAL_ROOT="/usr/lib/i386-linux-gnu/cmake/CGAL/"

#build OpenMVS library:
make -j2

umask "${OLD_UMASK}"

