from collections import namedtuple
from opensfm.large import metadataset
from opensfm.large import tools
from opensfm.dataset import DataSet
from opensfm import reconstruction

PartialReconstruction = namedtuple("PartialReconstruction", ["submodel_path", "index"])

def run_dataset(global_data: DataSet):
    """ Align submodel reconstructions for of MetaDataSet. """

    reconstructions = []

    meta_data = metadataset.MetaDataSet(global_data.data_path)
    for submodel_path in meta_data.get_submodel_paths():
        data = DataSet(submodel_path)
        if not data.reconstruction_exists():
            continue
        areconstruction=data.load_reconstruction()
        for index, partial_reconstruction in enumerate(areconstruction):
            key = PartialReconstruction(submodel_path,index)
            reconstructions.append(areconstruction[key.index]);

    global_data.save_reconstruction(reconstruction.merge_reconstructions(reconstructions, data.config), "reconstruction.aligned.json")
