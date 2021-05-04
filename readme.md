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
combination combine-markers
atlas-building-tools cell-detection extract-color-map
atlas-building-tools cell-detection svg-to-png
atlas-building-tools cell-detection compute-average-soma-radius
atlas-building-tools cell-densities cell-density
atlas-building-tools cell-densities glia-cell-densities
atlas-building-tools cell-densities inhibitory-and-excitatory-neuron-densities
atlas-building-tools combination combine-annotations
atlas-building-tools direction-vectors isocortex
atlas-building-tools direction-vectors cerebellum
atlas-building-tools region-splitter split-isocortex-layer-23
orientation-field
brainbuilder cells positions-and-orientations
atlas-building-tools placement-hints isocortex
parcellation2mesh
bba-data-check nrrd-integrity
bba-data-check meshes-obj-integrity
bba-data-check atlas-sonata-integrity
bba-data-push push-volumetric
bba-data-push push-meshes
bba-data-push push-cellrecords


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

Then to launch the pipeline up to a certain task:

snakemake --forcerun <some_rule>

where <some_rule> is the actual name of a rule, such as combine_annotations (see Rules index)

Note: the pipeline framework (Snakemake) resolves the data dependencies and automatically schedules the tasks to be launched when data are missing. Hence, there is no need to launch all the tasks manually, only the target one.

Note: Snakemake may ask you to specify the maximum number of CPU cores to use during the run.  
If this occurs, add the configuration argument  --cores <number_of_cores>  before  --forcerun <some_rule>.


## Rules index

(warning)*: The module associated to this rule takes a considerable amount of time and memory to be run.



fetch_ccf_brain_region_hierarchy, 
   Input: nexus_token_file.txt
      Module: bba-datafetch
         Output: hierarchy.json
fetch_brain_parcellation_ccfv2,
   Input: nexus_token_file.txt
      Module: bba-datafetch
         Output: brain_parcellation_ccfv2.nrrd
fetch_fiber_parcellation_ccfv2,
   Input: nexus_token_file.txt
      Module: bba-datafetch
         Output: fiber_parcellation_ccfv2.nrrd
fetch_brain_parcellation_ccfv3, 
   Input: nexus_token_file.txt
      Module: bba-datafetch
         Output: brain_parcellation_ccfv3.nrrd
fetch_nissl_stained_volume, 
   Input: nexus_token_file.txt
      Module: bba-datafetch
         Output: nissl_stained_volume.nrrd
fetch_annotation_stack_ccfv2_coronal, 
   Input: nexus_token_file.txt
      Module: bba-datafetch
         Output: directory(annotation_stack_ccfv2_coronal)
fetch_nissl_stack_ccfv2_coronal,
   Input: nexus_token_file.txt
      Module: bba-datafetch
         Output: directory(nissl_stack_ccfv2_coronal)
combine_annotations,
   Input: hierarchy.json, fiber_parcellation_ccfv2.nrrd, fiber_parcellation_ccfv2.nrrd, brain_parcellation_ccfv3.nrrd
      Module: atlas-building-tools combination combine-annotations
         Output: annotation_hybrid.nrrd
fetch_gene_tmem119,
   Input: nexus_token_file.txt
      Module: bba-datafetch
         Output: gene_tmem119.nrrd

fetch_gene_s100b,
   Input: nexus_token_file.txt
      Module: bba-datafetch
         Output: gene_s100b.nrrd
fetch_gene_aldh1l1,
   Input: nexus_token_file.txt
      Module: bba-datafetch
         Output: gene_aldh1l1.nrrd
fetch_gene_gfap,
   Input: nexus_token_file.txt
      Module: bba-datafetch
         Output: gene_gfap.nrrd
fetch_gene_cnp,
   Input: nexus_token_file.txt
      Module: bba-datafetch
         Output: gene_cnp.nrrd
fetch_gene_mbp,
   Input: nexus_token_file.txt
      Module: bba-datafetch
         Output: gene_mbp.nrrd
fetch_gene_gad, 
   Input: nexus_token_file.txt
      Module: bba-datafetch
         Output: gene_gad.nrrd
fetch_gene_nrn1,
   Input: nexus_token_file.txt
      Module: bba-datafetch
         Output: gene_nrn1.nrrd
combine_markers,
Input: hierarchy.json, annotation_hybrid.nrrd, combine_markers_config.yaml, gene_tmem119.nrrd, gene_s100b.nrrd, gene_aldh1l1.nrrd, gene_gfap.nrrd, 
             gene_cnp.nrrd, gene_mbp.nrrd
      Module: atlas-building-tools combination combine-markers
         Output: oligodendrocyte.nrrd, astrocyte.nrrd, microglia.nrrd, glia.nrrd, glia_proportions.json
extract_color_map,
   Input: directory(annotation_stack_ccfv2_coronal)
      Module: atlas-building-tools cell-detection extract-color-map
         Output: color_map.json
svg_to_png,
   Input: directory(annotation_stack_ccfv2_coronal), directory(nissl_stack_ccfv2_coronal)
      Module: atlas-building-tools cell-detection svg-to-png
         Output: directory(images_nissl_annotation_stack_ccfv2_coronal)
compute_average_soma_radius,  (warning)*
   Input: directory(images_nissl_annotation_stack_ccfv2_coronal), directory(annotation_stack_ccfv2_coronal)
      Module: atlas-building-tools cell-detection compute-average-soma-radius
         Output: soma_radius_dict.json
cell_density,
   Input: hierarchy.json, annotation_hybrid.nrrd, nissl_stained_volume.nrrd
      Module: atlas-building-tools cell-densities cell-density
         Output: cell_density.nrrd
glia_cell_densities,
Input: hierarchy.json, annotation_hybrid.nrrd, cell_density.nrrd, oligodendrocyte.nrrd, astrocyte.nrrd, microglia.nrrd, glia.nrrd, glia_proportions.json
      Module: atlas-building-tools glia-cell-densities
         Output: directory(cell_densities), glia_density.nrrd, astrocyte_density.nrrd, oligodendrocyte_density.nrrd, microglia_density.nrrd, neuron_density.nrrd
inhibitory_excitatory_neuron_densities,
   Input: hierarchy.json, annotation_hybrid.nrrd, gene_nrn1.nrrd, gene_gad.nrrd, neuron_density.nrrd
      Module: atlas-building-tools cell-densities inhibitory-and-excitatory-neuron-densities
         Output: directory(neuron_densities), inhibitory_neuron_density.nrrd, excitatory_neuron_density.nrrd
cell_positions,
   Input: hierarchy.json, cell_positions_config.yaml
      Module: atlas-building-tools cell-densities cell-positions
         Output: cell_positions.h5
direction_vector_isocortex,
   Input: hierarchy.json, annotation_hybrid.nrrd,
      Module: atlas-building-tools direction-vectors isocortex
         Output: direction_vectors_isocortex.nrrd
direction_vector_cerebellum,
   Input: annotation_hybrid.nrrd,
      Module: atlas-building-tools direction-vectors cerebellum 
         Output: direction_vectors_cerebellum.nrrd
orientation_field,
   Input: direction_vectors_isocortex.nrrd
      Module: atlas-building-tools orientation-field
         Output: orientation_field.nrrd
split_isocortex_layer_23,
   Input: hierarchy.json, annotation_hybrid.nrrd, 
      Module: atlas-building-tools region-splitter split-isocortex-layer-23
         Output: direction_vectors_isocortex.nrrd
placement_hints_isocortex,
   Input: hierarchy.json, annotation_hybrid.nrrd, direction_vectors_isocortex.nrrd
      Module: atlas-building-tools placement-hints isocortex
         Output: directory(placement_hints)
brain_region_meshes_generator,
   Input: hierarchy.json, annotation_hybrid.nrrd,
      Module: parcellation2mesh
         Output: directory(brain_region_meshes)