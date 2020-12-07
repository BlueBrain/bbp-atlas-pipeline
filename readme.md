First, the blue_brain_atlas_pipeline repository must be cloned.
Then, all the modules must be available in your $PATH, whether they are in production or local development mode.


## Installation

### Scheduler core
The pipeline is orchestrated by SnakeMake and the snakefile in the root folder of this repository. This means SnakeMake must be installed:
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

The configuration of the pipeline is written in the file `config.yaml`. 
Before running the pipeline, make sure you modify:
WORKING_DIR with a directory of your choice (will contain all the files, temporary or not)
NEXUS_TOKEN_FILE with a local text file of yours that contains the token (use the 'copy token' button from Nexus Web)
optionally NEXUS_IDS_FILE if the @ids have changed or if you are using a different Nexus environment
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
