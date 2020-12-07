import os
import subprocess
import shutil
import json
import yaml
import re

# loading the config
configfile: "config.yaml"

# placing the config values into local variable
WORKING_DIR = config["WORKING_DIR"]
NEXUS_ENV = config["NEXUS_ENV"]
NEXUS_ORG = config["NEXUS_ORG"]
NEXUS_PROJ = config["NEXUS_PROJ"]
NEXUS_TOKEN_FILE = config["NEXUS_TOKEN_FILE"]
NEXUS_IDS_FILE = config["NEXUS_IDS_FILE"]
RULES_CONFIG_DIR_TEMPLATES = config["RULES_CONFIG_DIR_TEMPLATES"]
RESOLUTION = str(config["RESOLUTION"])
LOG_FILE = os.path.join(WORKING_DIR, "log.log")
VERSION_FILE = os.path.join(WORKING_DIR, "versions.txt")

# All the apps must be listed here so that we can fetch all the versions
APPS = {
    "bba-datafetch": "bba-datafetch",
    "parcellation2mesh": "parcellation2mesh",
    "atlas-building-tools combination combine-annotations": "atlas-building-tools combination combine-annotations",
    "atlas-building-tools combination combine-markers": "atlas-building-tools combination combine-markers",
    "atlas-building-tools cell-detection svg-to-png": "atlas-building-tools cell-detection svg-to-png",
    "atlas-building-tools cell-detection extract-color-map": "atlas-building-tools cell-detection extract-color-map",
    "atlas-building-tools cell-detection compute-average-soma-radius": "atlas-building-tools cell-detection compute-average-soma-radius",
    "atlas-building-tools cell-densities cell-density": "atlas-building-tools cell-densities cell-density",
    "atlas-building-tools cell-densities glia-cell-densities": "atlas-building-tools cell-densities glia-cell-densities",
    "atlas-building-tools cell-densities inhibitory-neuron-densities": "atlas-building-tools cell-densities inhibitory-neuron-densities",
    "atlas-building-tools cell-positions": "atlas-building-tools cell-positions",
    "atlas-building-tools direction-vectors isocortex": "atlas-building-tools direction-vectors isocortex",
    "atlas-building-tools direction-vectors cerebellum": "atlas-building-tools direction-vectors cerebellum",
    "atlas-building-tools orientation-field": "atlas-building-tools orientation-field",
    "atlas-building-tools region-splitter split-isocortex-layer-23": "atlas-building-tools region-splitter split-isocortex-layer-23",
    "atlas-building-tools placement-hints isocortex": "atlas-building-tools placement-hints isocortex",
}

# delete the log of app versions
try:
    os.remove(VERSION_FILE)
except OSError:
    pass

# fetch version of each app and write it down in a file
version_file = open(VERSION_FILE,"a")
for app in APPS:

    app_name_fixed = app.split()[0]

    print(app, " [executable at] ", shutil.which(app_name_fixed))
    
    # first, we need to check if each CLI is in PATH, if not we abort with exit code 1
    if shutil.which(app_name_fixed) is None:
        raise Exception("The CLI {} is not installed or not in PATH. Pipeline cannot execute.".format(app_name_fixed))
        exit(1)

    app_version = subprocess.check_output("{} --version".format(app_name_fixed), shell=True).decode('ascii').rstrip("\n\r")
    version_file.write(f"{app} - {app_version}")
    version_file.write("\n")
version_file.close()

# Reading some Nexus file @id mapping
NEXUS_IDS = json.loads(open(NEXUS_IDS_FILE, 'r').read().strip())

# Create the rules configuration files from the template configuration files and annotate the data paths they contains
rule_config_dir = f"{WORKING_DIR}/rule_config_dir"
try:
    os.mkdir(rule_config_dir)
    combine_markers_config_file_template = open(f"{RULES_CONFIG_DIR_TEMPLATES}/combine_markers_config_template.yaml", "r")
    combine_markers_config_file = open(f"{rule_config_dir}/combine_markers_config.yaml", "w+")
    combine_markers_config_file.write(re.sub("{WORKING_DIR}", WORKING_DIR, combine_markers_config_file_template.read()))
    combine_markers_config_file_template.close()
    combine_markers_config_file.seek(0)
    cell_positions_config_file_template = open(f"{RULES_CONFIG_DIR_TEMPLATES}/cell_positions_config_template.yaml", "r")
    cell_positions_config_file = open(f"{rule_config_dir}/cell_positions_config.yaml", "w+")
    cell_positions_config_file.write(re.sub("{WORKING_DIR}", WORKING_DIR, cell_positions_config_file_template.read()))
    cell_positions_config_file_template.close()
    cell_positions_config_file.seek(0)
except FileExistsError:
    combine_markers_config_file = open(f"{rule_config_dir}/combine_markers_config.yaml", "r")
    cell_positions_config_file = open(f"{rule_config_dir}/cell_positions_config.yaml", "r")
except OSError:
    print(f"Creation of the directory {rule_config_dir} failed")

COMBINE_MARKERS_CONFIG_FILE = yaml.safe_load(combine_markers_config_file.read().strip())
CELL_POSITIONS_CONFIG_FILE = yaml.safe_load(cell_positions_config_file.read().strip())

# fetch the hierarchy file, originally called 1.json
rule fetch_ccf_brain_region_hierarchy:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{WORKING_DIR}/hierarchy.json"
    params:
        nexus_id=NEXUS_IDS["brain_region_hierarchies"]["allen_mouse_ccf"],
        app=APPS["bba-datafetch"]
    log:
        LOG_FILE
    shell:
        """
        {params.app} --nexus-env {NEXUS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org neurosciencegraph \
            --nexus-proj datamodels \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee -a {log}
        """

# fetch the CCF v2 brain parcellation volume in the given resolution
rule fetch_brain_parcellation_ccfv2:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{WORKING_DIR}/brain_parcellation_ccfv2.nrrd"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["parcellations"]["brain_ccfv2"],
        app=APPS["bba-datafetch"]
    log:
        LOG_FILE
    shell:
        """
        {params.app} --nexus-env {NEXUS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ORG} \
            --nexus-proj {NEXUS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee -a {log}
        """


# fetch the CCF v2 fiber parcellation volume in the given resolution
rule fetch_fiber_parcellation_ccfv2:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{WORKING_DIR}/fiber_parcellation_ccfv2.nrrd"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["parcellations"]["fiber_ccfv2"],
        app=APPS["bba-datafetch"]
    log:
        LOG_FILE
    shell:
        """
        {params.app} --nexus-env {NEXUS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ORG} \
            --nexus-proj {NEXUS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee -a {log}
        """

# fetch the CCF v3 brain parcellation volume in the given resolution
rule fetch_brain_parcellation_ccfv3:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{WORKING_DIR}/brain_parcellation_ccfv3.nrrd"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["parcellations"]["brain_ccfv3"],
        app=APPS["bba-datafetch"]
    log:
        LOG_FILE
    shell:
        """
        {params.app} --nexus-env {NEXUS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ORG} \
            --nexus-proj {NEXUS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee -a {log}
        """

# fetch the CCF nissl stained volume in the given resolution
rule fetch_nissl_stained_volume:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{WORKING_DIR}/nissl_stained_volume.nrrd"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["parcellations"]["ara_nissl"],
        app=APPS["bba-datafetch"]
    log:
        LOG_FILE
    shell:
        """
        {params.app} --nexus-env {NEXUS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ORG} \
            --nexus-proj {NEXUS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee -a {log}
        """

# fetch the CCFv2 annotation coronal image stack stack
rule fetch_annotation_stack_ccfv2_coronal:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        directory(f"{WORKING_DIR}/annotation_stack_ccfv2_coronal")
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["image_stack"]["annotation_stack_ccfv2_coronal"],
        app=APPS["bba-datafetch"]
    log:
        LOG_FILE
    shell:
        """
        {params.app} --nexus-env {NEXUS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ORG} \
            --nexus-proj {NEXUS_PROJ} \
            --out {output}.tar.gz \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee -a {log}
            mkdir {output} 
            tar xf {WORKING_DIR}/annotation_stack_ccfv2_coronal.tar.gz --directory={output} --strip-components=1
            rm {WORKING_DIR}/annotation_stack_ccfv2_coronal.tar.gz
        """

# fetch the CCFv2 nissl coronal image stack stack
rule fetch_nissl_stack_ccfv2_coronal:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        directory(f"{WORKING_DIR}/nissl_stack_ccfv2_coronal")
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["image_stack"]["nissl_stack_ccfv2_coronal"],
        app=APPS["bba-datafetch"]
    log:
        LOG_FILE
    shell:
        """
        {params.app} --nexus-env {NEXUS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ORG} \
            --nexus-proj {NEXUS_PROJ} \
            --out {output}.tar.gz \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee -a {log}
            mkdir {output} 
            tar xf {WORKING_DIR}/nissl_stack_ccfv2_coronal.tar.gz --directory={output} --strip-components=1
            rm {WORKING_DIR}/nissl_stack_ccfv2_coronal.tar.gz
        """

# Generate and save the combined annotation file
rule combine_annotations:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        brain_ccfv2=rules.fetch_brain_parcellation_ccfv2.output,
        fiber_ccfv2=rules.fetch_fiber_parcellation_ccfv2.output,
        brain_ccfv3=rules.fetch_brain_parcellation_ccfv3.output
    output:
        f"{WORKING_DIR}/annotation_hybrid.nrrd"
    params:
        app=APPS["atlas-building-tools combination combine-annotations"]
    shell:
        """
        {params.app} --hierarchy {input.hierarchy} \
            --brain-annotation-ccfv2 {input.brain_ccfv2} \
            --fiber-annotation-ccfv2 {input.fiber_ccfv2} \
            --brain-annotation-ccfv3 {input.brain_ccfv3} \
            --output-path {output}
        """

# fetch the gene expression volume corresponding to the genetic marker gad
rule fetch_gene_gad:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{WORKING_DIR}/gene_gad.nrrd"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["gene_expressions"]["gad"],
        app=APPS["bba-datafetch"]
    log:
        LOG_FILE
    shell:
        """
        {params.app} --nexus-env {NEXUS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ORG} \
            --nexus-proj {NEXUS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee -a {log}
        """

# fetch the gene expression volume corresponding to the genetic marker nrn1
rule fetch_gene_nrn1:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{WORKING_DIR}/gene_nrn1.nrrd"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["gene_expressions"]["nrn1"],
        app=APPS["bba-datafetch"]
    log:
        LOG_FILE
    shell:
        """
        {params.app} --nexus-env {NEXUS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ORG} \
            --nexus-proj {NEXUS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee -a {log}
        """

# fetch the gene expression volume corresponding to the genetic marker aldh1l1
rule fetch_gene_aldh1l1:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{COMBINE_MARKERS_CONFIG_FILE['inputGeneVolumePath']['aldh1l1']}"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["gene_expressions"]["aldh1l1"],
        app=APPS["bba-datafetch"]
    log:
        LOG_FILE
    shell:
        """
        {params.app} --nexus-env {NEXUS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ORG} \
            --nexus-proj {NEXUS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee -a {log}
        """

# fetch the gene expression volume corresponding to the genetic marker cnp
rule fetch_gene_cnp:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{COMBINE_MARKERS_CONFIG_FILE['inputGeneVolumePath']['cnp']}"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["gene_expressions"]["cnp"],
        app=APPS["bba-datafetch"]
    log:
        LOG_FILE
    shell:
        """
        {params.app} --nexus-env {NEXUS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ORG} \
            --nexus-proj {NEXUS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee -a {log}
        """
        
# fetch the gene expression volume corresponding to the genetic marker mbp
rule fetch_gene_mbp:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{COMBINE_MARKERS_CONFIG_FILE['inputGeneVolumePath']['mbp']}"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["gene_expressions"]["mbp"],
        app=APPS["bba-datafetch"]
    log:
        LOG_FILE
    shell:
        """
        {params.app} --nexus-env {NEXUS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ORG} \
            --nexus-proj {NEXUS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee -a {log}
        """

# fetch the gene expression volume corresponding to the genetic marker gfap
rule fetch_gene_gfap:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{COMBINE_MARKERS_CONFIG_FILE['inputGeneVolumePath']['gfap']}"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["gene_expressions"]["gfap"],
        app=APPS["bba-datafetch"]
    log:
        LOG_FILE
    shell:
        """
        {params.app} --nexus-env {NEXUS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ORG} \
            --nexus-proj {NEXUS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee -a {log}
        """

# fetch the gene expression volume corresponding to the genetic marker s100b
rule fetch_gene_s100b:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{COMBINE_MARKERS_CONFIG_FILE['inputGeneVolumePath']['s100b']}"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["gene_expressions"]["s100b"],
        app=APPS["bba-datafetch"]
    log:
        LOG_FILE
    shell:
        """
        {params.app} --nexus-env {NEXUS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ORG} \
            --nexus-proj {NEXUS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee -a {log}
        """

# fetch the gene expression volume corresponding to the genetic marker tmem119
rule fetch_gene_tmem119:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{COMBINE_MARKERS_CONFIG_FILE['inputGeneVolumePath']['tmem119']}"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["gene_expressions"]["tmem119"],
        app=APPS["bba-datafetch"]
    log:
        LOG_FILE
    shell:
        """
        {params.app} --nexus-env {NEXUS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ORG} \
            --nexus-proj {NEXUS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee -a {log}
        """

# Generate and save the combined glia files and the global celltype scaling factors
rule combine_markers:
    input:
        aldh1l1 = rules.fetch_gene_aldh1l1.output,
        cnp = rules.fetch_gene_cnp.output,
        mbp = rules.fetch_gene_mbp.output,
        gfap = rules.fetch_gene_gfap.output,
        s100b = rules.fetch_gene_s100b.output,
        tmem119 = rules.fetch_gene_tmem119.output,
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.combine_annotations.output,
        markers_config_file = f"{rule_config_dir}/combine_markers_config.yaml"
    output:
        oligodendrocyte_volume = f"{COMBINE_MARKERS_CONFIG_FILE['outputCellTypeVolumePath']['oligodendrocyte']}",
        astrocyte_volume = f"{COMBINE_MARKERS_CONFIG_FILE['outputCellTypeVolumePath']['astrocyte']}",
        microglia_volume = f"{COMBINE_MARKERS_CONFIG_FILE['outputCellTypeVolumePath']['microglia']}",
        glia_volume = f"{COMBINE_MARKERS_CONFIG_FILE['outputOverallGliaVolumePath']}",
        cell_proportion = f"{COMBINE_MARKERS_CONFIG_FILE['outputCellTypeProportionsPath']}"
    params:
        app=APPS["atlas-building-tools combination combine-markers"]
    shell:
        """
        {params.app} --hierarchy {input.hierarchy} \
            --brain-annotation {input.parcellation_volume} \
            --config {input.markers_config_file} \
        """

# Extract the mapping of colors to structure ids
rule extract_color_map:
    input:
        svg_dir = rules.fetch_annotation_stack_ccfv2_coronal.output,
    output:
        f"{WORKING_DIR}/color_map.json"
    params:
        app=APPS["atlas-building-tools cell-detection extract-color-map"]
    shell:
        """
        {params.app} --input-dir {input.svg_dir} \
            --output-path {output}
        """

# Convert svg files into png files
rule svg_to_png:
    input:
        svg_dir = rules.fetch_annotation_stack_ccfv2_coronal.output,
        nissl_dir = rules.fetch_nissl_stack_ccfv2_coronal.output # In order to put png and nissl jpg in the same folder
        #remove_strokes
    output:
        directory(f"{WORKING_DIR}/images_nissl_annotation_stack_ccfv2_coronal")
    params:
        app=APPS["atlas-building-tools cell-detection svg-to-png"]
    shell:
        """
        {params.app} --input-dir {input.svg_dir} \
            --output-dir {output}
            cp -a {input.nissl_dir}/*.jpg {output}
        """

# Compute the overall mouse brain cell density
rule compute_average_soma_radius:
    input:
        images_dir = rules.svg_to_png.output,
        color_map_json = rules.extract_color_map.output
    output:
        f"{WORKING_DIR}/soma_radius_dict.json"
    params:
        app=APPS["atlas-building-tools cell-detection compute-average-soma-radius"]
    shell:
        """
        {params.app} --input-dir {input.images_dir} \
            --color-map-path {input.color_map_json} \
            --output-path {output} \
        """

# Compute the overall mouse brain cell density
rule cell_density:
    input:
        hierarchy = rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume = rules.combine_annotations.output,
        nissl_volume = rules.fetch_nissl_stained_volume.output
    output:
        f"{WORKING_DIR}/cell_density.nrrd"
    params:
        app=APPS["atlas-building-tools cell-densities cell-density"]
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --hierarchy-path {input.hierarchy} \
            --nissl-path {input.nissl_volume} \
            --output-path {output}
        """
        
# Compute and save the glia cell densities
rule glia_cell_densities:
    input:
        hierarchy = rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume = rules.combine_annotations.output,
        overall_cell_density = rules.cell_density.output,
        glia_density = rules.combine_markers.output.glia_volume,
        astro_density = rules.combine_markers.output.astrocyte_volume,
        oligo_density = rules.combine_markers.output.oligodendrocyte_volume,
        microglia_density = rules.combine_markers.output.microglia_volume,
        glia_proportion = rules.combine_markers.output.cell_proportion
    output:
        cell_densities = directory(f"{WORKING_DIR}/cell_densities"),
        glia_density = f"{WORKING_DIR}/cell_densities/glia_density.nrrd",
        astrocyte_density = f"{CELL_POSITIONS_CONFIG_FILE['inputDensityVolumePath']['astrocyte']}",
        oligodendrocyte_density = f"{CELL_POSITIONS_CONFIG_FILE['inputDensityVolumePath']['oligodendrocyte']}",
        microglia_density = f"{CELL_POSITIONS_CONFIG_FILE['inputDensityVolumePath']['microglia']}",
        neuron_density = f"{WORKING_DIR}/cell_densities/neuron_density.nrrd"
    params:
        app=APPS["atlas-building-tools cell-densities glia-cell-densities"]
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --hierarchy-path {input.hierarchy} \
            --cell-density-path {input.overall_cell_density} \
            --glia-density-path {input.glia_density} \
            --astrocyte-density-path {input.astro_density} \
            --oligodendrocyte-density-path {input.oligo_density} \
            --microglia-density-path {input.microglia_density} \
            --glia-proportions-path {input.glia_proportion} \
            --output-dir {output.cell_densities}
        """
        
# Compute the inhibitory and excitatory neuron densities
rule inhibitory_excitatory_neuron_densities:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.combine_annotations.output,
        gad1_volume = rules.fetch_gene_gad.output,
        nrn1_volume = rules.fetch_gene_nrn1.output,
        neuron_density = rules.glia_cell_densities.output.neuron_density,
    output:
        neuron_densities = directory(f"{WORKING_DIR}/neuron_densities"),
        inhibitory_neuron_density = f"{CELL_POSITIONS_CONFIG_FILE['inputDensityVolumePath']['inhibitory_neuron']}",
        excitatory_neuron_density = f"{CELL_POSITIONS_CONFIG_FILE['inputDensityVolumePath']['excitatory_neuron']}",
    params:
        app=APPS["atlas-building-tools cell-densities inhibitory-neuron-densities"]
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --hierarchy-path {input.hierarchy} \
            --gad1-path {input.gad1_volume} \
            --nrn1-path {input.nrn1_volume} \
            --neuron-density-path {input.neuron_density} \
            --output-dir {output.neuron_densities}
        """

# Generate 3D cell positions for the whole mouse brain
rule cell_positions:
    input:
        parcellation_volume=rules.combine_annotations.output,
        glia_densities = rules.glia_cell_densities.output,
        neuron_densities = rules.inhibitory_excitatory_neuron_densities.output,
        cell_densities_config_file = f"{rule_config_dir}/cell_positions_config.yaml"
    output:
        f"{WORKING_DIR}/cell_positions.h5"
    params:
        app=APPS["atlas-building-tools cell-positions"]
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --config {input.cell_densities_config_file} \
            --output-path {output}
        """
       
# export a mesh for every brain region available in the parcellation volume
# generated by the rule combine (still in development)
# Note: not only the leaf regions are exported but also the above regions
# that are combinaisons of leaves
rule brain_region_meshes_generator:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.combine_annotations.output
    output:
        directory(f"{WORKING_DIR}/brain_region_meshes")
    params:
        app=APPS["parcellation2mesh"]
    log:
        LOG_FILE
    shell:
        """
        {params.app} --hierarchy {input.hierarchy} \
            --parcellation-volume {input.parcellation_volume} \
            --out-dir {output}
        """

# Compute a volume with 3 elements per voxel that are the direction in 
# Euler angles (x, y, z) of the neurons. This uses Regiodesics under the hood.
# The output is only for the top regions of the isocortex.
rule direction_vector_isocortex:
    input:
        parcellation_volume=rules.combine_annotations.output,
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output
    output:
        f"{WORKING_DIR}/direction_vectors_isocortex.nrrd"
    params:
        app=APPS["atlas-building-tools direction-vectors isocortex"]
    log:
        LOG_FILE
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --hierarchy-path {input.hierarchy} \
            --output-path {output}
        """

# Compute a volume with 3 elements per voxel that are the direction in 
# Euler angles (x, y, z) of the neurons. This uses Regiodesics under the hood.
# The output is only for some regions of the cerebellum.
rule direction_vector_cerebellum:
    input:
        parcellation_volume=rules.fetch_brain_parcellation_ccfv2.output
    output:
        f"{WORKING_DIR}/direction_vectors_cerebellum.nrrd"
    params:
        app=APPS["atlas-building-tools direction-vectors cerebellum"]
    log:
        LOG_FILE
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --output-path {output}
        """  
        
# Turn direction vectors into quaternions interpreted as 3D orientations
rule orientation_field:
    input:
        direction_vectors=rules.direction_vector_isocortex.output,
    output:
        f"{WORKING_DIR}/orientation_field.nrrd"
    params:
        app=APPS["atlas-building-tools orientation-field"]
    shell:
        """
        {params.app} --direction-vectors-path {input.direction_vectors} \
            --output-path {output} \
        """ 
 
# Refine annotations by splitting brain regions 
rule split_isocortex_layer_23:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.combine_annotations.output,
        direction_vectors=rules.direction_vector_isocortex.output
    output:
        hierarchy_l23split=f"{WORKING_DIR}/hierarchy_l23split.json",
        annotation_l23split=f"{WORKING_DIR}/annotation_l23split.nrrd"
    params:
        app=APPS["atlas-building-tools region-splitter split-isocortex-layer-23"]
    shell:
        """
        {params.app} --hierarchy-path {input.hierarchy} \
            --annotation-path {input.parcellation_volume} \
            --direction-vectors-path {input.direction_vectors} \
            --output-hierarchy-path {output.hierarchy_l23split} \
            --output-annotation-path {output.annotation_l23split}
        """
        
# Generate and save the placement hints of different regions of the AIBS mouse brain
rule placement_hints_isocortex:
    input:
        parcellation_volume=rules.combine_annotations.output,
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        direction_vectors=rules.direction_vector_isocortex.output
    output:
        directory(f"{WORKING_DIR}/placement_hints")
    params:
        app=APPS["atlas-building-tools placement-hints isocortex"]
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --hierarchy-path {input.hierarchy} \
            --direction-vectors-path {input.direction_vectors} \
            --output-dir {output}
        """