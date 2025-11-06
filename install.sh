#!/bin/sh

OLD_UMASK="$(umask)"
umask 0022

export DEBIAN_FRONTEND=noninteractive

# Install apt-getable dependencies
apt-get update \
    && apt-get install -y \
        build-essential \
        cmake \
        libeigen3-dev \
        libopencv-dev \
        libceres-dev \
        python3-dev \
        python3-numpy \
        python3-opencv \
        python3-pip \
        python3-pyproj \
        python3-scipy \
        python3-yaml \
        curl \
        wget \
        git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

mkdir /source
cd /source
rm -rf /source/OpenSfM
##git clone --recursive https://github.com/mapillary/OpenSfM
wget https://github.com/mapillary/OpenSfM/archive/69e39cf3f2ba42c9af43816235c6235665a9c5c9.tar.gz -O OpenSfM.tar.gz
tar -xf OpenSfM.tar.gz
mv OpenSfM-* OpenSfM
wget https://github.com/pybind/pybind11/archive/9a19306fbf30642ca331d0ec88e7da54a96860f9.tar.gz -O libpybind.tar.gz
tar -xf libpybind.tar.gz
rmdir OpenSfM/opensfm/src/third_party/pybind11
mv pybind11* OpenSfM/opensfm/src/third_party/pybind11

rm OpenSfM/opensfm/reconstruction.py
cp -a /source/patches/OpenSfM/opensfm/reconstruction.py OpenSfM/opensfm/
rm OpenSfM/opensfm/actions/align_submodels.py
cp -a /source/patches/OpenSfM/opensfm/actions/align_submodels.py OpenSfM/opensfm/actions/
rm OpenSfM/opensfm/actions/export_openmvs.py
cp -a /source/patches/OpenSfM/opensfm/actions/export_openmvs.py OpenSfM/opensfm/actions/
rm OpenSfM/opensfm/actions/undistort.py
cp -a /source/patches/OpenSfM/opensfm/actions/undistort.py OpenSfM/opensfm/actions/
rm OpenSfM/opensfm/actions/export_ply.py
cp -a /source/patches/OpenSfM/opensfm/actions/export_ply.py OpenSfM/opensfm/actions/
rm OpenSfM/opensfm/actions/export_visualsfm.py
cp -a /source/patches/OpenSfM/opensfm/actions/export_visualsfm.py OpenSfM/opensfm/actions/

cd OpenSfM

pip3 install -r requirements.txt

#https://github.com/mapillary/OpenSfM/issues/68
cat /source/OpenSfM/opensfm/src/CMakeLists.txt | while read line; do
if [ "$(printf "%s" "$line" | grep "Compilation Options")" != "" ]; then
        echo "$line" >> /source/OpenSfM/opensfm/src/CMakeListsNew.txt
        echo "set(CMAKE_C_FLAGS \"\${CMAKE_C_FLAGS} -fPIC -msse -msse2 -msse3\")" >> /source/OpenSfM/opensfm/src/CMakeListsNew.txt
        echo "set(CMAKE_CXX_FLAGS \"\${CMAKE_CXX_FLAGS} -fPIC -msse -msse2 -msse3\")" >> /source/OpenSfM/opensfm/src/CMakeListsNew.txt
else
        echo "$line" >> /source/OpenSfM/opensfm/src/CMakeListsNew.txt
fi
done
rm /source/OpenSfM/opensfm/src/CMakeLists.txt
mv /source/OpenSfM/opensfm/src/CMakeListsNew.txt /source/OpenSfM/opensfm/src/CMakeLists.txt

#increase max queue size for large datasets
sed -i "s#max_queue_size = 200#max_queue_size = 5000#g" /source/OpenSfM/opensfm/actions/detect_features.py
sed -i "s#full_queue_timeout = 120#full_queue_timeout = 5000#g" /source/OpenSfM/opensfm/actions/detect_features.py
sed -i "s#timeout=full_queue_timeout#timeout=None#g" /source/OpenSfM/opensfm/actions/detect_features.py
sed -i "s#log.memory_available()#-1#g" /source/OpenSfM/opensfm/actions/detect_features.py
python3 setup.py build

umask "${OLD_UMASK}"

