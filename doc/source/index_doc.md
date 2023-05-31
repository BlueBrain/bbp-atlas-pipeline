# Blue Brain Atlas Pipeline

## Introduction

The Atlas Pipeline is a set of processing modules that generate new data such as:

- Aligned datasets from unaligned gene expression slices
- A hybrid annotation volume based on Allen Mouse CCF. This includes:
  - Information from CCFv2 and CCFv3 to reinstate missing brain regions.
  - Split of layer 2 and 3 of the AIBS mouse isocortex.

- Volumes representing cortical and layer depth of Isocortex.
- Compute direction vectors for selected mouse brain regions.
- Cell density volumes for several cell types.
- 3D cell positions in the whole brain.

Data are always fetched from [Nexus](https://bbp.epfl.ch/nexus/web/). If the data are not yet in Nexus, then a phase of data integration has to happen before hand. Having a unique source of data enforces reproducibility and favors traceability and provenance. The pipeline input data originally comes from different experiments performed on the "Allen Institute for Brain Science (AIBS)" P56 adult mouse brain.

Historically, the first mission of this pipeline was to generate cell density volumes as well as point cloud datasets with individual cell positions and cell type (the results as well as the methods are detailed in the paper "A Cell Atlas for the Mouse Brain" by Csaba Eroe et al., 2018.)
As the pipeline was gaining interest and contributors, its scope has broadened, hence the decision to have a more modular approach in terms of software architecture.

At the present time, the goal of this pipeline is to generate some key reference datasets for The Blue Brain Projects to be used by BBP researchers and engineers. In fact, The BBAP can generate datasets and products to be used for the Cell Atlas for the Mouse Brain, the [Circuits building pipeline](https://bbpteam.epfl.ch/documentation/#:~:text=Circuit%20building%20pipeline) and the future new Cell atlas for the Mouse brain.
For now one part of the BBAP is making the full loop from fetching the data from Nexus to push the generated products back to be visualised in the [Blue Brain Atlas](https://bbpteam.epfl.ch/documentation/#:~:text=Visualize-,Blue%20Brain%20Atlas,-Morphology%20visualization) : the one generating datasets used in the [Circuits building pipeline](https://bbpteam.epfl.ch/documentation/#:~:text=Circuit%20building%20pipeline) referred as the **annotation pipeline**.

Its workflow consists of 4 steps :
- Fetch the required datasets from Nexus. These input data consist of the [original AIBS ccfv3 brain parcellation](https://bbp.epfl.ch/nexus/web/bbp/atlas/resources/https%3A%2F%2Fbbp.epfl.ch%2Fneurosciencegraph%2Fdata%2F025eef5f-2a9a-4119-b53f-338452c72f2a) and the [AIBS Mouse CCF Atlas regions hierarchy file](https://bbp.epfl.ch/nexus/web/neurosciencegraph/datamodels/resources/http%3A%2F%2Fbbp.epfl.ch%2Fneurosciencegraph%2Fontologies%2Fmba) as described in the documentation page [Allen Mouse CCF Compatible Data](https://bbpteam.epfl.ch/project/spaces/display/BBKG/Allen+Mouse+CCF+Compatible+Data).

- The fetched datasets are then fed to the rules, and under the hood consumed by atlas modules to generate products. These products consist of [orientation field](https://bbpteam.epfl.ch/project/spaces/display/BBKG/orientation-field), [placement hints](https://bbpteam.epfl.ch/project/spaces/display/BBKG/placement-hints), [splitted annotation volume](https://bbpteam.epfl.ch/project/spaces/display/BBKG/region-splitter) and brain regions [meshes, masks and json summary files](https://bbpteam.epfl.ch/project/spaces/display/BBKG/parcellationexport).

- Each product has its integrity verified based on their format.

- Each product can (optionally) be pushed into Nexus with a set of metadata automatically filled up and be visualised in the [Blue Brain Atlas](https://bbpteam.epfl.ch/documentation/#:~:text=Visualize-,Blue%20Brain%20Atlas,-Morphology%20visualization).

This workflow is illustrated on the following diagram containing the directed acyclic graph (DAG) of the [Snakemake](https://snakemake.readthedocs.io/en/stable/) rules of the BBAP:


![README_annotation_pipeline_DAG](figures/README_annotation_pipeline_DAG.png)



***
**Rules and modules**  
In this document, a “module” is a CLI that could also be launched separately but that was encapsulated inside one of the components of the pipeline. Such component is called a “rule”. This terminology comes from SnakeMake, where a “rule” can leverage one or more “module” and where a “module” can be used by one of more “rule”, usually using a different set of arguments.  
You can find more informations on rules in the SnakeMake [documentation](https://snakemake.readthedocs.io/en/stable/).
***


**Additional informations**  
To see more information about The Blue Brain Atlas Pipeline (BBAP) you can check its [confluence documentation](https://bbpteam.epfl.ch/project/spaces/display/BBKG/Atlas+Pipeline).  
This space contains several documentation pages describing:  
The Allen Mouse CCF Compatible Data : [https://bbpteam.epfl.ch/project/spaces/display/BBKG/Allen+Mouse+CCF+Compatible+Data](https://bbpteam.epfl.ch/project/spaces/display/BBKG/Allen+Mouse+CCF+Compatible+Data)   
The Atlas Modules : [https://bbpteam.epfl.ch/project/spaces/display/BBKG/Atlas+Modules](https://bbpteam.epfl.ch/project/spaces/display/BBKG/Atlas+Modules)


## Installation

_Note: For computation time reason and ease of installation, it is recommended to run the pipeline on BB5._

### Scheduler core

The pipeline is orchestrated by SnakeMake and the snakefile in the root folder of this repository. 
This means SnakeMake must be installed in one of the following ways:

- Snakemake is available as a BB5 module that can be loaded doing :
`module load unstable Snakemake`

- Conda can be used as explained here : https://snakemake.readthedocs.io/en/stable/getting_started/installation.html. Once Snakemake has been installed in an isolated conda environment, you can use it and install the other pipeline dependencies after activating it:
`conda activate <your_snakemake_environment>`

- It is also possible to install it using pip:
`pip install snakemake`

_Note: this uses Python 3.6 or more recent._

### Other dependencies

Each module to run as part of the pipeline can be seen as a dependency of this pipeline. Then each module may come with it’s own dependencies (if installed with Conda, Pip or loaded on BB5) or, on some cases, module-level dependencies will have to be installed manually.

List of modules used by the annotation pipeline:

- [bba-datafetch](https://bbpteam.epfl.ch/project/spaces/display/BBKG/bba-data-fetch)
- [atlas-building-tools direction-vectors isocortex](https://bbpteam.epfl.ch/project/spaces/display/BBKG/direction-vectors)
- [atlas-building-tools orientation-field](https://bbpteam.epfl.ch/project/spaces/display/BBKG/orientation-field)
- [atlas-building-tools region-splitter split-isocortex-layer-23](https://bbpteam.epfl.ch/project/spaces/display/BBKG/region-splitter)
- [atlas-building-tools placement-hints isocortex](https://bbpteam.epfl.ch/project/spaces/display/BBKG/placement-hints)
- [parcellationexport](https://bbpteam.epfl.ch/project/spaces/display/BBKG/parcellationexport)
- [bba-data-integrity-check nrrd-integrity](https://bbpteam.epfl.ch/project/spaces/display/BBKG/bba-data-check)
- [bba-data-integrity-check meshes-obj-integrity](https://bbpteam.epfl.ch/project/spaces/display/BBKG/bba-data-check)
- [bba-data-integrity-check atlas-sonata-integrity](https://bbpteam.epfl.ch/project/spaces/display/BBKG/bba-data-check)
- [bba-data-push push-volumetric](https://bbpteam.epfl.ch/project/spaces/display/BBKG/bba-data-push)
- [bba-data-push push-meshes](https://bbpteam.epfl.ch/project/spaces/display/BBKG/bba-data-push)
- [bba-data-push push-cellrecords](https://bbpteam.epfl.ch/project/spaces/display/BBKG/bba-data-push)
- [bba-data-push push-regionsummary](https://bbpteam.epfl.ch/project/spaces/display/BBKG/bba-data-push)

The packages are available as bb5 module using :

`module load unstable py-atlas-building-tools py-bba-datafetch py-token-fetch py-data-integrity-check py-bba-webexporter py-nexusforge`

Or it can be installed following the ‘Installation’ section in their confluence documentation linked higher.

The CLI bba-data-push is not available as a BB5 module yet. You can install it by following the process detailed in the Installation section of the confluence documentation [here](https://bbpteam.epfl.ch/project/spaces/display/BBKG/bba-data-push).


## Configuration

The configuration of the pipeline is written in the file 'config.yaml'.
Before running the pipeline, make sure you modify:

- `WORKING_DIR` with a directory of your choice (will contain all the files, temporary or not).

- Optionally `NEXUS_IDS_FILE` if the @ids have changed or if you are using a different Nexus environment.

- Optionally `FORGE_CONFIG` corresponding to the forge configuration file (yaml) located within the module bba-data-push directory. The default path value assumes that the bba-data-push module folder is in the same directory as the blue_brain_atlas_pipeline folder.

- Optionally `RESOLUTION` if the input volumetric files of the pipeline are in another resolution other than the default one (25 μm).

- Optionally `MODULES_VERBOSE` (True/False, default : False) if you want to enable supplementary verbosity to be displayed during the run.

- Optionally `DISPLAY_HELP` (True/False, default : False) if you want to display in your console every rules from the snakefile with their descriptions.

- The generated data destination aka the Nexus environment `NEXUS_DESTINATION_ENV`, organisation `NEXUS_DESTINATION_ORG` and project `NEXUS_DESTINATION_PROJ` where your datasets will be eventually push into. You can find more details on the generated datasets on the page Pipeline Products as well as informations on the module dedicated to push data into Nexus on the page bba-data-push.

If you do not want to modify the config file, you can still overload the config settings when running the pipeline in command line using the `--config` flag:

`snakemake --config RESOLUTION="10" --forcerun <some_rule>`


## Launch the pipeline

In a terminal, first cd the workflow folder:

`cd blue_brain_atlas_pipeline`

Then, based on whether the whole pipeline or just a subpart of it needs to be launched, it can be handy to have a list of the tasks:

- `check_annotation_pipeline_volume_datasets` : Generate and check the integrity of the .nrrd volumetric datasets generated by the annotation pipeline.
- `check_annotation_pipeline_mesh_datasets` : Generate and check the integrity of the annotation pipeline mesh datasets.
- `generate_annotation_pipeline_datasets` : Global rule to generate and check the integrity of every products of the annotation pipeline.
- `push_annotation_pipeline_volume_datasets` : Create VolumetricDataLayer resource payloads and push them along with the pipeline volumetric datasets (verified beforehand) into Nexus.
- `push_annotation_pipeline_mesh_datasets` : Create Mesh resource payloads and push them along with the pipeline mesh datasets (verified beforehand) into Nexus.
- `push_annotation_pipeline_datasets` : Global rule to generate, check and push into Nexus every products of the annotation pipeline.

_Note: the pipeline framework (Snakemake) resolves the data dependencies and automatically schedules the tasks to be launched when data are missing. Hence, there is no need to launch all the tasks manually, only the target one._

Then to launch the pipeline up to a certain task:

`snakemake <some_rule>`

where `<some_rule>` is the actual name of a rule, such as `push_annotation_pipeline_datasets`.

Note: Snakemake may ask you to specify the maximum number of CPU cores to use during the run.  
If this occurs, add the configuration argument  `--cores <number_of_cores>`  before  `<some_rule>`.


### Useful Snakemake command line arguments

Snakemake being a command-line tool, it comes with a multitude of optional arguments to execute, debug, and visualize workflows. Here is a selection of the most used :

- `snakemake --dry-run`, `-n` → To conduct a dry run (execute nothing but print a summary of jobs that would be done).

- `snakemake --forcerun <some_rule>` → Force a given rule to be re-executed  (overwrite the already created output.)

- `snakemake --list`, `-l` → Print a list of all the available rules from the snakefile.

- `snakemake <some_rule> --dag | dot -Tpdf > <name_of_your_DAG>.pdf` → Save in a pdf file the directed acyclic graph (DAG) of jobs representing your workflow in the dot language. Several DAG of the atlas pipeline workflow are shown here. Note that the package [graphviz](https://graphviz.org/) need to be installed. As it is available as a BB5 module you can load it doing : `module load instable graphviz`

Every Snakemake CL arguments are listed and described in the Snakemake official documentation page.


## Authors and Contributors :

* Nabil Alibou: <nabil.alibou@epfl.ch>
* Jonathan Lurie: <jonathan.lurie@epfl.ch>

The BBAP is currently maintained by the BlueBrain DKE team: <bbp-ou-dke@groupes.epfl.ch>.
If you face any issue using the BBAP, please send a mail to one of the contributors.
