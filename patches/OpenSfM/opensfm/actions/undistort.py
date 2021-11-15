import itertools
import logging
import os

from opensfm import dataset, undistort
from opensfm.dataset import DataSet

from opensfm import types
from opensfm import pymap
from opensfm import pygeometry
from opensfm import reconstruction
from opensfm.context import parallel_map
from collections import namedtuple

logger = logging.getLogger(__name__)

PartialReconstruction = namedtuple("PartialReconstruction",["submodel_path","index"])

def run_dataset(data: DataSet, toreconstruct, reconstruction_index, tracks, output):
    """Export reconstruction to NVM_V3 format from VisualSfM

    Args:
        reconstruction: reconstruction to undistort
        reconstruction_index: index of the reconstruction component to undistort
        tracks: tracks graph of the reconstruction
        output: undistorted

    """

    #see undistort_reconstruction from undistort.py

    undistorted_data_path = os.path.join(data.data_path, output)
    udata = dataset.UndistortedDataSet(data, undistorted_data_path, io_handler=data.io_handler)
    reconstructions = data.load_reconstruction(toreconstruct)

    if data.tracks_exists(tracks):
        tracks_manager = data.load_tracks_manager(tracks)
    else:
        tracks_manager = None

    if reconstructions:

        urec = []
        undistorted_shots={}

        utracks_manager = pymap.TracksManager()

        for index, partial_reconstruction in enumerate(reconstructions):
             key = PartialReconstruction(data.data_path,index)
             image_format=data.config["undistorted_image_format"]
             urec.append(types.Reconstruction())
             urec[key.index].points=reconstructions[key.index].points
             print(len(reconstructions[key.index].points))
             urec[key.index].reference=reconstructions[key.index].reference
             rig_instance_count = itertools.count()
             logger.debug("Undistorting partial reconstruction " + str(index))
             for shot in reconstructions[key.index].shots.values():
                 if shot.camera.projection_type == "perspective":
                     camera = undistort.perspective_camera_from_perspective(shot.camera)
                     urec[key.index].add_camera(camera)
                     subshots = [undistort.get_shot_with_different_camera(urec[key.index], shot, camera, image_format)]
                 elif shot.camera.projection_type == "brown":
                     camera = undistort.perspective_camera_from_brown(shot.camera)
                     urec[key.index].add_camera(camera)
                     subshots = [undistort.get_shot_with_different_camera(urec[key.index], shot, camera, image_format)]
                 elif shot.camera.projection_type in ["fisheye", "fisheye_opencv"]:
                     camera = undistort.perspective_camera_from_fisheye(shot.camera)
                     urec[key.index].add_camera(camera)
                     subshots = [undistort.get_shot_with_different_camera(urec[key.index], shot, camera, image_format)]
                 elif pygeometry.Camera.is_panorama(shot.camera.projection_type):
                     subshot_width = int(data.config["depthmap_resolution"])
                     subshots = undistort.perspective_views_of_a_panorama(
                         shot, subshot_width, urec[key.index], image_format, rig_instance_count
                     )

                 for subshot in subshots:
                     if tracks_manager:
                         undistort.add_subshot_tracks(tracks_manager, utracks_manager, shot, subshot)
                 undistorted_shots[shot.id] = subshots

        #udata.save_undistorted_reconstruction(reconstruction.merge_reconstructions(urec, data.config))

        udata.save_undistorted_reconstruction(urec)

        if tracks_manager:
             udata.save_undistorted_tracks_manager(utracks_manager)

        udata.save_undistorted_shot_ids(
            {
                 shot_id: [shot_id for ushot in ushots] for shot_id, ushots in undistorted_shots.items()
            }
        )

        #see undistort_reconstruction_with_images from undistort.py

        arguments = []
        for index, key in enumerate(reconstructions):
            for shot in reconstructions[index].shots.values():
                arguments.append((shot, undistorted_shots[shot.id], data, udata))

        processes = data.config["processes"]
        parallel_map(undistort.undistort_image_and_masks, arguments, processes)
