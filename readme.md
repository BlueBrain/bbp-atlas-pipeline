The Blue Brain Atlas Pipeline (BBAP) is documented on confluence here : https://bbpteam.epfl.ch/project/spaces/display/BBKG/Atlas+Pipeline
This space contains several documentation pages describing:

Allen Mouse CCF Compatible Data : https://bbpteam.epfl.ch/project/spaces/display/BBKG/Allen+Mouse+CCF+Compatible+Data
Atlas Modules : https://bbpteam.epfl.ch/project/spaces/display/BBKG/Atlas+Modules
Pipeline installation & configuration : https://bbpteam.epfl.ch/project/spaces/pages/viewpage.action?pageId=51548376
Pipeline Products : https://bbpteam.epfl.ch/project/spaces/display/BBKG/Pipeline+Products


Authors and Contributors :

* Nabil Alibou: nabil.alibou@epfl.ch
* Jonathan Lurie: jonathan.lurie@epfl.ch

The BBAP is currently maintained by the BlueBrain DKE team: <bbp-ou-dke@groupes.epfl.ch>.
If you face any issue using the BBAP, please send a mail to one of the contributors.


# Atlas Pipeline


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

Data are always fetched from Nexus (https://bbp.epfl.ch/nexus/web/). If the data are not yet in Nexus, then a phase of data integration has to happen before hand. Having a unique source of data enforces reproducibility and favors traceability and provenance. The pipeline input data originally comes from different experiments performed on the "Allen Institute for Brain Science (AIBS)" P56 adult mouse brain (the datasets are listed and detailed on this page: [https://bbpteam.epfl.ch/project/spaces/display/BBKG/Allen+Mouse+CCF+Compatible+Data]).

Historically, the first mission of this pipeline was to generate cell density volumes as well as point cloud datasets with individual cell positions and cell type (the results as well as the methods are detailed in the paper "A Cell Atlas for the Mouse Brain" by Csaba Eroe et al., 2018.)
As the pipeline was gaining interest and contributors, its scope has broadened, hence the decision to have a more modular approach in terms of software architecture. 

Now, the goal of this pipeline is to generate some key reference datasets for The Blue Brain Projects to be used by BBP researchers and engineers. This can be made possible only if some strict rules are respected, among them:

Each module of the pipeline must be independent, with a limited scope that does not overlap on the scope of other modules
Each module must be documented and maintained by a domain expert
The code of each module must be versioned (git)
Alongside the generated datasets must be recorded which modules and which versions of these modules was used, as well as which input data
The generated datasets must be pushed into a trustable platform, where versioning, provenance, rich metadata and integrity check are the norm
The datasets produced by this pipeline must be made available to everyone at BBP who may need it, with simple tools


## Installation


### Scheduler core

The pipeline is orchestrated by SnakeMake and the snakefile in the root folder of this repository. This means SnakeMake must be installed either using conda (recommended way) as explained here : https://snakemake.readthedocs.io/en/stable/getting_started/installation.html. Once Snakemake has been installed in an isolated conda environment, you can use it and install the other pipeline dependencies after activating it:

conda activate <your_snakemake_environment>

But you can also install it using pip:

pip install snakemake

Note: this uses Python 3.6 or more recent.


### Other dependencies

Each module to run as part of the pipeline can be seen as a dependency of this pipeline. Then each module may come with it's own dependencies (if installed with Conda or Pip) or, on some cases, module-level dependencies will have to be installed manually. 
We will do our best to keep the following list as up to date as possible. Please comment on this documentation or contact bbp-ou-dke@epfl.ch to raise an issue.

bba-datafetch
combination combine_markers
atlas-building-tools cell-detection extract_color_map
atlas-building-tools cell-detection svg_to_png
atlas-building-tools cell-detection compute_average_soma_radius
atlas-building-tools cell-densities cell_density
atlas-building-tools cell-densities glia_cell_densities
atlas-building-tools cell-densities inhibitory_neuron_densities
atlas-building-tools cell_positions
atlas-building-tools combination combine-annotations
atlas-building-tools direction-vectors isocortex
atlas-building-tools direction-vectors cerebellum
atlas-building-tools region-splitter split-isocortex-layer-23
orientation-field
atlas-building-tools placement-hints isocortex
parcellation2mesh


## Configuration

The configuration of the pipeline is written in the file 'config.yaml'.
Before running the pipeline, make sure you modify:

- WORKING_DIR with a directory of your choice (will contain all the files, temporary or not).

- NEXUS_TOKEN_FILE with a local text file of yours that contains the token (use the 'copy token' button from Nexus Web).

- Optionally NEXUS_IDS_FILE if the @ids have changed or if you are using a different Nexus environment.

- Optionally FORGE_CONFIG corresponding to the forge configuration file (yaml) located within the module bba-data-push directory. The default path value assumes that the bba-data-push module folder is in the same directory as the blue_brain_atlas_pipeline folder.

- Optionally RESOLUTION if the input volumetric files of the pipeline are in another resolution other than the default one (25 μm).

- Optionally MODULES_VERBOSE (True/False, default : False) if you want to enable supplementary verbosity to be displayed during the run.

- Optionally DISPLAY_HELP (True/False, default : False) if you want to display in your console every rules from the snakefile with their descriptions.

- The generated data destination aka the Nexus environment NEXUS_DESTINATION_ENV, organisation NEXUS_DESTINATION_ORG and project NEXUS_DESTINATION_PROJ where your datasets will be eventually push into. You can find more details on the generated datasets on the page Pipeline Products as well as informations on the module dedicated to push data into Nexus on the page bba-data-push.

If you do not want to modify the config file, you can still overload the config settings when running the pipeline in command line using the --config flag:

snakemake --config RESOLUTION="10" --forcerun <some_rule>


## Launch the pipeline

In a terminal, first cd the workflow folder:

cd blue_brain_atlas_pipeline

Then, based on whether the whole pipeline or just a subpart of it needs to be launched, it can be handy to have the list of the tasks available:

- fetch_ccf_brain_region_hierarchy, using bba-datafetch CLI
- fetch_brain_parcellation_ccfv2, using bba-datafetch CLI
- fetch_fiber_parcellation_ccfv2, using bba-datafetch CLI
- fetch_brain_parcellation_ccfv3, using bba-datafetch CLI
- fetch_nissl_stained_volume, using bba-datafetch CLI
- fetch_annotation_stack_ccfv2_coronal, using bba-datafetch CLI
- fetch_nissl_stack_ccfv2_coronal, using bba-datafetch CLI
- combine_annotations, using atlas-building-tools combination combine-annotations CLI
- fetch_gene_tmem119, using bba-datafetch CLI
- fetch_gene_s100b, using bba-datafetch CLI
- fetch_gene_aldh1l1, using bba-datafetch CLI
- fetch_gene_gfap, using bba-datafetch CLI
- fetch_gene_cnp, using bba-datafetch CLI
- fetch_gene_mbp, using bba-datafetch CLI
- fetch_gene_gad, using bba-datafetch CLI
- fetch_gene_nrn1, using bba-datafetch CLI
- combine_markers, using atlas-building-tools combination combine-markers CLI
- extract_color_map, using atlas-building-tools cell-detection extract-color-map CLI
- svg_to_png, using atlas-building-tools cell-detection svg-to-png CLI
- compute_average_soma_radius, using atlas-building-tools cell-detection compute-average- soma-radius CLI   (warning)*
- cell_density, using atlas-building-tools cell-densities cell-density CLI
- glia_cell_densities, using atlas-building-tools glia-cell-densities CLI
- inhibitory_excitatory_neuron_densities, using atlas-building-tools cell-densities -- inhibitory-neuron-densities CLI
- cell_positions, using atlas-building-tools cell-densities cell-positions CLI
- direction_vector_isocortex, using atlas-building-tools direction-vectors isocortex CLI
- direction_vector_cerebellum, using atlas-building-tools direction-vectors cerebellum CLI
- orientation_field, using atlas-building-tools orientation-field CLI
- split_isocortex_layer_23, using atlas-building-tools region-splitter split-isocortex -- layer-23 CLI
- placement_hints_isocortex, using atlas-building-tools placement-hints isocortex CLI
- brain_region_meshes_generator, using parcellation2mesh CLI

(warning)*: This module takes a considerable amount of time and memory to be run.

Note: the pipeline framework (Snakemake) resolves the data dependencies and automatically schedules the tasks to be launched when data are missing. Hence, there is no need to launch all the tasks manually, only the target one.
Then to launch the pipeline up to a certain task:

snakemake --forcerun <some_rule>

where <some_rule> is the actual name of a rule, such as combine_annotations.

Note: Snakemake may ask you to specify the maximum number of CPU cores to use during the run.  
If this occurs, add the configuration argument  --cores <number_of_cores>  before  --forcerun <some_rule>.


### Useful Snakemake command line arguments

Snakemake being a command-line tool, it comes with a multitude of optional arguments to execute, debug, and visualize workflows. Here is a selection of the most used :

- snakemake --dry-run, -n → To conduct a dry run (execute nothing but print a summary of jobs that would be done).

- snakemake --forcerun <some_rule> → Force a given rule to be re-executed  (overwrite the already created output.)

- snakemake --list, -l → Print a list of all the available rules from the snakefile.

- snakemake <some_rule> --dag | dot -Tpdf > <name_of_your_DAG>.pdf → Save in a pdf file the directed acyclic graph (DAG) of jobs representing your workflow in the dot language. Several DAG of the atlas pipeline workflow are shown here.

Every Snakemake CL arguments are listed and described in the Snakemake official documentation page.
