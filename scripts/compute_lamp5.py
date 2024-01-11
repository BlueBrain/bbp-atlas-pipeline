from voxcell import VoxelData

gad67 = VoxelData.load_nrrd(snakemake.params.gad67)
vip = VoxelData.load_nrrd(snakemake.params.vip)
sst = VoxelData.load_nrrd(snakemake.params.sst)
pv = VoxelData.load_nrrd(snakemake.params.pv)
lamp5 = VoxelData(gad67.raw - vip.raw - sst.raw - pv.raw,
    gad67.voxel_dimensions, gad67.offset)

lamp5.save_nrrd(snakemake.output[0])
