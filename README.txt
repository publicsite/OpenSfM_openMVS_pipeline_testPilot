=== TEST PILOTING STRUCTURE FROM MOTION [2021] ===

A High Definition piece of drone footage was given to me to reconstruct.

In a previous round of testing, using fewer images, a still camera and older code bases, I tested:

RunSFM, SfM-Toy-Library, OpenMVG, micmac, TomoPy, COLMAP, Insight3d, PMVS, Bundler, Theia-SfM, LSD-Slam and OpenSFM

I found OpenSFM to be most suitable at the time, so I decided to use OpenSFM to reconstruct the footage this time around too.

Note, I also chose this over other 'drone-specific' reconstruction softwares [and wrappers] because I wanted the software to be also applicable
to '3D scanning' using photographs, not just drones.

I created a script to build OpenSFM in a chroot created from an Ubuntu 20.04.2 iso. You can use this script to build (although things might have changed since), by running:

	./get.sh

After building OpenSFM, I started on the data by extracting frames from the drone footage. I did this with ffmpeg.

First by cutting the footage ...

	ffmpeg -ss 00:07:00 -i video.mp4 -c copy -t 00:01:08 shot-1.mp4

(where ss is the start time, t is the duration of _the clip you want to cut_)

... and then by extracting the images:

	ffmpeg -i shot1.mp4 -r 25 images/imageA-%3d.jpeg

(where r is the frames per second)

I then put these in a directory in the chroot in source/OpenSfM/data/mydataset/images

I copied config.yaml from source/OpenSfM/data/berlin to source/OpenSfM/data/mydataset/

I then tried running the reconstruction as-is, in the chroot:

	cd source/OpenSfM
	bin/opensfm_run_all data/mydataset

It failed, due to running out of memory. This was to do with the queue in opensfm not working properly.

So I modified /source/OpenSfM/opensfm/actions/detect_features.py to load the images all at once. (Relevant changes are included in the build scripts already.)

It then ran out of memory again so in source/OpenSfM/config.py I then set:

	processes: 1

As parallel processing seemed to use too much memory.

This also ran out of memory, but I could then get OpenSFM to continue to the matching stage by creating a 150GB swap.

I did this, on the host, by:

	sudo fallocate -l 150G /.swapfile
	sudo chmod 600 /.swapfile
	sudo mkswap /.swapfile
	sudo swapon /.swapfile

This swapfile will not survive reboots, which is OK for running a few reconstructions. However, the swap file will remain, taking up space on the system.
So once you have run all your reconstructions, you can delete the swap and swapfile by:

	sudo swapoff /.swapfile
	sudo rm /.swapfile

After I ran OpenSFM again with the swap, the matching stage then took forever and never completed. I had a total of 4758 images, each with
a resolution of 4096x2160, with a combined total file size of 1.7 GigaBytes.

So I set;

	matching_order_neighbors: 0

to instead read;

	matching_order_neighbors: 20

This then got further, but failed at the "incremental reconstruction" stage because it ran out of memory.

I then tried to create submodels, first by modifying source/OpenSfM/bin/opensfm_run_all to add the create_submodels process here:

	"$DIR"/opensfm extract_metadata "$1"
	"$DIR"/opensfm create_submodels "$1"
	"$DIR"/opensfm detect_features "$1"
	"$DIR"/opensfm match_features "$1"

... which failed due to lack of GPS information. And then instead (, in this order): 

	"$DIR"/opensfm extract_metadata "$1"
	"$DIR"/opensfm detect_features "$1"
	"$DIR"/opensfm match_features "$1"
	"$DIR"/opensfm create_submodels "$1"

... which also failed.

I also attempted to create a image_groups.txt file, with no additional success.

As the drone footage did not contain GPS information, I modified in the chroot source/OpenSfM/config.py

So that the following line, beginning with;

	matching_order_neighbors: 0

instead read:

	matching_order_neighbors: 2

(NOTE: Unfortunately, setting this value is a bit of an art.
	If you set it too high, it might take too long to complete the matching stage, or use too much memory in the incremental reconstruction stage,
	and if you set it too low, you might get a poorer reconstruction at the end of it as a result.
	Therefore, there is no easy way to tell you the 'correct answer' at what value to set it,
	it is dependent on many factors, such as your hardware and software environment and dataset etc.)

After setting matching_order_neighbors to "2" in the config. It finally reconstructed OK.

To export a PLY file to open with meshlab (data/mydataset/reconstruction.ply), I used

	bin/opensfm export_ply data/mydataset

To get textures, I used openmvs (which is built in the scripts I created).

To export the reconstruction in a format for openmvs (data/mydataset/undistorted/openmvs/scene.mvs), I used:

	bin/opensfm export_openmvs data/mydataset

cd to data/mydataset/undistorted/openmvs, and run

	/source/openMVS_build/bin/DensifyPointCloud scene.mvs

This failed for me because it was too slow, so I scaled the images like this:

	/source/openMVS_build/bin/DensifyPointCloud --resolution-level 2 scene.mvs

I then ran mesh reconstruction like so:

	/source/openMVS_build/bin/ReconstructMesh scene_dense.mvs

I then tried RefineMesh, but it was too slow. Interestingly enough, increasing the amount of stages seemed to reduce the overall time, but still it wasn't enough,
so I skipped this optional step.

to densify the point cloud (a requirement to) then run:

	/source/openMVS_build/bin/TextureMesh --export-type obj --resolution-level 2 --decimate 0.05 scene_dense_mesh.mvs

The decimate argument reduces the number of faces in the mesh. This is the main bottleneck in processing. It has to be low enough for the software to run. Setting it
at 0.05 seemed to work OK.
_______________________________________________________________________________________________________________

Note, whilst running the reconstruction. I changed virtual terminal, by using CTRL+ALT+F1 and killed xorg, and the X display manager,
for stability and to free up some memory.
__________________________________________________________________________________________________________________

In the mean time, while it was reconstructing. I wrote two scripts,

To use them, make your /source/OpenSfM/bin/opensfm_run_all to look like this (note the commented out lines):

	#!/usr/bin/env bash

	set -e

	DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

	"$DIR"/opensfm extract_metadata "$1"
	"$DIR"/opensfm detect_features "$1"
	"$DIR"/opensfm match_features "$1"
	#"$DIR"/opensfm create_tracks "$1"
	#"$DIR"/opensfm reconstruct "$1"
	#"$DIR"/opensfm mesh "$1"
	#"$DIR"/opensfm undistort "$1"
	#"$DIR"/opensfm compute_depthmaps "$1"


THEN:

set in /source/OpenSfM/config.py
	matching_order_neighbors: 3

and run

	bin/OpenSfM/opensfm_run_all

THEN:

If images from your first shot are named ImageA-1.png, ImageA-2.png, ImageA-3.png (...) you can run:

	./makeSubmodelStructure.sh data/mydataset ImageA 0000

Where "ImageA" is the filename prefix of the images, and 0000 means it's shot 0.

Likewise if your second shot images are named ImageB-1.png, ImageB-2.png, ImageB-3.png (...) you then run:

	./makeSubmodelStructure.sh data/mydataset ImageB 0001

Where "ImageB" is the filename prefix of the images, and 0001 means it's shot 1.

You do this for all the shots, and finally run:

	./runRest.sh data/mydataset

To run the reconstruction for each submodel (shot) and align, then texture etc. the final result.
__________________________________________________________________________________________________________________

=Other Notes:==

1) RefineMesh wasn't much quicker with CERES.

RefineMesh times ... 

With CERES

real	3m54.503s
user	6m49.411s
sys	0m2.460s

Without CERES

real	4m0.979s
user	6m53.379s
sys	0m2.212s


2) To explain the patches in OpenSfM ... they make it so all of the reconstruction is exported (ie. all of the partial reconstructions, rather than the 
partial reconstruction indexed at 0.

3) To explain the patches in openMVS ... they remove some stuff that has a non-free licence.

4) The code I provide here might not run 'out of the box' and may need tweaking.

5) Patches for OpenSfM are under the OpenSfM licence. Patches for openMVS are under the openMVS licence.

6) This stuff here is Copyright (c) J05HYYY , where that copyright can apply.
__________________________________________________________________________________________________________________

=Discussion of results:=

After all this, results weren't fantastic. It worked, but it didn't create a very good mesh, unfortunately.

__________________________________________________________________________________________________________________
Links:

[0] https://en.wikipedia.org/wiki/Comparison_of_photogrammetry_software
[1] https://github.com/mapillary/OpenSfM
[2] https://www.opendronemap.org/
[3] https://stackoverflow.com/questions/34786669/extract-all-video-frames-as-images-with-ffmpeg/34786929
[4] https://superuser.com/questions/138331/using-ffmpeg-to-cut-up-video
[5] https://itsfoss.com/create-swap-file-linux/
[6] https://opensfm.readthedocs.io/en/latest/using.html
[7] https://opensfm.readthedocs.io/en/latest/large.html?highlight=align_submodels
[8] https://github.com/mapillary/OpenSfM/blob/master/Dockerfile
[9] https://github.com/mapillary/OpenSfM/blob/master/bin/opensfm_run_all
[10] https://github.com/mapillary/OpenSfM/blob/main/opensfm/actions/detect_features.py
[11] http://cdimage.ubuntu.com/ubuntu-base/releases