# Release Notes

## v1.0.0 [to be released]
### New features
- Perform densities validation
### Enhancements
- Replace CCFv2-to-CCFv3 transplant with single CCFv3 augmented annotation and aligned Nissl-stained volume ([Jira](https://bbpteam.epfl.ch/project/issues/browse/MS-5))
  - Updated gene expression volumes
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
