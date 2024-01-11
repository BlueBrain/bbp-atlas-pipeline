import voxcell
from atlas_commons.utils import assign_hemispheres

annotation = voxcell.VoxelData.load_nrrd(snakemake.input[0])
hemispheres = assign_hemispheres(annotation)
hemispheres.save_nrrd(snakemake.output[0])
