##
##Snakemake - Cell Atlas Pipeline
##
##nabil.alibou@epfl.ch
##jonathan.lurie@epfl.ch
##

import os
import time
import datetime
import subprocess
import shutil
import json
import yaml
import re
import logging
from snakemake.logging import logger as L

# loading the config
configfile: "config.yaml"

# placing the config values into local variable
WORKING_DIR = config["WORKING_DIR"]
NEXUS_TOKEN_FILE = config["NEXUS_TOKEN_FILE"]
NEXUS_IDS_FILE = config["NEXUS_IDS_FILE"]
FORGE_CONFIG = config["FORGE_CONFIG"]
RULES_CONFIG_DIR_TEMPLATES = config["RULES_CONFIG_DIR_TEMPLATES"]
RESOLUTION = str(config["RESOLUTION"])
MODULES_VERBOSE = config["MODULES_VERBOSE"]
DISPLAY_HELP = config["DISPLAY_HELP"]

NEXUS_ATLAS_ENV = config["NEXUS_ATLAS_ENV"]
NEXUS_ATLAS_ORG = config["NEXUS_ATLAS_ORG"]
NEXUS_ATLAS_PROJ = config["NEXUS_ATLAS_PROJ"]

NEXUS_DESTINATION_ENV = config["NEXUS_DESTINATION_ENV"]
NEXUS_DESTINATION_ORG = config["NEXUS_DESTINATION_ORG"]
NEXUS_DESTINATION_PROJ = config["NEXUS_DESTINATION_PROJ"]

VERSION_FILE = os.path.join(WORKING_DIR, "versions.txt")

# Create Logs directory
LOG_DIR = os.path.join(WORKING_DIR, "logs")
snakemake_run_logs = os.path.join(LOG_DIR, "snakemake_run_logs")
if not os.path.exists(LOG_DIR):
    try:
        os.mkdir(LOG_DIR)
        L.info("folder '{LOG_DIR}' created")
        if not os.path.exists(snakemake_run_logs):
            try:
                os.mkdir(snakemake_run_logs)
                L.info("folder '{snakemake_run_logs}' created")
            except OSError:
                L.error(f"creation of the directory {snakemake_run_logs} failed")
    except OSError:
        L.error(f"creation of the directory {LOG_DIR} failed")

# Pipeline logs
logfile = os.path.abspath(
            os.path.join(
                snakemake_run_logs, 
                datetime.datetime.now().isoformat().replace(":", "-")
                + ".log"
            )
          )
logfile_handler = logging.FileHandler(logfile)
L.logger.addHandler(logfile_handler)

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
    "atlas-building-tools cell-densities inhibitory-and-excitatory-neuron-densities": "atlas-building-tools cell-densities inhibitory-and-excitatory-neuron-densities",
    "brainbuilder cells positions-and-orientations": "brainbuilder cells positions-and-orientations",
    "atlas-building-tools direction-vectors isocortex": "atlas-building-tools direction-vectors isocortex",
    "atlas-building-tools direction-vectors cerebellum": "atlas-building-tools direction-vectors cerebellum",
    "atlas-building-tools orientation-field": "atlas-building-tools orientation-field",
    "atlas-building-tools region-splitter split-isocortex-layer-23": "atlas-building-tools region-splitter split-isocortex-layer-23",
    "atlas-building-tools placement-hints isocortex": "atlas-building-tools placement-hints isocortex",
    "bba-data-integrity-check nrrd-integrity": "bba-data-integrity-check nrrd-integrity",
    "bba-data-integrity-check meshes-obj-integrity": "bba-data-integrity-check meshes-obj-integrity",
    "bba-data-integrity-check atlas-sonata-integrity": "bba-data-integrity-check atlas-sonata-integrity",
    "bba-data-push push-volumetric": "bba-data-push push-volumetric",
    "bba-data-push push-meshes": "bba-data-push push-meshes",
    "bba-data-push push-cellrecords": "bba-data-push push-cellrecords"
}

# delete the log of app versions
try:
    os.remove(VERSION_FILE)
except OSError:
    pass

# fetch version of each app and write it down in a file
applications = {"applications": {}}
for app in APPS:

    app_name_fixed = app.split()[0]
    if MODULES_VERBOSE:
        L.info(f"{app} [executable at] {shutil.which(app_name_fixed)}")

    # first, we need to check if each CLI is in PATH, if not we abort with exit code 1
    if shutil.which(app_name_fixed) is None:
        raise Exception(f"The CLI {app_name_fixed} is not installed or not in PATH. Pipeline cannot execute.")
        exit(1)

    app_version = subprocess.check_output(f"{app_name_fixed} --version", shell=True).decode('ascii').rstrip("\n\r")
    applications["applications"].update({app: app_version})

with open(VERSION_FILE, "w") as outfile: 
    outfile.write(json.dumps(applications, indent = 4))

# Reading some Nexus file @id mapping
NEXUS_IDS = json.loads(open(NEXUS_IDS_FILE, 'r').read().strip())

# Create the rules configuration files from the template configuration files and annotate the data paths they contains
rule_config_dir = f"{WORKING_DIR}/rule_config_dir"

if not os.path.exists(rule_config_dir):
    try:
        os.mkdir(rule_config_dir)
        L.info("folder '{rule_config_dir}' created")
    except OSError:
        L.error(f"creation of the directory {rule_config_dir} failed")

try:
    combine_markers_config_file_template = open(f"{RULES_CONFIG_DIR_TEMPLATES}/combine_markers_config_template.yaml", "r")
    combine_markers_config_file = open(f"{rule_config_dir}/combine_markers_config.yaml", "w+")
    combine_markers_config_file.write(re.sub("{WORKING_DIR}", WORKING_DIR, combine_markers_config_file_template.read()))
    combine_markers_config_file_template.close()
    combine_markers_config_file.seek(0)
except FileExistsError:
    combine_markers_config_file = open(f"{rule_config_dir}/combine_markers_config.yaml", "r")
try:  
    cell_positions_config_file_template = open(f"{RULES_CONFIG_DIR_TEMPLATES}/cell_positions_config_template.yaml", "r")
    cell_positions_config_file = open(f"{rule_config_dir}/cell_positions_config.yaml", "w+")
    cell_positions_config_file.write(re.sub("{WORKING_DIR}", WORKING_DIR, cell_positions_config_file_template.read()))
    cell_positions_config_file_template.close()
    cell_positions_config_file.seek(0)
except FileExistsError:
    cell_positions_config_file = open(f"{rule_config_dir}/cell_positions_config.yaml", "r")
try:
    push_dataset_config_file_template = open(f"{RULES_CONFIG_DIR_TEMPLATES}/push_dataset_config_template.yaml", "r")
    push_dataset_config_file = open(f"{rule_config_dir}/push_dataset_config.yaml", "w+")
    push_dataset_config_file.write(re.sub("{WORKING_DIR}", WORKING_DIR, push_dataset_config_file_template.read()))
    push_dataset_config_file_template.close()
    push_dataset_config_file.seek(0)
except FileExistsError:
    push_dataset_config_file = open(f"{rule_config_dir}/push_dataset_config.yaml", "r")

COMBINE_MARKERS_CONFIG_FILE = yaml.safe_load(combine_markers_config_file.read().strip())
CELL_POSITIONS_CONFIG_FILE = yaml.safe_load(cell_positions_config_file.read().strip())
PUSH_DATASET_CONFIG_FILE = yaml.safe_load(push_dataset_config_file.read().strip())

if DISPLAY_HELP:
    try:
        L.info((open("HELP_RULES.txt", "r")).read())
        os._exit(0)
    except OSError as e:
        L.error(f"{e}. Could not open 'HELP_RULES.txt'. Its content can also be access by running the 'help' rule.")


##>help : prints help comments for Snakefile
rule help:
    input: "snakefile"
    output: "HELP_RULES.txt"
    shell:
        """
        sed -n 's/^##//p' {input} \
        | tee {output}
        """

##>fetch_ccf_brain_region_hierarchy : fetch the hierarchy file, originally called 1.json
rule fetch_ccf_brain_region_hierarchy:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{PUSH_DATASET_CONFIG_FILE['HierarchyJson']['hierarchy']}",
    params:
        nexus_id=NEXUS_IDS["brain_region_hierarchies"]["allen_mouse_ccf"],
        app=APPS["bba-datafetch"]
    log:
        f"{LOG_DIR}/fetch_ccf_brain_region_hierarchy.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org neurosciencegraph \
            --nexus-proj datamodels \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --favor name:1.json \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_brain_parcellation_ccfv2 :  fetch the CCF v2 brain parcellation volume in the given resolution
rule fetch_brain_parcellation_ccfv2:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{WORKING_DIR}/brain_parcellation_ccfv2.nrrd"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["parcellations"]["brain_ccfv2"],
        app=APPS["bba-datafetch"]
    log:
        f"{LOG_DIR}/fetch_brain_parcellation_ccfv2.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """              

##>fetch_fiber_parcellation_ccfv2 : fetch the CCF v2 fiber parcellation volume in the given resolution
rule fetch_fiber_parcellation_ccfv2:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{WORKING_DIR}/fiber_parcellation_ccfv2.nrrd"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["parcellations"]["fiber_ccfv2"],
        app=APPS["bba-datafetch"]
    log:
        f"{LOG_DIR}/fetch_fiber_parcellation_ccfv2.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_brain_parcellation_ccfv3 : fetch the CCF v3 brain parcellation volume in the given resolution
rule fetch_brain_parcellation_ccfv3:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{WORKING_DIR}/brain_parcellation_ccfv3.nrrd"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["parcellations"]["brain_ccfv3"],
        app=APPS["bba-datafetch"]
    log:
        f"{LOG_DIR}/fetch_brain_parcellation_ccfv3.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_nissl_stained_volume : fetch the CCF nissl stained volume in the given resolution
rule fetch_nissl_stained_volume:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{WORKING_DIR}/nissl_stained_volume.nrrd"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["parcellations"]["ara_nissl"],
        app=APPS["bba-datafetch"]
    log:
        f"{LOG_DIR}/fetch_nissl_stained_volume.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_annotation_stack_ccfv2_coronal : fetch the CCFv2 annotation coronal image stack stack
rule fetch_annotation_stack_ccfv2_coronal:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        directory(f"{WORKING_DIR}/annotation_stack_ccfv2_coronal")
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["image_stack"]["annotation_stack_ccfv2_coronal"],
        app=APPS["bba-datafetch"]
    log:
        f"{LOG_DIR}/fetch_annotation_stack_ccfv2_coronal.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output}.tar.gz \
            --nexus-id {params.nexus_id} \
            --verbose \
            mkdir {output} \
            tar xf {WORKING_DIR}/annotation_stack_ccfv2_coronal.tar.gz --directory={output} --strip-components=1 \
            rm {WORKING_DIR}/annotation_stack_ccfv2_coronal.tar.gz \
            2>&1 | tee {log}
        """

##>fetch_nissl_stack_ccfv2_coronal : fetch the CCFv2 nissl coronal image stack stack
rule fetch_nissl_stack_ccfv2_coronal:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        directory(f"{WORKING_DIR}/nissl_stack_ccfv2_coronal")
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["image_stack"]["nissl_stack_ccfv2_coronal"],
        app=APPS["bba-datafetch"]
    log:
        f"{LOG_DIR}/fetch_nissl_stack_ccfv2_coronal.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output}.tar.gz \
            --nexus-id {params.nexus_id} \
            --verbose \
            mkdir {output} \
            tar xf {WORKING_DIR}/nissl_stack_ccfv2_coronal.tar.gz --directory={output} --strip-components=1 \
            rm {WORKING_DIR}/nissl_stack_ccfv2_coronal.tar.gz \
            2>&1 | tee {log}
        """

##>combine_annotations : Generate and save the combined annotation file
rule combine_annotations:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        brain_ccfv2=rules.fetch_brain_parcellation_ccfv2.output,
        fiber_ccfv2=rules.fetch_fiber_parcellation_ccfv2.output,
        brain_ccfv3=rules.fetch_brain_parcellation_ccfv3.output
    output:
        f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['annotation_hybrid']}"
    params:
        app=APPS["atlas-building-tools combination combine-annotations"]
    log:
        f"{LOG_DIR}/combine_annotations.log"
    shell:
        """
        {params.app} --hierarchy {input.hierarchy} \
            --brain-annotation-ccfv2 {input.brain_ccfv2} \
            --fiber-annotation-ccfv2 {input.fiber_ccfv2} \
            --brain-annotation-ccfv3 {input.brain_ccfv3} \
            --output-path {output} \
            2>&1 | tee {log}
        """

##>fetch_gene_gad : fetch the gene expression volume corresponding to the genetic marker gad
rule fetch_gene_gad:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{WORKING_DIR}/gene_gad.nrrd"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["gene_expressions"]["gad"],
        app=APPS["bba-datafetch"]
    log:
        f"{LOG_DIR}/fetch_gene_gad.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_gene_nrn1 : fetch the gene expression volume corresponding to the genetic marker nrn1
rule fetch_gene_nrn1:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{WORKING_DIR}/gene_nrn1.nrrd"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["gene_expressions"]["nrn1"],
        app=APPS["bba-datafetch"]
    log:
        f"{LOG_DIR}/fetch_gene_nrn1.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_gene_aldh1l1 : fetch the gene expression volume corresponding to the genetic marker aldh1l1
rule fetch_gene_aldh1l1:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{COMBINE_MARKERS_CONFIG_FILE['inputGeneVolumePath']['aldh1l1']}"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["gene_expressions"]["aldh1l1"],
        app=APPS["bba-datafetch"]
    log:
        f"{LOG_DIR}/fetch_gene_aldh1l1.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_gene_cnp : fetch the gene expression volume corresponding to the genetic marker cnp
rule fetch_gene_cnp:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{COMBINE_MARKERS_CONFIG_FILE['inputGeneVolumePath']['cnp']}"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["gene_expressions"]["cnp"],
        app=APPS["bba-datafetch"]
    log:
        f"{LOG_DIR}/fetch_gene_cnp.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_gene_mbp : fetch the gene expression volume corresponding to the genetic marker mbp
rule fetch_gene_mbp:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{COMBINE_MARKERS_CONFIG_FILE['inputGeneVolumePath']['mbp']}"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["gene_expressions"]["mbp"],
        app=APPS["bba-datafetch"]
    log:
        f"{LOG_DIR}/fetch_gene_mbp.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_gene_gfap : fetch the gene expression volume corresponding to the genetic marker gfap
rule fetch_gene_gfap:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{COMBINE_MARKERS_CONFIG_FILE['inputGeneVolumePath']['gfap']}"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["gene_expressions"]["gfap"],
        app=APPS["bba-datafetch"]
    log:
        f"{LOG_DIR}/fetch_gene_gfap.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_gene_s100b : fetch the gene expression volume corresponding to the genetic marker s100b
rule fetch_gene_s100b:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{COMBINE_MARKERS_CONFIG_FILE['inputGeneVolumePath']['s100b']}"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["gene_expressions"]["s100b"],
        app=APPS["bba-datafetch"]
    log:
        f"{LOG_DIR}/fetch_gene_s100b.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_gene_tmem119 : fetch the gene expression volume corresponding to the genetic marker tmem119
rule fetch_gene_tmem119:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{COMBINE_MARKERS_CONFIG_FILE['inputGeneVolumePath']['tmem119']}"
    params:
        nexus_id=NEXUS_IDS["volumes"][RESOLUTION]["gene_expressions"]["tmem119"],
        app=APPS["bba-datafetch"]
    log:
        f"{LOG_DIR}/fetch_gene_tmem119.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>combine_markers : Generate and save the combined glia files and the global celltype scaling factors
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
    log:
        f"{LOG_DIR}/combine_markers.log"
    shell:
        """
        {params.app} --hierarchy {input.hierarchy} \
            --brain-annotation {input.parcellation_volume} \
            --config {input.markers_config_file} \
            2>&1 | tee {log}
        """

##>extract_color_map : Extract the mapping of colors to structure ids
rule extract_color_map:
    input:
        svg_dir = rules.fetch_annotation_stack_ccfv2_coronal.output,
    output:
        f"{WORKING_DIR}/color_map.json"
    params:
        app=APPS["atlas-building-tools cell-detection extract-color-map"]
    log:
        f"{LOG_DIR}/extract_color_map.log"
    shell:
        """
        {params.app} --input-dir {input.svg_dir} \
            --output-path {output} \
            2>&1 | tee {log}
        """

##>svg_to_png : Convert svg files into png files
rule svg_to_png:
    input:
        svg_dir = rules.fetch_annotation_stack_ccfv2_coronal.output,
        nissl_dir = rules.fetch_nissl_stack_ccfv2_coronal.output # In order to put png and nissl jpg in the same folder
        #you can optionally remove_strokes
    output:
        directory(f"{WORKING_DIR}/images_nissl_annotation_stack_ccfv2_coronal")
    params:
        app=APPS["atlas-building-tools cell-detection svg-to-png"]
    log:
        f"{LOG_DIR}/svg_to_png.log"
    shell:
        """
        {params.app} --input-dir {input.svg_dir} \
            --output-dir {output} \
            cp -a {input.nissl_dir}/*.jpg {output} \
            2>&1 | tee {log}
        """

##>compute_average_soma_radius : Compute the overall mouse brain cell density
rule compute_average_soma_radius:
    input:
        images_dir = rules.svg_to_png.output,
        color_map_json = rules.extract_color_map.output
    output:
        f"{WORKING_DIR}/soma_radius_dict.json"
    params:
        app=APPS["atlas-building-tools cell-detection compute-average-soma-radius"]
    log:
        f"{LOG_DIR}/compute_average_soma_radius.log"
    shell:
        """
        {params.app} --input-dir {input.images_dir} \
            --color-map-path {input.color_map_json} \
            --output-path {output} \
            2>&1 | tee {log}
        """

##>cell_density : Compute the overall mouse brain cell density
rule cell_density:
    input:
        hierarchy = rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume = rules.combine_annotations.output,
        nissl_volume = rules.fetch_nissl_stained_volume.output
    output:
        f"{WORKING_DIR}/cell_density.nrrd"
    params:
        app=APPS["atlas-building-tools cell-densities cell-density"]
    log:
        f"{LOG_DIR}/cell_density.log"
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --hierarchy-path {input.hierarchy} \
            --nissl-path {input.nissl_volume} \
            --output-path {output} \
            2>&1 | tee {log}
        """

##>glia_cell_densities : Compute and save the glia cell densities
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
        cell_densities = directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['cell_densities']}"),
        glia_density = f"{WORKING_DIR}/cell_densities/glia_density.nrrd",
        astrocyte_density = f"{CELL_POSITIONS_CONFIG_FILE['inputDensityVolumePath']['astrocyte']}",
        oligodendrocyte_density = f"{CELL_POSITIONS_CONFIG_FILE['inputDensityVolumePath']['oligodendrocyte']}",
        microglia_density = f"{CELL_POSITIONS_CONFIG_FILE['inputDensityVolumePath']['microglia']}",
        neuron_density = f"{WORKING_DIR}/cell_densities/neuron_density.nrrd"
    params:
        app=APPS["atlas-building-tools cell-densities glia-cell-densities"]
    log:
        f"{LOG_DIR}/glia_cell_densities.log"
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
            --output-dir {output.cell_densities} \
            2>&1 | tee {log}
        """

##>inhibitory_excitatory_neuron_densities : Compute the inhibitory and excitatory neuron densities
rule inhibitory_excitatory_neuron_densities:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.combine_annotations.output,
        gad1_volume = rules.fetch_gene_gad.output,
        nrn1_volume = rules.fetch_gene_nrn1.output,
        neuron_density = rules.glia_cell_densities.output.neuron_density,
    output:
        neuron_densities = directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['neuron_densities']}"),
        inhibitory_neuron_density = f"{CELL_POSITIONS_CONFIG_FILE['inputDensityVolumePath']['inhibitory_neuron']}",
        excitatory_neuron_density = f"{CELL_POSITIONS_CONFIG_FILE['inputDensityVolumePath']['excitatory_neuron']}",
    params:
        app=APPS["atlas-building-tools cell-densities inhibitory-and-excitatory-neuron-densities"]
    log:
        f"{LOG_DIR}/inhibitory_excitatory_neuron_densities.log"
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --hierarchy-path {input.hierarchy} \
            --gad1-path {input.gad1_volume} \
            --nrn1-path {input.nrn1_volume} \
            --neuron-density-path {input.neuron_density} \
            --output-dir {output.neuron_densities} \
            2>&1 | tee {log}
        """

##>direction_vector_isocortex : Compute a volume with 3 elements per voxel that are the direction in Euler angles (x, y, z) of the neurons. This uses Regiodesics under the hood. The output is only for the top regions of the isocortex.
rule direction_vector_isocortex:
    input:
        parcellation_volume=rules.combine_annotations.output,
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output
    output:
        f"{WORKING_DIR}/direction_vectors_isocortex.nrrd"
    params:
        app=APPS["atlas-building-tools direction-vectors isocortex"]
    log:
        f"{LOG_DIR}/direction_vector_isocortex.log"
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --hierarchy-path {input.hierarchy} \
            --output-path {output} \
            2>&1 | tee {log}
        """

##>direction_vector_cerebellum : Compute a volume with 3 elements per voxel that are the direction in Euler angles (x, y, z) of the neurons. This uses Regiodesics under the hood. The output is only for some regions of the cerebellum.
rule direction_vector_cerebellum:
    input:
        parcellation_volume=rules.fetch_brain_parcellation_ccfv2.output
    output:
        f"{WORKING_DIR}/direction_vectors_cerebellum.nrrd"
    params:
        app=APPS["atlas-building-tools direction-vectors cerebellum"]
    log:
        f"{LOG_DIR}/direction_vector_cerebellum.log"
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --output-path {output} \
            2>&1 | tee {log}
        """  

##>split_isocortex_layer_23 : Refine annotations by splitting brain regions 
rule split_isocortex_layer_23:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.combine_annotations.output,
        direction_vectors=rules.direction_vector_isocortex.output
    output:
        hierarchy_l23split=f"{PUSH_DATASET_CONFIG_FILE['HierarchyJson']['hierarchy_l23split']}",
        annotation_l23split=f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['annotation_l23split']}"
    params:
        app=APPS["atlas-building-tools region-splitter split-isocortex-layer-23"]
    log:
        f"{LOG_DIR}/split_isocortex_layer_23.log"
    shell:
        """
        {params.app} --hierarchy-path {input.hierarchy} \
            --annotation-path {input.parcellation_volume} \
            --direction-vectors-path {input.direction_vectors} \
            --output-hierarchy-path {output.hierarchy_l23split} \
            --output-annotation-path {output.annotation_l23split} \
            2>&1 | tee {log}
        """

##>brain_region_meshes_hybrid : export a mesh for every brain region available in the hybrid brain parcellation volume. Note: not only the leaf regions are exported but also the above regions that are combinaisons of leaves
rule brain_region_meshes_hybrid:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.combine_annotations.output
    output:
        directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['MeshFile']['brain_region_meshes_hybrid']}")
    params:
        app=APPS["parcellation2mesh"]
    log:
        f"{LOG_DIR}/brain_region_meshes_hybrid.log"
    shell:
        """
        {params.app} --hierarchy {input.hierarchy} \
            --parcellation-volume {input.parcellation_volume} \
            --out-dir {output} \
            2>&1 | tee {log}
        """

##>brain_region_meshes_l23split : export a mesh for every brain region available in the hybrid brain parcellation volume with layer 2-3 split. Note: not only the leaf regions are exported but also the above regions that are combinaisons of leaves
rule brain_region_meshes_l23split:
    input:
        hierarchy=rules.split_isocortex_layer_23.output.hierarchy_l23split,
        parcellation_volume=rules.split_isocortex_layer_23.output.annotation_l23split
    output:
        directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['MeshFile']['brain_region_meshes_l23split']}")
    params:
        app=APPS["parcellation2mesh"]
    log:
        f"{LOG_DIR}/brain_region_meshes_l23split.log"
    shell:
        """
        {params.app} --hierarchy {input.hierarchy} \
            --parcellation-volume {input.parcellation_volume} \
            --out-dir {output} \
            2>&1 | tee {log}
        """

##>orientation_field : Turn direction vectors into quaternions interpreted as 3D orientations
rule orientation_field:
    input:
        direction_vectors=rules.direction_vector_isocortex.output,
    output:
        f"{WORKING_DIR}/orientation_field.nrrd"
    params:
        app=APPS["atlas-building-tools orientation-field"]
    log:
        f"{LOG_DIR}/orientation_field.log"
    shell:
        """
        {params.app} --direction-vectors-path {input.direction_vectors} \
            --output-path {output} \
            2>&1 | tee {log}
        """ 

##>cell_records : Generate 3D cell records for the whole mouse brain and save them with the orientations and the region_ID in an hdf5 file
rule cell_records:
    input:
        parcellation_volume = rules.combine_annotations.output,
        orientation_file = rules.orientation_field.output,
        glia_densities = rules.glia_cell_densities.output,
        neuron_densities = rules.inhibitory_excitatory_neuron_densities.output,
        cell_densities_config_file = f"{rule_config_dir}/cell_positions_config.yaml"
    output:
        f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['CellRecordsFile']['cell_records_sonata']}"
    params:
        app=APPS["brainbuilder cells positions-and-orientations"]
    log:
        f"{LOG_DIR}/cell_records.log"
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --orientation-path {input.orientation_file} \
            --config-path {input.cell_densities_config_file} \
            --output-path {output} \
            2>&1 | tee {log}
        """

##>placement_hints_isocortex : Generate and save the placement hints of different regions of the AIBS mouse brain
rule placement_hints_isocortex:
    input:
        parcellation_volume=rules.combine_annotations.output,
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        direction_vectors=rules.direction_vector_isocortex.output
    output:
        directory(f"{WORKING_DIR}/placement_hints")
    params:
        app=APPS["atlas-building-tools placement-hints isocortex"]
    log:
        f"{LOG_DIR}/placement_hints_isocortex.log"
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --hierarchy-path {input.hierarchy} \
            --direction-vectors-path {input.direction_vectors} \
            --output-dir {output} \
            2>&1 | tee {log}
        """


##========================== Check Rules ==========================


##>check_hybrid_v2v3_annotation : Check the integrity of the generated annotation hybrid .nrrd volumetric dataset
rule check_hybrid_v2v3_annotation:
    input:
        annotation_hybrid=rules.combine_annotations.output,
    output:
        f"{WORKING_DIR}/data_check_report/report_volumetric_nrrd.json"
    params:
        app=APPS["bba-data-integrity-check nrrd-integrity"]
    log:
        f"{LOG_DIR}/check_hybrid_v2v3_annotation.log"
    shell:
        """
        {params.app} --input_dataset {input.annotation_hybrid} \
            --report_path {output} \
            2>&1 | tee {log}
        """

##>check_l23split_annotation : Check the integrity of the generated annotation with layer23 split .nrrd volumetric dataset
rule check_l23split_annotation:
    input:
        annotation_l23split=rules.split_isocortex_layer_23.output.annotation_l23split
    output:
        f"{WORKING_DIR}/data_check_report/report_volumetric_nrrd.json"
    params:
        app=APPS["bba-data-integrity-check nrrd-integrity"]
    log:
        f"{LOG_DIR}/check_l23split_annotation.log"
    shell:
        """
        {params.app} --input_dataset {input.annotation_l23split} \
            --report_path {output} \
            2>&1 | tee {log}
        """

##>check_hybrid_v2v3_nrrd_dataset : Check the integrity of the generated cell densities folder containing .nrrd volumetric dataset
rule check_cell_densities:
    input:
        cell_densities=rules.glia_cell_densities.output.cell_densities,
    output:
        f"{WORKING_DIR}/data_check_report/report_volumetric_nrrd.json"
    params:
        app=APPS["bba-data-integrity-check nrrd-integrity"]
    log:
        f"{LOG_DIR}/check_cell_densities.log"
    shell:
        """
        {params.app} --input_dataset {input.cell_densities} \
            --report_path {output} \
            2>&1 | tee {log}
        """

##>check_neuron_densities : Check the integrity of the generated neuron densities folder containing .nrrd volumetric dataset
rule check_neuron_densities:
    input:
        neuron_densities=rules.inhibitory_excitatory_neuron_densities.output.neuron_densities
    output:
        f"{WORKING_DIR}/data_check_report/report_volumetric_nrrd.json"
    params:
        app=APPS["bba-data-integrity-check nrrd-integrity"]
    log:
        f"{LOG_DIR}/check_neuron_densities.log"
    shell:
        """
        {params.app} --input_dataset {input.neuron_densities} \
            --report_path {output} \
            2>&1 | tee {log}
        """

##>check_hybrid_v2v3_volumetric_nrrd_datasets : Check the integrity of the hybrid .nrrd volumetric datasets that can be generated by the pipeline
rule check_hybrid_v2v3_volumetric_nrrd_datasets:
    input:
        annotation_hybrid=rules.combine_annotations.output,
        cell_densities=rules.glia_cell_densities.output.cell_densities,
        neuron_densities=rules.inhibitory_excitatory_neuron_densities.output.neuron_densities
    output:
        f"{WORKING_DIR}/data_check_report/report_volumetric_nrrd.json"
    params:
        app=APPS["bba-data-integrity-check nrrd-integrity"]
    log:
        f"{LOG_DIR}/check_hybrid_v2v3_volumetric_nrrd_datasets.log"
    shell:
        """
        {params.app} --input_dataset {input.annotation_hybrid} \
            --input_dataset {input.annotation_l23split} \
            --input_dataset {input.cell_densities} \
            --input_dataset {input.neuron_densities} \
            --report_path {output} \
            2>&1 | tee {log}
        """

##>check_l23split_volumetric_nrrd_datasets : Check the integrity of the hybrid with layer 2,3 split .nrrd volumetric datasets that can be generated by the pipeline
rule check_l23split_volumetric_nrrd_datasets:
    input:
        annotation_l23split=rules.split_isocortex_layer_23.output.annotation_l23split,
        cell_densities=rules.glia_cell_densities.output.cell_densities,
        neuron_densities=rules.inhibitory_excitatory_neuron_densities.output.neuron_densities
    output:
        f"{WORKING_DIR}/data_check_report/report_volumetric_nrrd.json"
    params:
        app=APPS["bba-data-integrity-check nrrd-integrity"]
    log:
        f"{LOG_DIR}/check_l23split_volumetric_nrrd_datasets.log"
    shell:
        """
        {params.app}  --input_dataset {input.annotation_l23split} \
            --input_dataset {input.cell_densities} \
            --input_dataset {input.neuron_densities} \
            --report_path {output} \
            2>&1 | tee {log}
        """

##>check_all_volumetric_nrrd_datasets : Check the integrity of every .nrrd volumetric datasets that can be generated by the pipeline
rule check_all_volumetric_nrrd_datasets:
    input:
        annotation_hybrid=rules.combine_annotations.output,
        annotation_l23split=rules.split_isocortex_layer_23.output.annotation_l23split,
        cell_densities=rules.glia_cell_densities.output.cell_densities,
        neuron_densities=rules.inhibitory_excitatory_neuron_densities.output.neuron_densities
    output:
        f"{WORKING_DIR}/data_check_report/report_volumetric_nrrd.json"
    params:
        app=APPS["bba-data-integrity-check nrrd-integrity"]
    log:
        f"{LOG_DIR}/check_all_volumetric_nrrd_datasets.log"
    shell:
        """
        {params.app} --input_dataset {input.annotation_hybrid} \
            --input_dataset {input.annotation_l23split} \
            --input_dataset {input.cell_densities} \
            --input_dataset {input.neuron_densities} \
            --report_path {output} \
            2>&1 | tee {log}
        """

##>check_hybrid_v2v3_meshes_obj : Check the integrity of the generated .obj meshes of the hybrid ccfv2-ccfv3 annotation 
rule check_hybrid_v2v3_meshes_obj:
    input:
        mesh_hybrid=rules.brain_region_meshes_hybrid.output
    output:
        f"{WORKING_DIR}/data_check_report/report_obj_brain_meshes.json"
    params:
        app=APPS["bba-data-integrity-check meshes-obj-integrity"]
    log:
        f"{LOG_DIR}/check_hybrid_v2v3_meshes_obj.log"
    shell:
        """
        {params.app} --input_dataset {input.mesh_hybrid} \
            --report_path {output} \
            2>&1 | tee {log}
        """

##>check_l23split_meshes_obj : Check the integrity of the generated .obj meshes of the hybrid ccfv2-ccfv3 with layer 2,3 split annotation
rule check_l23split_meshes_obj:
    input:
        mesh_l23split=rules.brain_region_meshes_l23split.output
    output:
        f"{WORKING_DIR}/data_check_report/report_obj_brain_meshes.json"
    params:
        app=APPS["bba-data-integrity-check meshes-obj-integrity"]
    log:
        f"{LOG_DIR}/check_l23split_meshes_obj.log"
    shell:
        """
        {params.app} --input_dataset {input.mesh_l23split} \
            --report_path {output} \
            2>&1 | tee {log}
        """

##>check_meshes_obj_dataset : Check the integrity of all the generated .obj meshes datasets that can be generated by the pipeline
rule check_all_meshes_obj_datasets:
    input:
        mesh_hybrid=rules.brain_region_meshes_hybrid.output,
        mesh_l23split=rules.brain_region_meshes_l23split.output
    output:
        f"{WORKING_DIR}/data_check_report/report_obj_brain_meshes.json"
    params:
        app=APPS["bba-data-integrity-check meshes-obj-integrity"]
    log:
        f"{LOG_DIR}/check_all_meshes_obj_datasets.log"
    shell:
        """
        {params.app} --input_dataset {input.mesh_hybrid} \
            --input_dataset {input.mesh_l23split} \
            --report_path {output} \
            2>&1 | tee {log}
        """

##>check_sonata_cellrecords : Check the integrity of the generated sonata .h5 containing the cell records
rule check_sonata_cellrecords:
    input:
        cell_records_file=rules.cell_records.output
    output:
        f"{WORKING_DIR}/data_check_report/report_sonata_cell_records_h5.json"
    params:
        app=APPS["bba-data-integrity-check atlas-sonata-integrity"]
    log:
        f"{LOG_DIR}/check_sonata_cellrecords.log"
    shell:
        """
        {params.app} --input_dataset {input.cell_records_file} \
            --report_path {output} \
            2>&1 | tee {log}
        """

##>check_hybrid_v2v3_report : Verify that the report files generated by the module verifying the hybrid datasets integrity do not contain any issues before starting to push datasets into Nexus. These are contained in the folder data_check_report.
rule check_hybrid_v2v3_report:
    priority: 10
    input:
        nrrd_report = rules.check_hybrid_v2v3_volumetric_nrrd_datasets.output,
        obj_report = rules.check_hybrid_v2v3_meshes_obj.output,
        hdf5_report = rules.check_sonata_cellrecords.output
    output:
        touch(f"{WORKING_DIR}/data_check_report/report_valid.txt")
    log:
        f"{LOG_DIR}/check_hybrid_v2v3_report.log"
    run:
        with open(log[0], "w") as logfile:
            report_files = input
            for f in report_files:
                report_file = open(f,'r')
                report_json = json.load(report_file)
                for k in report_json.keys():
                    if not report_json[k]['success'] == 'true':
                        logfile.write(f"The report file contains errors: \n{report_json}\n "\ 
                                      "All the data_check_report need to show valid dataset or else those "\
                                      "will not be pushed in Nexus.")
                        #raise ValueError
                        L.error(f"The report file contains errors: \n'{report_json}")
                        exit(1)
                report_file.close()
            logfile.write(f"All report files show successful datasets integrity check.\nUpdating '{output}'")


##>check_l23split_report : Verify that the report files generated by the module verifying the l23 split datasets integrity do not contain any issues before starting to push datasets into Nexus. These are contained in the folder data_check_report.
rule check_l23split_report:
    priority: 10
    input:
        nrrd_report = rules.check_l23split_volumetric_nrrd_datasets.output,
        obj_report = rules.check_l23split_meshes_obj.output,
        hdf5_report = rules.check_sonata_cellrecords.output
    output:
        touch(f"{WORKING_DIR}/data_check_report/report_valid.txt")
    log:
        f"{LOG_DIR}/check_l23split_report.log"
    run:
        with open(log[0], "w") as logfile:
            report_files = input
            for f in report_files:
                report_file = open(f,'r')
                report_json = json.load(report_file)
                for k in report_json.keys():
                    if not report_json[k]['success'] == 'true':
                        logfile.write(f"The report file contains errors: \n{report_json}\n "\ 
                                      "All the data_check_report need to show valid dataset or else those "\
                                      "will not be pushed in Nexus.")
                        L.error(f"The report file contains errors: \n'{report_json}")
                        exit(1)
                report_file.close()
            logfile.write(f"All report files show successful datasets integrity check.\nUpdating '{output}'")
            

##>check_alldatasets_report : Verify that the report files generated by the module verifying all the dataset integrity do not contain any issues before starting to push datasets into Nexus. These are contained in the folder data_check_report.
rule check_alldatasets_report:
    priority: 10
    input:
        nrrd_report = rules.check_all_volumetric_nrrd_datasets.output,
        obj_report = rules.check_all_meshes_obj_datasets.output,
        hdf5_report = rules.check_sonata_cellrecords.output
    output:
        touch(f"{WORKING_DIR}/data_check_report/report_valid.txt")
    log:
        f"{LOG_DIR}/check_alldatasets_report.log"
    run:
        with open(log[0], "w") as logfile:
            report_files = input
            for f in report_files:
                report_file = open(f,'r')
                report_json = json.load(report_file)
                for k in report_json.keys():
                    if not report_json[k]['success'] == 'true':
                        logfile.write(f"The report file contains errors: \n{report_json}\n "\ 
                                      "All the data_check_report need to show valid dataset or else those "\
                                      "will not be pushed in Nexus.")
                        L.error(f"The report file contains errors: \n'{report_json}")
                        exit(1)
                report_file.close()
            logfile.write(f"All report files show successful datasets integrity check.\nUpdating '{output}'")


##========================== Push Rules ==========================


##>push_hybrid_v2v3_annotation : Create a VolumetricDataLayer resource payload and push it along with the volumetric file into Nexus
rule push_hybrid_v2v3_annotation:
    input:
        annotation_hybrid=rules.combine_annotations.output,
        check_nrrd = rules.check_hybrid_v2v3_annotation.output
    output:
        touch(f"{WORKING_DIR}/push_hybrid_v2v3_annotation_success.txt")
    params:
        app=APPS["bba-data-push push-volumetric"].split(),
        provenance = f"atlas-building-tools combination combine-annotations:{applications['applications']['atlas-building-tools combination combine-annotations']}"
    log:
        f"{LOG_DIR}/push_hybrid_v2v3_annotation.log"
    shell:
        """
        {params.app[0]} --forge_config_file {FORGE_CONFIG} \
            --nexus_env {NEXUS_DESTINATION_ENV} \
            --nexus_org {NEXUS_DESTINATION_ORG} \
            --nexus_proj {NEXUS_DESTINATION_PROJ} \
            --nexus_token_file {NEXUS_TOKEN_FILE} \
            --verbose \
        {params.app[1]} --dataset_path {input.annotation_hybrid} \
            --provenances "{params.provenance}" \
            --config {rule_config_dir}/push_dataset_config.yaml \
            --voxels_resolution {RESOLUTION} \
            2>&1 | tee {log}
        """
        
##>push_l23split_annotation : Create a VolumetricDataLayer resource payload and push it along with the volumetric file into Nexus
rule push_l23split_annotation:
    input:
        annotation_l23split=rules.split_isocortex_layer_23.output.annotation_l23split,
        check_nrrd = rules.check_l23split_annotation.output
    output:
        touch(f"{WORKING_DIR}/push_l23split_annotation_success.txt")
    params:
        app=APPS["bba-data-push push-volumetric"].split(),
        provenance = f"atlas-building-tools region-splitter split-isocortex-layer-23:{applications['applications']['atlas-building-tools region-splitter split-isocortex-layer-23']}"
    log:
        f"{LOG_DIR}/push_l23split_annotation.log"
    shell:
        """
        {params.app[0]} --forge_config_file {FORGE_CONFIG} \
            --nexus_env {NEXUS_DESTINATION_ENV} \
            --nexus_org {NEXUS_DESTINATION_ORG} \
            --nexus_proj {NEXUS_DESTINATION_PROJ} \
            --nexus_token_file {NEXUS_TOKEN_FILE} \
        {params.app[1]} --dataset_path {input.annotation_l23split} \
            --provenances "{params.provenance}" \
            --config {rule_config_dir}/push_dataset_config.yaml \
            --voxels_resolution {RESOLUTION} \
            2>&1 | tee {log}
        """

##>push_cell_densities : Create a VolumetricDataLayer resource payload and push it along with the volumetric file into Nexus
rule push_cell_densities:
    input:
        cell_densities=rules.combine_annotations.output,
        check_nrrd = rules.check_cell_densities.output
    output:
        touch(f"{WORKING_DIR}/push_cell_densities_success.txt")
    params:
        app=APPS["bba-data-push push-volumetric"].split(),
        provenance = f"atlas-building-tools cell-densities glia-cell-densities:{applications['applications']['atlas-building-tools cell-densities glia-cell-densities']}"
    log:
        f"{LOG_DIR}/push_cell_densities.log"
    shell:
        """
        {params.app[0]} --forge_config_file {FORGE_CONFIG} \
            --nexus_env {NEXUS_DESTINATION_ENV} \
            --nexus_org {NEXUS_DESTINATION_ORG} \
            --nexus_proj {NEXUS_DESTINATION_PROJ} \
            --nexus_token_file {NEXUS_TOKEN_FILE} \
        {params.app[1]} --dataset_path {input.cell_densities} \
            --provenances "{params.provenance}" \
            --config {rule_config_dir}/push_dataset_config.yaml \
            --voxels_resolution {RESOLUTION} \
            2>&1 | tee {log}
        """
        
##>push_neuron_densities : Create a VolumetricDataLayer resource payload and push it along with the volumetric file into Nexus
rule push_neuron_densities:
    input:
        neuron_densities=rules.combine_annotations.output,
        check_nrrd = rules.check_neuron_densities.output
    output:
        touch(f"{WORKING_DIR}/push_neuron_densities_success.txt")
    params:
        app=APPS["bba-data-push push-volumetric"].split(),
        provenance = f"atlas-building-tools cell-densities inhibitory-and-excitatory-neuron-densities:{applications['applications']['atlas-building-tools cell-densities inhibitory-and-excitatory-neuron-densities']}"
    log:
        f"{LOG_DIR}/push_neuron_densities.log"
    shell:
        """
        {params.app[0]} --forge_config_file {FORGE_CONFIG} \
            --nexus_env {NEXUS_DESTINATION_ENV} \
            --nexus_org {NEXUS_DESTINATION_ORG} \
            --nexus_proj {NEXUS_DESTINATION_PROJ} \
            --nexus_token_file {NEXUS_TOKEN_FILE} \
        {params.app[1]} --dataset_path {input.neuron_densities} \
            --provenances "{params.provenance}" \
            --config {rule_config_dir}/push_dataset_config.yaml \
            --voxels_resolution {RESOLUTION} \
            2>&1 | tee {log}
        """

##>push_hybrid_v2v3_volumetric_nrrd_datasets : Create a VolumetricDataLayer resource payload and push it along with the volumetric file into Nexus
rule push_hybrid_v2v3_volumetric_nrrd_datasets:
    input:
        annotation_hybrid=rules.combine_annotations.output,
        cell_densities=rules.glia_cell_densities.output,
        neuron_densities=rules.combine_annotations.output,
        check_nrrd = rules.check_hybrid_v2v3_volumetric_nrrd_datasets.output
    output:
        touch(f"{WORKING_DIR}/push_hybrid_v2v3_volumetric_nrrd_datasets_success.txt")
    params:
        app=APPS["bba-data-push push-volumetric"].split(),
        provenance_hybrid = f"atlas-building-tools combination combine-annotations:{applications['applications']['atlas-building-tools combination combine-annotations']}",
        provenance_cell_densities = f"atlas-building-tools cell-densities glia-cell-densities:{applications['applications']['atlas-building-tools cell-densities glia-cell-densities']}",
        provenance_neuron_densities = f"atlas-building-tools cell-densities inhibitory-and-excitatory-neuron-densities:{applications['applications']['atlas-building-tools cell-densities inhibitory-and-excitatory-neuron-densities']}"
    log:
        f"{LOG_DIR}/push_hybrid_v2v3_volumetric_nrrd_datasets.log"
    shell:
        """
        {params.app[0]} --forge_config_file {FORGE_CONFIG} \
            --nexus_env {NEXUS_DESTINATION_ENV} \
            --nexus_org {NEXUS_DESTINATION_ORG} \
            --nexus_proj {NEXUS_DESTINATION_PROJ} \
            --nexus_token_file {NEXUS_TOKEN_FILE} \
        {params.app[1]} --dataset_path {input.annotation_hybrid} \
            --dataset_path {input.cell_densities} \
            --dataset_path {input.neuron_densities} \
            --provenances "{params.provenance_hybrid}" \
            --provenances "{params.provenance_cell_densities}" \
            --provenances "{params.provenance_neuron_densities}" \
            --config {rule_config_dir}/push_dataset_config.yaml \
            --voxels_resolution {RESOLUTION} \
            2>&1 | tee {log}
        """

##>push_l23split_volumetric_nrrd_datasets : Create a VolumetricDataLayer resource payload and push it along with the volumetric file into Nexus
rule push_l23split_volumetric_nrrd_datasets:
    input:
        annotation_l23split=rules.split_isocortex_layer_23.output.annotation_l23split,
        cell_densities=rules.glia_cell_densities.output,
        neuron_densities=rules.combine_annotations.output,
        check_nrrd = rules.check_l23split_volumetric_nrrd_datasets.output
    output:
        touch(f"{WORKING_DIR}/push_l23split_volumetric_nrrd_datasets_success.txt")
    params:
        app=APPS["bba-data-push push-volumetric"].split(),
        provenance_l23split = f"atlas-building-tools region-splitter split-isocortex-layer-23:{applications['applications']['atlas-building-tools region-splitter split-isocortex-layer-23']}",
        provenance_cell_densities = f"atlas-building-tools cell-densities glia-cell-densities:{applications['applications']['atlas-building-tools cell-densities glia-cell-densities']}",
        provenance_neuron_densities = f"atlas-building-tools cell-densities inhibitory-and-excitatory-neuron-densities:{applications['applications']['atlas-building-tools cell-densities inhibitory-and-excitatory-neuron-densities']}"
    log:
        f"{LOG_DIR}/push_l23split_volumetric_nrrd_datasets.log"
    shell:
        """
        {params.app[0]} --forge_config_file {FORGE_CONFIG} \
            --nexus_env {NEXUS_DESTINATION_ENV} \
            --nexus_org {NEXUS_DESTINATION_ORG} \
            --nexus_proj {NEXUS_DESTINATION_PROJ} \
            --nexus_token_file {NEXUS_TOKEN_FILE} \
        {params.app[1]} --dataset_path {input.annotation_l23split} \
            --dataset_path {input.cell_densities} \
            --dataset_path {input.neuron_densities} \
            --provenances "{params.provenance_l23split}" \
            --provenances "{params.provenance_cell_densities}" \
            --provenances "{params.provenance_neuron_densities}" \
            --config {rule_config_dir}/push_dataset_config.yaml \
            --voxels_resolution {RESOLUTION} \
            2>&1 | tee {log}
        """

##>push_all_volumetric_nrrd_datasets : Create a VolumetricDataLayer resource payload and push it along with the volumetric file into Nexus
rule push_all_volumetric_nrrd_datasets:
    input:
        annotation_hybrid=rules.combine_annotations.output,
        annotation_l23split=rules.split_isocortex_layer_23.output.annotation_l23split,
        cell_densities=rules.glia_cell_densities.output,
        neuron_densities=rules.combine_annotations.output,
        check_nrrd = rules.check_all_volumetric_nrrd_datasets.output
    output:
        touch(f"{WORKING_DIR}/push_all_volumetric_nrrd_datasets_success.txt")
    params:
        app=APPS["bba-data-push push-volumetric"].split(),
        provenance_hybrid = f"atlas-building-tools combination combine-annotations:{applications['applications']['atlas-building-tools combination combine-annotations']}",
        provenance_l23split = f"atlas-building-tools region-splitter split-isocortex-layer-23:{applications['applications']['atlas-building-tools region-splitter split-isocortex-layer-23']}",
        provenance_cell_densities = f"atlas-building-tools cell-densities glia-cell-densities:{applications['applications']['atlas-building-tools cell-densities glia-cell-densities']}",
        provenance_neuron_densities = f"atlas-building-tools cell-densities inhibitory-and-excitatory-neuron-densities:{applications['applications']['atlas-building-tools cell-densities inhibitory-and-excitatory-neuron-densities']}"
    log:
        f"{LOG_DIR}/push_all_volumetric_nrrd_datasets.log"
    shell:
        """
        {params.app[0]} --forge_config_file {FORGE_CONFIG} \
            --nexus_env {NEXUS_DESTINATION_ENV} \
            --nexus_org {NEXUS_DESTINATION_ORG} \
            --nexus_proj {NEXUS_DESTINATION_PROJ} \
            --nexus_token_file {NEXUS_TOKEN_FILE} \
        {params.app[1]} --dataset_path {input.annotation_hybrid} \
            --dataset_path {input.annotation_l23split} \
            --dataset_path {input.cell_densities} \
            --dataset_path {input.neuron_densities} \
            --provenances "{params.provenance_hybrid}" \
            --provenances "{params.provenance_l23split}" \
            --provenances "{params.provenance_cell_densities}" \
            --provenances "{params.provenance_neuron_densities}" \
            --config {rule_config_dir}/push_dataset_config.yaml \
            --voxels_resolution {RESOLUTION} \
            2>&1 | tee {log}
        """

##>push_hybrid_v2v3_meshes_obj : Create a Mesh resource and push it along with the mesh files into Nexus
rule push_hybrid_v2v3_meshes_obj:
    input:
        mesh_hybrid=rules.brain_region_meshes_hybrid.output,
        hierarchy = rules.fetch_ccf_brain_region_hierarchy.output,
        check_obj_meshes = rules.check_hybrid_v2v3_meshes_obj.output
    output:
        temp(touch(f"{WORKING_DIR}/push_hybrid_v2v3_meshes_obj_success.txt"))
    params:
        app=APPS["bba-data-push push-meshes"].split(),
    log:
        f"{LOG_DIR}/push_hybrid_v2v3_meshes_obj.log"
    shell:
        """
        {params.app[0]} --forge_config_file {FORGE_CONFIG} \
            --nexus_env {NEXUS_DESTINATION_ENV} \
            --nexus_org {NEXUS_DESTINATION_ORG} \
            --nexus_proj {NEXUS_DESTINATION_PROJ} \
            --nexus_token_file {NEXUS_TOKEN_FILE} \
        {params.app[1]} --dataset_path {input.mesh_hybrid} \
            --hierarchy_path {input.hierarchy} \
            --config {rule_config_dir}/push_dataset_config.yaml \
            2>&1 | tee {log}
        """

##>push_l23split_meshes_obj : Create a Mesh resource and push it along with the mesh files into Nexus
rule push_l23split_meshes_obj:
    input:
        mesh_l23split=rules.brain_region_meshes_l23split.output,
        hierarchy_split = rules.split_isocortex_layer_23.output.hierarchy_l23split,
        check_obj_meshes = rules.check_l23split_meshes_obj.output
    output:
        temp(touch(f"{WORKING_DIR}/push_l23split_meshes_obj_success.txt"))
    params:
        app=APPS["bba-data-push push-meshes"].split(),
    log:
        f"{LOG_DIR}/push_l23split_meshes_obj.log"
    shell:
        """
        {params.app[0]} --forge_config_file {FORGE_CONFIG} \
            --nexus_env {NEXUS_DESTINATION_ENV} \
            --nexus_org {NEXUS_DESTINATION_ORG} \
            --nexus_proj {NEXUS_DESTINATION_PROJ} \
            --nexus_token_file {NEXUS_TOKEN_FILE} \
        {params.app[1]} --dataset_path {input.mesh_l23split} \
            --hierarchy_path {input.hierarchy_split} \
            --config {rule_config_dir}/push_dataset_config.yaml \
            2>&1 | tee {log}
        """

##>push_all_meshes_obj_datasets : Create a Mesh resource and push it along with the mesh files into Nexus
rule push_all_meshes_obj_datasets:
    input:
        mesh_hybrid=rules.brain_region_meshes_hybrid.output,
        mesh_l23split=rules.brain_region_meshes_l23split.output,
        hierarchy = rules.fetch_ccf_brain_region_hierarchy.output,
        hierarchy_split = rules.split_isocortex_layer_23.output.hierarchy_l23split,
        check_obj_meshes = rules.check_all_meshes_obj_datasets.output
    output:
        temp(touch(f"{WORKING_DIR}/push_all_meshes_obj_datasets_success.txt"))
    params:
        app=APPS["bba-data-push push-meshes"].split(),
    log:
        f"{LOG_DIR}/push_all_meshes_obj_datasets.log"
    shell:
        """
        {params.app[0]} --forge_config_file {FORGE_CONFIG} \
            --nexus_env {NEXUS_DESTINATION_ENV} \
            --nexus_org {NEXUS_DESTINATION_ORG} \
            --nexus_proj {NEXUS_DESTINATION_PROJ} \
            --nexus_token_file {NEXUS_TOKEN_FILE} \
        {params.app[1]} --dataset_path {input.mesh_hybrid} \
            --dataset_path {input.mesh_l23split} \
            --hierarchy_path {input.hierarchy} \
            --hierarchy_path {input.hierarchy_split} \
            --config {rule_config_dir}/push_dataset_config.yaml \
            2>&1 | tee {log}
        """

##>push_sonata_cellrecords : Create a CellRecordSerie resource and push it along with the Sonata .h5 file into Nexus
rule push_sonata_cellrecords:
    input:
        cell_records=rules.cell_records.output,
        check_sonata = rules.check_sonata_cellrecords.output
    output:
        touch(f"{WORKING_DIR}/push_sonata_cellrecords_success.txt")
    params:
        app=APPS["bba-data-push push-cellrecords"].split(),
        provenance = f"brainbuilder cells positions-and-orientations:{applications['applications']['brainbuilder cells positions-and-orientations']}"
    log:
        f"{LOG_DIR}/push_sonata_cellrecords.log"
    shell:
        """
        {params.app[0]} --forge_config_file {FORGE_CONFIG} \
            --nexus_env {NEXUS_DESTINATION_ENV} \
            --nexus_org {NEXUS_DESTINATION_ORG} \
            --nexus_proj {NEXUS_DESTINATION_PROJ} \
            --nexus_token_file {NEXUS_TOKEN_FILE} \
        {params.app[1]} --dataset_path {input.cell_records} \
            --provenances "{params.provenance}" \
            --config {rule_config_dir}/push_dataset_config.yaml \
            --voxels_resolution {RESOLUTION} \
            2>&1 | tee {log}
        """


##========================== User Rules ==========================

##>generate_hybrid_v2v3_annotation : global rule with the aim of triggering the generation and verification of annotation_l23split dataset
rule generate_hybrid_v2v3_annotation:
    input:
        volumetric_dataset = rules.check_hybrid_v2v3_annotation.output
        
##>generate_l23split_annotation : global rule with the aim of triggering the generation and verification of annotation_l23split dataset
rule generate_l23split_annotation:
    input:
        volumetric_dataset = rules.check_l23split_annotation.output

##>generate_cell_densities : global rule with the aim of triggering the generation and verification of annotation_l23split dataset
rule generate_cell_densities:
    input:
        volumetric_dataset = rules.check_cell_densities.output

##>generate_neuron_densities : global rule with the aim of triggering the generation and verification of annotation_l23split dataset
rule generate_neuron_densities:
    input:
        volumetric_dataset = rules.check_neuron_densities.output

##>generate_hybrid_v2v3_meshes_obj : global rule with the aim of triggering the generation and verification of annotation_l23split dataset
rule generate_hybrid_v2v3_meshes_obj:
    input:
        mesh_dataset = rules.check_hybrid_v2v3_meshes_obj.output
        
##>generate_l23split_meshes_obj : global rule with the aim of triggering the generation and verification of annotation_l23split dataset
rule generate_l23split_meshes_obj:
    input:
        mesh_dataset = rules.check_l23split_meshes_obj.output
        
##>generate_sonata_cellrecords : global rule with the aim of triggering the generation and verification of annotation_l23split dataset
rule generate_sonata_cellrecords:
    input:
        cellrecords_dataset = rules.check_sonata_cellrecords.output
    
##>generate_hybrid_v2v3_datasets : global rule with the aim of triggering the generation and verification of volumetric datasets
rule generate_hybrid_v2v3_datasets:
    input:
        hybrid_dataset = rules.check_hybrid_v2v3_report.output
        
##>generate_l23split_datasets : global rule with the aim of triggering the generation and verification of volumetric datasets
rule generate_l23split_datasets:
    input:
        l23split_dataset = rules.check_l23split_report.output
        

##>all : global rule with the aim of triggering the generation of datasets
rule all:
    input:
        all_datasets = rules.check_alldatasets_report.output,