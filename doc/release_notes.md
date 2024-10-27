# Release Notes

## v1.2.0
### New features
- Apply open-source guidelines
- Add Download_Atlas notebook
### Enhancements
- Update probability maps to populate barrel layers in densities
### Bug fixes
- Correctly filter barrel-split region acronyms in PHs

## v1.1.0
### Enhancements
- Add `tag` metadata to the `atlasRelease` property of Atlas Resources ([MR](https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_nexus_push/-/merge_requests/56)) 

## v1.0.1
### New features
- Perform densities validation
- Drop layer requirement for M-types in CellComposition
- Add CI job for post registration test
- Automatically Create BMO MR to update the parcellation ontology revision
- Add brian regions to layers map
### Enhancements
- Replace CCFv2-to-CCFv3 transplant with single CCFv3 augmented annotation and aligned Nissl-stained volume ([Jira](https://bbpteam.epfl.ch/project/issues/browse/MS-5))
  - Updated gene expression volumes
- Use stable region Ids across annotations ([PR](https://github.com/BlueBrain/atlas-splitter/pull/10))
### Bug fixes
- Update PHs metadata input file to account for new barrel cortex acronyms ([PR](https://github.com/BlueBrain/atlas-placement-hints/pull/14)) 

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
