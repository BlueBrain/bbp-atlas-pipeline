# Release Notes

## v1.0.0 [to be released]
### Description
We introduced an extended and improved version of the Common Coordinate Framework version 3 (CCFv3) from the Allen Institute. This new atlas version is composed of an annotation CCFv3a and an aligned Nissl-stained volume. First, we accurately aligned the Nissl-stained volume from CCFv2 to the CCFv3 incorporating widely recognized registration algorithms from the literature. Second, we filled the missing part of the aligned Nissl-stained volume using automated registration technique. Given this new extended aligned Nissl-stained tissue, we extended the CCFv3 annotation and validated it using image processing tools under expert supervision. This new version CCFv3a annotation plus the aligned Nissl-stained volume now covers the whole mouse brain, having extended the main olfactory bulb, cerebellum and medulla in particular. Third, we identified the granular and molecular layers in the cerebellum in the CCFv3a annotation through several automated registration methods under expert supervision. Those files were provided with negative coordinates from -14 to 551 (566 in total) along the rostro-caudal axis to retrieve the CCFv3 coordinates from 0 to 527 at an isotropic 25μm3 resolution.
In this new atlas release, we also provided the gene expression volumes consumed by the pipeline that were registered to the aligned Nissl-stained volume in the CCFv3a and interpolated using the Deep Atlas pipeline. The raw data was considered for genes CNP (1175), MBP (112202838), GFAP (79591671), S100b (79591593), TMEM119 (68161453) and ALDH1l1 (1724), and the expression data was considered for genes SST (1001), VIP (77371835), PV (868), and GAD67 (479). Because of some significant artifacts on the right hemisphere after interpolation for each dataset, the left hemisphere was mirrored for each one of them. All those gene expression volumes have the same sizes as the aligned Nissl-stained volume, including negative coordinates.

### New features
- Replace CCFv2-to-CCFv3 transplant with single CCFv3 augmented annotation ([Jira](https://bbpteam.epfl.ch/project/issues/browse/MS-5))
- Perform densities validation
- 
### Enhancements
- Use stable region Ids across annotations ([PR](https://github.com/BlueBrain/atlas-splitter/pull/10))
### Bug fixes


## v0.6.0
### New features
- Profile pipeline steps
- Replace `NaN` with `direction-vectors from-center` as default value for direction vectors
- Support service tokens
- Versioning probability maps for ME-type densities
- CI job to automatically run the whole pipeline
- CI job to automatically synchronize probability maps in Nexus
- CI job to automatically update pipeline DAGs 
### Enhancements
- Speed-up pipeline execution by a factor of 6 (1.5 days to 6 hours) 
- Use only packaged software in Docker image
- Improve unit tests
- Improve documentation
### Bug fixes
- Avoid re-execution of a pipeline rule upon token refresh
- Correctly parse variables from user-provided CLI (workaround of snakemake bug) 


## [v0.5.2](https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline/-/tags/v0.5.2)
### New features
### Enhancements
- Speed up generation of CellCompositionVolume
### Bug fixes


## [v0.5.0](https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline/-/tags/v0.5.0)
### New features
### Enhancements
### Bug fixes


## v0.2.0
### New features
### Enhancements
### Bug fixes


## v0.1.0
### New features
### Enhancements
### Bug fixes
