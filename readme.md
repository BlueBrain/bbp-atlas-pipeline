# Blue Brain Atlas Pipeline

## Table of Contents
- [**Introduction**](#introduction)
- [**Installation**](#installation)
  - [Git repository](#git-repository)
  - [Singularity image on BB5](#singularity-image-on-bb5)
  - [Docker image](#docker-image)
- [**Run the pipeline**](#run-the-pipeline)
  - [Running the reference Atlas pipeline](#running-the-reference-atlas-pipeline)
  - [Customize a pipeline rule](#customize-a-pipeline-rule)
  - [Useful Snakemake options](#useful-snakemake-options)
- [**Blue Brain Atlas Pipeline**](#blue-brain-atlas-pipeline-1)
  - [Rules and modules](#rules-and-modules)
  - [Configuration](#configuration)
  - [Additional information](#additional-information)
- [**Appendix**](#appendix)
  - [Placement hints data catalog json format](#placement-hints-data-catalog-json-format)
- [**Acknowledgment**](#funding--acknowledgment)


## Introduction

The Blue Brain Atlas Pipeline (BBAP) is a set of processing modules that generate new data such as:

- Annotation volume, brain region hierarchy, direction vectors, orientations and placement hints for selected brain regions,
- Cell density volumes for several cell types,
- CellComposition summary of the brain regions.

To view the command for creating the Atlas as it is pushed to Nexus and consumed by OBP 
(the "reference" Atlas), see the below section [Running the Reference Atlas Pipeline](#running-the-reference-atlas-pipeline).


## Installation

The Blue Brain Atlas Pipeline (BBAP) can be installed in three different ways:
- via this [Git repository](#git-repository),
- via a [Singularity image](#singularity-image-on-bb5) (recommended),
- via a [Docker image](#docker-image).

For computation time reason and ease of installation, it is recommended to run the pipeline 
on the BB5 cluster via the Singularity image described [hereafter](#singularity-image-on-bb5).
You can log in to the cluster with  
`ssh -l <your-Gaspar-username> bbpv1.epfl.ch`  
and your Gaspar password, or via the [OpenOnDemand service](https://bbpteam.epfl.ch/project/spaces/display/SDKB/JupyterHub+on+BB5).

Once the installation step is completed, go to [Run the pipeline](#run-the-pipeline) for the instructions to run the pipeline.

### Git repository
The BBAP can be installed directly from the `setup.py` file available in this repository:

1. `git clone https://github.com/BlueBrain/bbp-atlas-pipeline.git`
2. `pip install blue_brain_atlas_pipeline/`
3. `cd blue_brain_atlas_pipeline`

#### Dependencies
Each package run as part of the pipeline is considered a pipeline dependency:

- [token-fetch](https://bbpgitlab.epfl.ch/dke/apps/blue_brain_nexus_token_fetch)
- [nexusforge](https://github.com/BlueBrain/nexus-forge)
- [bba-datafetch](https://bbpteam.epfl.ch/project/spaces/display/BBKG/bba-data-fetch)
- [atlas-direction-vectors](https://github.com/BlueBrain/atlas-direction-vectors)
- [atlas-splitter](https://github.com/BlueBrain/atlas-splitter)
- [atlas-placement-hints](https://github.com/BlueBrain/atlas-placement-hints)
- [atlas-densities](https://github.com/BlueBrain/atlas-densities)
- [parcellationexport](https://bbpteam.epfl.ch/project/spaces/display/BBKG/parcellationexport)
- [bba-data-integrity-check](https://bbpteam.epfl.ch/project/spaces/display/BBKG/bba-data-check)
- [bba-data-push](https://bbpteam.epfl.ch/project/spaces/display/BBKG/bba-data-push)

On BB5, most packages are available also as modules:
```
module load unstable \
snakemake \
py-token-fetch \
py-nexusforge \
py-bba-datafetch \
py-atlas-building-tools \
py-bba-webexporter \
py-data-integrity-check \
py-bba-data-push
```
Or they can be installed following the ‘Installation’ section in their Confluence documentation page.

Now you can go to [Run the pipeline](#run-the-pipeline) for the instructions to run the pipeline.


### Singularity image on BB5
A Singularity image (created from the [Docker image](#docker-image)) is available on BB5 in:  
`/gpfs/bbp.cscs.ch/data/project/proj84/atlas_singularity_images/`

The folder contains
- `blue_brain_atlas_pipeline_dev.sif`: development image regularly updated,
- `blue_brain_atlas_pipeline_<tag>.sif`: production image corresponding to a repository [tag](https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline/-/tags)
  (such as `v0.5.2`).

One can spawn the corresponding container with (example with dev) 
1. `module load unstable singularityce`
2. `singularity shell /gpfs/bbp.cscs.ch/data/project/proj84/atlas_singularity_images/blue_brain_atlas_pipeline_dev.sif`  
and run the following commands to copy the pipeline files in a path (e.g `$HOME`) where snakemake can write:  
3. `cp -r /pipeline/blue_brain_atlas_pipeline $HOME`  
4. `cd blue_brain_atlas_pipeline`  

Now you can go to [Run the pipeline](#run-the-pipeline) for the instructions to run the pipeline.


### Docker image
A [Docker](https://docs.docker.com/reference) image containing all the pipeline dependencies is available in the Git [registry](https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline/container_registry/159):  
`bbpgitlab.epfl.ch:5050/dke/apps/blue_brain_atlas_pipeline:<tag>`  
where `<tag>` = `dev` or a repository tag. 

It can be pulled and run with  
1. `docker login bbpgitlab.epfl.ch:5050 -u <your-Gaspar-username> -p <your-Gaspar-password>`
2. `docker pull bbpgitlab.epfl.ch:5050/dke/apps/blue_brain_atlas_pipeline:<tag>`
3. `docker run -it bbpgitlab.epfl.ch:5050/dke/apps/blue_brain_atlas_pipeline:<tag> bash`
4. `cd blue_brain_atlas_pipeline`

or converted into an **Apptainer** image with  
`apptainer pull --docker-login docker://bbpgitlab.epfl.ch:5050/dke/apps/blue_brain_atlas_pipeline:<tag>`

A benchmark of the resources to provision as required by the different pipeline steps 
is available [here](#profiling).

Now you can go to [Run the pipeline](#run-the-pipeline) for the instructions to run the pipeline.


## Run the pipeline

Once the pipeline environment is [installed](#installation), from the root directory execute  
`export PYTHONPATH=.:$PYTHONPATH`  
and the general command to run the pipeline is available:
```
bbp-atlas  --target-rule <target_rule>  --snakemake-options '<options>'
```
where
- `<target_rule>` represents the target action to execute.
- `<options>` represents the snakemake options.  
A set of most common options is available [here](#useful-snakemake-options). 
The option  `--cores <number_of_cores>` is mandatory unless the `--dryrun` option is used,
and must be provided as last option.

_Note_: If running multicore on a BB5 node, the step 
`transplant_mtypes_densities_from_probability_map` may exceed the available memory and 
cause a node failure. Therefore, it is recommended to use a maximum of 70 cores.

A benchmark of the resources required by the different pipeline steps is available [here](#profiling).


### Running the reference Atlas pipeline

The command that is used to run the version of the Blue Brain Atlas Pipeline that is 
pushed to Nexus and then used for OBP is as follows:
```
bbp-atlas  --target-rule push_atlas_datasets  --user-config-path customize_pipeline/user_config.json  --snakemake-options '--config NEXUS_REGISTRATION=True  --cores all'
```

Note that unless you have special permissions, the `push_...` rules are expected to fail
because only some users have write access to Nexus.

The main entities generated by the pipeline are stored under the paths and names defined 
in the config file located at `$HOME/blue_brain_atlas_pipeline/rules_config_dir_templates/push_dataset_config_template.yaml`.  

#### AtlasRelease

The following command:
```
  bbp-atlas  --target-rule push_atlas_release  --snakemake-options '--config NEXUS_REGISTRATION=False  --cores 1'
```
will generate (locally, without registering in Nexus) the following AtlasRelease (see the prod [AtlasRelease entity](https://bbp.epfl.ch/nexus/v1/resources/bbp/atlas/_/https:%2F%2Fbbp.epfl.ch%2Fneurosciencegraph%2Fdata%2F4906ab85-694f-469d-962f-c0174e901885)) datasets:
- parcellationVolume: annotation volume nrrd file generated at the location defined in the config under `GeneratedDatasetPath.VolumetricFile.annotation_ccfv3_l23split_barrelsplit`
- parcellationOntology: brain region hierarchy generated at the location defined in the config under `HierarchyJson.hierarchy_ccfv3_l23split_barrelsplit`
- directionVector: direction vector volume generated at the location defined in the config under `GeneratedDatasetPath.VolumetricFile.direction_vectors_ccfv3`
- cellOrientationField: orientation field volume generated at the location defined in the config under `GeneratedDatasetPath.VolumetricFile.cell_orientations`
- hemisphereVolume: orientation field volume generated at the location defined in the config under `GeneratedDatasetPath.VolumetricFile.hemispheres`
- placementHintsDataCatalog: json catalog of placement hints volumes generated at the location `WORKING_DIR/ph_catalog_distribution.json`
  This catalog has the format described in the [Appendix](#placement-hints-data-catalog-json-format) and groups the placement hints by regions and layers.
  The set of actual placement hints nrrd files are generated at the location defined in the config under `GeneratedDatasetPath.VolumetricFile.placement_hints`

#### CellComposition

The following command:
```
  bbp-atlas  --target-rule push_cellComposition  --snakemake-options '--config NEXUS_REGISTRATION=False  --cores 1'
```
will generate (locally, without registering in Nexus) the following CellComposition (see the prod [CellComposition entity](https://bbp.epfl.ch/nexus/v1/resources/bbp/atlasdatasetrelease/_/https:%2F%2Fbbp.epfl.ch%2Fneurosciencegraph%2Fdata%2Fcellcompositions%2F54818e46-cf8c-4bd6-9b68-34dffbc8a68c)) datasets:
- cellCompositionVolume: json file generated at the location `WORKING_DIR/cellCompositionVolume_payload.json`,
  containing the ids of selected ME-type density nrrd files registered in Nexus,
  grouped by M-type and E-type.  
  The whole set of ME-type densities is generated at the location defined in the config under `GeneratedDatasetPath.VolumetricFile.mtypes_densities_probability_map_transplant`
- cellCompositionSummary: json file generated at the location `WORKING_DIR/cellCompositionSummary_payload.json`,
  containing the values of the ME-type densities in the cellCompositionVolume,
  grouped by regions

***
**NOTE for versions < v1.0.0**  
The selected ME-type densities that enter the [CellCompositionVolume](https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline/-/blob/develop/cellCompVolume_payload.py?ref_type=heads#L16)
are those having a `layer` in their Nexus Resource property `brainLocation`, plus the two   
`Generic{Inhibitory,Excitatory}NeuronMType`-`Generic{Inhibitory,Excitatory}NeuronEType`.

For an ME-type density Resource to be registered by the pipeline with such a `layer` property,
the [Nexus Ontology Class of its M-type](https://bbpteam.epfl.ch/project/spaces/display/BBKG/METypes+Registration#METypesRegistration-Checkexistingcelltypes)
must have the `hasLayerLocationPhenotype` attribute:
```
res = forge.resolve("<M-type label>", scope="ontology", target="CellType", strategy="EXACT_MATCH")
res_layer = res.hasLayerLocationPhenotype
```
***

#### Miscellanea

The rules in the previous commands trigger many intermediate dependent rules as described [here](#blue-brain-atlas-pipeline-1).

The pipeline consumes a configuration file described [here](#configuration), by default 
named `config.yaml` and located in the directory from which the pipeline is run.  
A specific config file can be provided via the `--configfile` option:
```
bbp-atlas  --target-rule <target_rule>  --snakemake-options '--configfile <config_file_path>'
```

**NOTE**  
To run the pipeline skipping the generation of datasets already available (in 
case a previous run failed at an intermediate step for instance), the [option](#useful-snakemake-options) 
`--rerun-trigger mtime` can be used as in the following command:
```
bbp-atlas  --target-rule <target_rule>  --snakemake-options '--rerun-trigger mtime  --cores 1'
```
Such an option allows to skip the execution of the pipeline steps whose output 
files exist and have a modification time (`mtime`) more recent than any of their
input files.
***

### Customize a pipeline rule

It is possible to customize a pipeline rule that generates a (set of) volumetric file 
(`.nrrd`) in order to change the values of a specific region of the volume (and leave 
the rest of the volume unchanged).
The customization happens via the configuration file [`customize_pipeline/user_config.json`](https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline/-/blob/develop/customize_pipeline/user_config.json)
with the following structure:
- `rule`: name of the rule to customize from the default pipeline;
- `brainRegion`: ID of the brain region to customize;
- `CLI`:
  - `command`: CLI to execute in order to produce the volumetric file with the desired values for the brain region of interest;
  - `args`: CLI arguments that can reference variables between curly brackets (see below);
- `output_dir`: path of the folder where the volumetric file(s) is generated by the CLI;
- `container`: URL of the Docker image to use in order to spawn a container where the CLI will be executed. This parameter
is optional: if not provided, the CLI will be executed in the same environment of the default pipeline (in such a case,
the user must ensure that the provided CLI is defined therein).

_Note_: the Snakemake option `--use-singularity` must be provided for the configuration parameter `container` to be considered.

The CLI `args` can reference one or more variables which points to files generated by 
pipeline rules executed before the rule to customize. The list of variables is available
in [customize_pipeline/available_vars.yaml](https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline/-/blob/develop/customize_pipeline/available_vars.yaml).

#### Filename convention
The user must ensure that the files generated by the provided CLI have the same names as
the files generated by the rule to customize.  
For example, the rule `direction_vectors_placeholder_ccfv3`
in the sample configuration generates one output file `direction_vectors_ccfv3.nrrd`.  
The `placement_hints` rule generates seven volumetric files: `[PH]y.nrrd` and 
`[PH]layer_n.nrrd` where n = 1, ..., 6. The mapping between each nrrd file and the layer
it refers to for each region is available in [this dictionary](https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline/-/blob/develop/metadata/PH_layers_regions_map.json),
which the user needs to extend with the `"region acronym": {"layer ID", "layer label"}` 
of its customized region. A layer is considered associated to a region if the 
corresponding layer ID appears in the [regions-to-layers mapping](#brain-region-layers) for that region 
or for at least one of that region's offspring.

#### Customized pipeline
Once the [configuration file](https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline/-/blob/develop/customize_pipeline/user_config.json)
is ready, the customized pipeline can be run with the following command:
```
bbp-atlas  --target-rule <target_rule>  --user-config-path customize_pipeline/user_config.json  --snakemake-options '<options>'
```

When a rule is customized as described above, the pipeline will run
1. the default rule to generate the default output file(s),
2. the CLI provided in the configuration file to produce the corresponding 
region-specific output file(s),
3. a merge step to override the specific region in the default file(s) (step 1) with the 
values of that region from the region-specific file(s) (step 2).

#### Integration
In case a user wants to request the integration of the customized version of a dataset:
1. Open a Merge Request (MR) in this repository including the updated `user_config.json`
and any additional input [metadata](#metadata) required.
2. The MR is then reviewed and, if approved, a new Atlas pipeline dev image is produced accordingly.
3. The new pipeline is run and the new datasets are registered in Nexus staging for wider tests.
4. When the new version of the datasets is validated, a new tag of the Atlas pipeline is
cut and the corresponding image is used to register the datasets in Nexus prod.

##### Metadata
Some pipeline steps require metadata as input, which are fetched from Nexus.  
Currently, the files available in the [`metadata`](https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline/-/tree/develop/metadata)
directory are automatically synchronized with their Nexus versions.  
If you want to update/add one metadata file, make sure to update/add also the 
corresponding documentation file in the [`metadata/docs`](https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline/-/tree/develop/metadata/docs)
directory, keeping the current naming convention (`probability_map_*{.csv,.txt}`).

#### Direction-vectors and placement-hints

If you want to add creation of your region's direction-vectors, placement-hints, or other NRRD files that need to be merged with files containing data from other regions, you should add them using the instructions in [Customize a pipeline rule](#customize-a-pipeline-rule) into `customize_pipeline/user_config.json` instead of the `snakefile` directly.

### Useful Snakemake options

Snakemake being a command-line tool, it comes with a multitude of optional arguments to
execute, debug, and visualize workflows. Here is a selection of the most used:

- `--cores <number_of_cores>`, `-c <number_of_cores>` → Specify the number of cores 
snakemake can use.
- `--dry-run`, `-n` → Perform a dry run (execute nothing but print the list of rules
that would be executed).
- `--rerun-trigger mtime` → Use only the modification time (`mtime`) of the existing 
output files to determine which rules to execute.
- `--forcerun <some_rule>` → Force a given rule to be re-executed (overwrite the output 
if it already exists).
- `--list`, `-l` → Print a list of all the available rules from the snakefile.

Every Snakemake command line argument is listed and described in the [Snakemake](https://snakemake.readthedocs.io/en/stable/) official documentation page.


## Blue Brain Atlas Pipeline

Its workflow consists of the following steps:
1. Fetch the required datasets from Nexus. These input data consist of the [original AIBS ccfv3 brain parcellation](https://bbp.epfl.ch/nexus/web/bbp/atlas/resources/https%3A%2F%2Fbbp.epfl.ch%2Fneurosciencegraph%2Fdata%2F025eef5f-2a9a-4119-b53f-338452c72f2a), 
the [AIBS Mouse CCF Atlas regions hierarchy file](https://bbp.epfl.ch/nexus/web/neurosciencegraph/datamodels/resources/http%3A%2F%2Fbbp.epfl.ch%2Fneurosciencegraph%2Fontologies%2Fmba) and a series of Nissl and ISH volumes 
as described in the documentation page [Allen Mouse CCF Compatible Data](https://bbpteam.epfl.ch/project/spaces/display/BBKG/Allen+Mouse+CCF+Compatible+Data).
2. The fetched datasets are then fed to the [Snakemake](https://snakemake.readthedocs.io/en/stable/) rules, and under the hood consumed by atlas modules to generate products. 
3. Each product can (optionally) be pushed into Nexus with a set of metadata automatically filled up and be visualised in 
the [Blue Brain Atlas](https://bbpteam.epfl.ch/documentation/#:~:text=Visualize-,Blue%20Brain%20Atlas,-Morphology%20visualization).

This workflow is illustrated on the following diagram containing the directed acyclic graph (DAG)
of the Snakemake rules of the BBAP:

![README_pipeline_DAG](doc/source/figures/dag_push_atlas.svg)

A more detailed DAG listing the input and output files for each step is available [here](https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline/-/blob/develop/doc/source/figures/dag_push_atlas_fg.svg).

### Rules and modules
In this document, a “module” is a CLI encapsulated inside one of the components of the pipeline.
Such component is called a “rule”. This terminology comes from SnakeMake, where a “rule” 
can leverage one or more modules and where a module can be used by one of more rules,
usually using a different set of arguments.  
You can find more information on rules in the [SnakeMake documentation](https://snakemake.readthedocs.io/en/stable/).

To only visualize the command that a given rule will execute without running it, one can
use the `--dryrun` option as in the following command:
```
  bbp-atlas  --target-rule <target_rule>  --snakemake-options '--dryrun'
```
The documentation of each command is available in the corresponding pipeline [dependency](#dependencies).

#### Profiling
A detailed profiling of the most resource-intensive rules (sorted by execution order) 
is available in the following table, corresponding to a single core of an 
Intel Xeon Gold 6140 CPU (BB5 node).  
Some rules can exploit multiple cores, in which case a second entry for such rules 
appears in the table along with the number of cores ("--cores n") used for the 
profiling.

The **total multicore wall clock time** required by the two final rules `push_atlas_release` 
(which depends on direction vectors, orientation field, placement hints) and 
`push_cellComposition` (which depends on all the density generation rules) is 
respectively **1 h** (with an RSS peak of 10 GB) and **4 h** (with an RSS peak of 8 GB).

| Rule name                                                   | wall clock time [s] | wall clock time [h:m:s] | max [RSS](https://en.wikipedia.org/wiki/Resident_set_size) [MB] | max [VMS](https://en.wikipedia.org/wiki/Virtual_memory) [MB] | max [USS](https://en.wikipedia.org/wiki/Unique_set_size) [MB] | max [PSS](https://en.wikipedia.org/wiki/Proportional_set_size) [MB] | I/O in [B] | I/O out [B] | average CPU load [%] | CPU time [s] |
|-------------------------------------------------------------|--------------------:|------------------------:|----------------------------------------------------------------:|-------------------------------------------------------------:|--------------------------------------------------------------:|--------------------------------------------------------------------:|-----------:|------------:|---------------------:|-------------:|
| direction_vectors_default_ccfv3                             |            352.1527 |                 0:05:52 |                                                         3345.09 |                                                      4503.41 |                                                       3309.88 |                                                             3321.13 |       0.07 |        0.00 |                98.53 |       347.43 |
| direction_vectors_isocortex_ccfv3                           |            376.2279 |                 0:06:16 |                                                         5438.86 |                                                      6049.21 |                                                       5401.71 |                                                             5412.96 |       0.00 |        0.00 |                92.23 |       347.29 |
| orientation_field                                           |            248.3647 |                 0:04:08 |                                                         8423.66 |                                                      9010.55 |                                                       8388.29 |                                                             8399.54 |       0.00 |        0.00 |                91.73 |       228.17 |
| split_isocortex_layer_23_ccfv3                              |            147.5079 |                 0:02:27 |                                                         1945.17 |                                                      2977.68 |                                                       1866.67 |                                                             1877.88 |       0.83 |        0.00 |                92.70 |       137.05 |
| create_leaves_only_hierarchy_annotation_ccfv3               |             46.3272 |                 0:00:46 |                                                         5897.06 |                                                      6542.66 |                                                       5818.63 |                                                             5830.39 |       0.04 |        0.00 |                36.30 |        17.06 |
| split_barrel_ccfv3_l23split                                 |            141.6368 |                 0:02:21 |                                                          715.49 |                                                      2420.59 |                                                        679.82 |                                                              691.35 |       0.06 |        0.00 |                96.49 |       137.23 |
| validate_annotation_v3                                      |              4.8913 |                 0:00:04 |                                                          908.17 |                                                      1749.66 |                                                        865.54 |                                                              876.86 |       0.03 |        0.00 |                71.09 |         3.81 |
| placement_hints                                             |            924.7421 |                 0:15:24 |                                                         6600.64 |                                                      7225.64 |                                                       6524.41 |                                                             6537.06 |       7.41 |        0.00 |                99.36 |       919.29 |
| create_hemispheres_ccfv3                                    |              6.3128 |                 0:00:06 |                                                          547.75 |                                                      1233.48 |                                                        514.01 |                                                              524.86 |       0.00 |        0.00 |                68.63 |         4.67 |
| export_brain_region                                         |          27482.2978 |                 7:38:02 |                                                         2649.79 |                                                      3214.40 |                                                       3497.71 |                                                             3509.16 |       0.40 |        0.00 |                99.68 |     27395.00 |
| export_brain_region (`--cores 70`)                          |           1162.2325 |                 0:19:22 |                                                       143397.54 |                                                    193202.21 |                                                     115383.76 |                                                          	115749.06 |       0.04 |       	0.00 |             	4307.04 |     50067.62 |
| combine_v2_annotations                                      |             17.5364 |                 0:00:17 |                                                         1030.33 |                                                      1581.99 |                                                       1002.29 |                                                             1015.24 |       1.09 |        0.00 |                85.00 |        15.44 |
| direction_vectors_isocortex_ccfv2                           |            299.9846 |                 0:04:59 |                                                         5483.91 |                                                      6050.02 |                                                       5454.11 |                                                             5467.01 |       0.04 |        0.00 |                95.15 |       285.99 |
| split_isocortex_layer_23_ccfv2                              |            153.1193 |                 0:02:33 |                                                         1999.78 |                                                      2979.68 |                                                       1937.86 |                                                             1950.75 |       0.00 |        0.00 |                88.49 |       135.96 |
| create_leaves_only_hierarchy_annotation_ccfv2               |             31.2190 |                 0:00:31 |                                                         6027.33 |                                                      6836.57 |                                                       6276.27 |                                                             6289.61 |       0.04 |        0.00 |                51.64 |        16.60 |
| split_barrel_ccfv2_l23split                                 |            112.8031 |                 0:01:52 |                                                          737.26 |                                                      2421.75 |                                                        706.36 |                                                              719.25 |       0.06 |        0.00 |                93.59 |       106.04 |
| validate_annotation_v2                                      |              2.3923 |                 0:00:02 |                                                         1116.59 |                                                      1736.83 |                                                       1076.46 |                                                             1089.53 |       0.03 |        0.00 |                66.48 |         2.12 |
| cell_density_correctednissl                                 |             55.1323 |                 0:00:55 |                                                         2867.18 |                                                      3418.92 |                                                       2839.32 |                                                             2852.28 |       0.00 |        0.00 |                82.24 |        45.88 |
| validate_cell_density                                       |              4.8925 |                 0:00:04 |                                                         1252.33 |                                                      2355.65 |                                                       1767.52 |                                                             1780.59 |       0.00 |        0.00 |                76.66 |         4.27 |
| combine_markers                                             |            555.3407 |                 0:09:15 |                                                         5147.12 |                                                      5697.71 |                                                       5119.06 |                                                             5132.01 |       0.00 |        0.00 |                94.58 |       525.61 |
| glia_cell_densities_correctednissl                          |            221.8078 |                 0:03:41 |                                                         7373.72 |                                                      8061.20 |                                                       7298.36 |                                                             7311.31 |       0.00 |        0.00 |                87.87 |       195.19 |
| validate_neuron_glia_cell_densities                         |             17.4026 |                 0:00:17 |                                                         3845.63 |                                                      4698.86 |                                                       4109.74 |                                                             4122.81 |       0.00 |        0.00 |                89.61 |        16.00 |
| average_densities_correctednissl                            |           2886.3829 |                 0:48:06 |                                                         3889.09 |                                                      5342.21 |                                                       3841.21 |                                                             3854.18 |       0.00 |        0.00 |                99.22 |      2864.22 |
| fit_average_densities_correctednissl                        |           2185.0088 |                 0:36:25 |                                                         5605.01 |                                                      7106.13 |                                                       5410.92 |                                                             5423.89 |       0.00 |        0.00 |                99.52 |      2174.67 |
| inhibitory_neuron_densities_linprog_correctednissl          |           2859.1158 |                 0:47:39 |                                                         4799.59 |                                                     18207.76 |                                                       4771.89 |                                                             4784.86 |       0.00 |        0.00 |                99.16 |      2834.94 |
| compute_lamp5_density                                       |             53.7274 |                 0:00:53 |                                                         3652.39 |                                                      4176.77 |                                                       4964.55 |                                                             4977.10 |       0.00 |        0.00 |                83.84 |        45.36 |
| create_mtypes_densities_from_probability_map                |          31310.7357 |                 8:41:50 |                                                        31178.52 |                                                     32289.28 |                                                      31150.59 |                                                            31163.56 |       0.00 |        0.00 |                99.69 |     31209.90 |
| create_mtypes_densities_from_probability_map (`--cores 70`) |           6276.3961 |                 1:44:36 |                                                       394077.36 |                                                   2285360.80 |                                                      63690.27 |                                                            82778.46 |       1.04 |       	0.00 |             	5992.08 |    376431.41 |
| excitatory_split                                            |            222.6994 |                 0:03:42 |                                                         3437.98 |                                                      3989.99 |                                                       3410.12 |                                                             3423.07 |       0.00 |        0.00 |                87.40 |       195.18 |
| create_cellCompositionVolume_payload                        |            414.9835 |                 0:06:54 |                                                               0 |                                                            0 |                                                             0 |                                                                   0 |       0.00 |        0.00 |                 0.25 |            0 |
| create_cellCompositionSummary_payload                       |           1205.1099 |                 0:20:05 |                                                         2414.04 |                                                     	5000.99 |                                                      	2230.68 |                                                             2308.75 |       3.73 |       	0.00 |                84.15 |      1030.68 |
| create_cellCompositionSummary_payload (`--cores 70`)        |            206.0507 |                 0:03:26 |                                                       	21817.64 |                                                     67112.53 |                                                      12911.70 |                                                            13023.87 |       0.00 |       	0.00 |               635.94 |      1314.64 |


#### Fetch rules
The rules starting with "fetch_" are used to download a given file from Nexus.  
The IDs of the corresponding Nexus Resource (containing a description of the file to 
fetch) are listed in the [nexus_ids.json](https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline/-/blob/develop/nexus_ids.json) (the explicit link between a fetch 
rule and the corresponding Resource ID lays in the `nexus_id` parameter of the rule 
definition in the [snakefile](https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline/-/blob/develop/snakefile)).  
_Note_: the rule "fetch_genes_correctednissl" is not linked to a specific Resource, it's 
used just to trigger the execution of a set of single "fetch_gene_" rules needed by the
"fit-average-densities" step.

In order to run the pipeline with a different version of a fetched file, one can just
execute the corresponding fetch rule and subsequently replace the downloaded file with 
the desired version, by keeping the same name of the originally fetched file.  
The `--rerun-trigger mtime` [option](#useful-snakemake-options) may be useful here.

### Configuration

The configuration of the pipeline is provided in the `config.yaml` file. The most important
variables that a user can customize are:

- `WORKING_DIR`: the output directory of the pipeline files,
- `NEXUS_IDS_FILE`: the json file containing the Ids of the Nexus Resources to fetch,
- `FORGE_CONFIG`: the configuration file (yaml) to instantiate nexus-forge,
- `NEW_ATLAS`: boolean flag to trigger the creation of a brand-new atlas release,
- `RESOLUTION`: resolution (in μm) of the input volumetric files to be consumed by the pipeline (default to 25),
- `NEXUS_REGISTRATION`: boolean flag to trigger data registration in Nexus
- `RESOURCE_TAG`: string to use as tag of the data registered in Nexus
- `IS_PROD_ENV`: boolean flag to indicate whether the target Nexus environment is production or not (staging),
- `NEXUS_DESTINATION_ORG`/`NEXUS_DESTINATION_PROJ`: Nexus organization/project where register the pipeline products,
- `DISPLAY_HELP`: boolean flag to display every rule of the snakefile with its descriptions.

It is possible to override the config variables at runtime using the snakemake argument `--config`:  
`--config <VAR_NAME>=<VALUE>`

### Additional information
The release notes are available [here](https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline/-/blob/develop/doc/release_notes.md).

More information about The Blue Brain Atlas Pipeline (BBAP) are available in its [confluence documentation](https://bbpteam.epfl.ch/project/spaces/display/BBKG/Atlas+Pipeline).  
This space contains several documentation pages describing:  
The Allen Mouse CCF Compatible Data : [https://bbpteam.epfl.ch/project/spaces/display/BBKG/Allen+Mouse+CCF+Compatible+Data](https://bbpteam.epfl.ch/project/spaces/display/BBKG/Allen+Mouse+CCF+Compatible+Data)   
The Atlas Modules : [https://bbpteam.epfl.ch/project/spaces/display/BBKG/Atlas+Modules](https://bbpteam.epfl.ch/project/spaces/display/BBKG/Atlas+Modules)


## Appendix

### Brain region layers
Some brain areas have a subdivision in layers.  
The mapping adopted in the BBP between a brain region and the layers it belongs to is 
provided in [this dictionary](https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline/-/blob/develop/metadata/regions_layers_map.json),
where the keys are brain region IDs and the layers are identified with 
[Uberon](https://www.ebi.ac.uk/ols4/ontologies/uberon) classes.  
One layer - "Neocortex layer 6a" - is not present in the Uberon ontology and is defined 
as follows:
```
<https://bbp.epfl.ch/ontologies/core/bmo/neocortex_layer_6a> rdf:type owl:Class ;
    rdfs:subClassOf <http://purl.obolibrary.org/obo/UBERON_0002301> ;
    rdfs:label "L6a"^^xsd:string ;
    <http://www.w3.org/2004/02/skos/core#definition> "Neocortex layer 6a."^^xsd:string ;
    <http://www.w3.org/2004/02/skos/core#altLabel> "layer 6a"^^xsd:string ;
    <http://www.w3.org/2004/02/skos/core#altLabel> "neocortex layer 6a"^^xsd:string  ;
    <http://www.w3.org/2004/02/skos/core#prefLabel> "L6a"^^xsd:string ;
    <http://www.w3.org/2004/02/skos/core#notation> "L6a"^^xsd:string .
```


### Placement hints data catalog json format
```json
{
  "placementHints": [
    {
      "@id": "https://bbp.epfl.ch/data/bbp/atlas/f1049c1b-f1af-4d33-acd9-099f05c56bbf",
      "_rev": 13,
      "distribution": {
        "atLocation": {
          "location": "file:///gpfs/bbp.cscs.ch/data/project/proj39/nexus/bbp/atlas/9/b/1/3/3/7/7/9/%5BPH%5Dlayer_1.nrrd"
        },
        "name": "[PH]layer_1.nrrd"
      },
      "regions": {
        "Isocortex": {
          "@id": "http://api.brain-map.org/api/v2/data/Structure/315",
          "hasLeafRegionPart": [
            "PL1",
            "..."
          ],
          "layer": {
            "@id": "http://purl.obolibrary.org/obo/UBERON_0005390",
            "label": "L1"
          }
        },
        "Hippocampal formation": {
          "@id": "http://api.brain-map.org/api/v2/data/Structure/1089",
          "hasLeafRegionPart": [
            "CA1sp",
            "..."
          ],
          "layer": {
            "@id": "http://purl.obolibrary.org/obo/UBERON_0002313",
            "label": "SP"
          }
        },
        "...": {}
      }
    },
    {
      "@id": "https://bbp.epfl.ch/data/bbp/atlas/74ba22b1-39ee-486d-ab3c-cb960d006a5d",
      "_rev": 13,
      "distribution": {
        "atLocation": {
          "location": "file:///gpfs/bbp.cscs.ch/data/project/proj39/nexus/bbp/atlas/a/9/3/0/d/e/a/8/%5BPH%5Dlayer_2.nrrd"
        },
        "name": "[PH]layer_2.nrrd"
      },
      "regions": {
        "Isocortex": {
          "@id": "http://api.brain-map.org/api/v2/data/Structure/315",
          "hasLeafRegionPart": [
            "AUDp2",
            "..."
          ],
          "layer": {
            "@id": "http://purl.obolibrary.org/obo/UBERON_0005391",
            "label": "L2"
          }
        },
        "Hippocampal formation": {
          "@id": "http://api.brain-map.org/api/v2/data/Structure/1089",
          "hasLeafRegionPart": [
            "CA1so",
            "..."
          ],
          "layer": {
            "@id": "http://purl.obolibrary.org/obo/UBERON_0005371",
            "label": "SO"
          }
        },
        "...": {}
      }
    },
   "..."
  ],
  "voxelDistanceToRegionBottom": {
    "@id": "https://bbp.epfl.ch/data/bbp/atlas/59a2bca3-d8b6-43b1-870e-a0c19a020175",
    "_rev": 13,
    "distribution": {
      "atLocation": {
        "location": "file:///gpfs/bbp.cscs.ch/data/project/proj39/nexus/bbp/atlas/3/9/e/b/6/d/8/b/%5BPH%5Dy.nrrd"
      },
      "name": "[PH]y.nrrd"
    }
  }
}
```


## Funding & Acknowledgment
The development of this software was supported by funding to the Blue Brain Project, a 
research center of the École polytechnique fédérale de Lausanne (EPFL), from the Swiss 
government’s ETH Board of the Swiss Federal Institutes of Technology.

Copyright © 2020-2024 Blue Brain Project/EPFL
