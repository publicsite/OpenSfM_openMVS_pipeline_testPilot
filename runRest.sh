#!/bin/sh
openMVSbin="/source/OpenMVS/bin"

if ! [ -d "$1" ]; then
printf "Argument 1: Dataset \"$1\" does not exist.\n"
exit
fi

bin/opensfm create_tracks "${1}"

find "${1}/submodels/" -mindepth 1 -maxdepth 1 -type d | while read line; do
	bin/opensfm create_tracks $line
	bin/opensfm reconstruct $line
done

bin/opensfm align_submodels ${1}

mv "${1}/reconstruction.aligned.json" "${1}/reconstruction.json"

on=0
find "${1}/submodels/" -mindepth 1 -maxdepth 1 -type d | while read line; do
	if [ "$on" = 0 ]; then
		cat "$line/tracks.csv" > "${1}/tracks.csv"
		on=1
	else
		tail -n+2 "$line/tracks.csv" >> "${1}/tracks.csv"
	fi
done

bin/opensfm mesh "${1}"

bin/opensfm undistort "${1}"

bin/opensfm export_openmvs "${1}"

###START OF OPENMVS###

cd "${1}/undistorted/openmvs"

${openMVSbin}/DensifyPointCloud --resolution-level 2 scene.mvs
${openMVSbin}/ReconstructMesh scene_dense.mvs
##we comment RefineMesh out as it is too slow, and optional.
#${openMVSbin}/RefineMesh scene_dense_mesh.mvs --resolution-level 2 --stages 10 # Note, higher stages results in quicker times
${openMVSbin}/TextureMesh --export-type obj --resolution-level 2 --decimate 0.05 scene_dense_mesh.mvs
