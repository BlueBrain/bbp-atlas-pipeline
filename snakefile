##
##Snakemake - Cell Atlas Pipeline
##
##nabil.alibou@epfl.ch
##jonathan.lurie@epfl.ch
##

import os
import time
from datetime import datetime
import fnmatch
import subprocess
import shutil
import json
import yaml
import re
import logging
import threading
import getpass
import sysconfig
from copy import deepcopy
from uuid import uuid4
# from importlib.metadata import distribution
from platform import python_version
from snakemake.logging import logger as L
from blue_brain_token_fetch.Token_refresher import TokenFetcher

# loading the config
configfile: "config.yaml"

#Launch the automatic token refreshing
myTokenFetcher = TokenFetcher()

# placing the config values into local variable
WORKING_DIR = config["WORKING_DIR"]
NEXUS_IDS_FILE = config["NEXUS_IDS_FILE"]
FORGE_CONFIG = config["FORGE_CONFIG"]
RULES_CONFIG_DIR_TEMPLATES = config["RULES_CONFIG_DIR_TEMPLATES"]
RESOLUTION = str(config["RESOLUTION"])
MODULES_VERBOSE = config["MODULES_VERBOSE"]
DISPLAY_HELP = config["DISPLAY_HELP"]
RESOURCE_TAG = config["RESOURCE_TAG"]
ATLAS_CONFIG_PATH = config["ATLAS_CONFIG_PATH"]
PROVENANCE_METADATA_PATH = f"{WORKING_DIR}/provenance_metadata.json"

NEXUS_ATLAS_ENV = config["NEXUS_ATLAS_ENV"]
NEXUS_ATLAS_ORG = config["NEXUS_ATLAS_ORG"]
NEXUS_ATLAS_PROJ = config["NEXUS_ATLAS_PROJ"]
NEXUS_ONTOLOGY_ORG = config["NEXUS_ONTOLOGY_ORG"]
NEXUS_ONTOLOGY_PROJ = config["NEXUS_ONTOLOGY_PROJ"]

NEXUS_DESTINATION_ENV = config["NEXUS_DESTINATION_ENV"]
NEXUS_DESTINATION_ORG = config["NEXUS_DESTINATION_ORG"]
NEXUS_DESTINATION_PROJ = config["NEXUS_DESTINATION_PROJ"]

VERSION_FILE = os.path.join(WORKING_DIR, "versions.txt")

if not os.path.exists(WORKING_DIR):
    try:
        os.mkdir(WORKING_DIR)
        L.info(f"folder '{WORKING_DIR}' created")
    except OSError:
        L.error(f"creation of the directory {WORKING_DIR} failed")

# Create Logs directory
LOG_DIR = os.path.join(WORKING_DIR, "logs")
snakemake_run_logs = os.path.join(LOG_DIR, "snakemake_run_logs")
if not os.path.exists(LOG_DIR):
    try:
        os.mkdir(LOG_DIR)
        L.info(f"folder '{LOG_DIR}' created")
    except OSError:
        L.error(f"creation of the directory {LOG_DIR} failed")
if not os.path.exists(snakemake_run_logs):
    try:
        os.mkdir(snakemake_run_logs)
        L.info(f"folder '{snakemake_run_logs}' created")
    except OSError:
        L.error(f"creation of the directory {snakemake_run_logs} failed")

# Pipeline logs
logfile = os.path.abspath(
            os.path.join(
                snakemake_run_logs, 
                datetime.now().isoformat().replace(":", "-")
                + ".log"
            )
          )
logfile_handler = logging.FileHandler(logfile)
L.logger.addHandler(logfile_handler)

# All the apps must be listed here so that we can fetch all the versions
APPS = {
    "bba-data-fetch": "bba-data-fetch",
    "parcellationexport": "parcellationexport",
    "atlas-building-tools combination combine-annotations": "atlas-building-tools combination combine-annotations",
    "atlas-building-tools combination combine-markers": "atlas-building-tools combination combine-markers",
    "atlas-building-tools cell-detection svg-to-png": "atlas-building-tools cell-detection svg-to-png",
    "atlas-building-tools cell-detection extract-color-map": "atlas-building-tools cell-detection extract-color-map",
    "atlas-building-tools cell-detection compute-average-soma-radius": "atlas-building-tools cell-detection compute-average-soma-radius",
    "atlas-building-tools cell-densities cell-density": "atlas-building-tools cell-densities cell-density",
    "atlas-building-tools cell-densities glia-cell-densities": "atlas-building-tools cell-densities glia-cell-densities",
    "atlas-building-tools cell-densities inhibitory-and-excitatory-neuron-densities": "atlas-building-tools cell-densities inhibitory-and-excitatory-neuron-densities",
    "atlas-building-tools cell-densities compile-measurements": "atlas-building-tools cell-densities compile-measurements",
    "atlas-building-tools cell-densities measurements-to-average-densities": "atlas-building-tools cell-densities measurements-to-average-densities",
    "atlas-building-tools cell-densities fit-average-densities": "atlas-building-tools cell-densities fit-average-densities",
    "atlas-building-tools cell-densities inhibitory-neuron-densities": "atlas-building-tools cell-densities inhibitory-neuron-densities",
    "atlas-building-tools mtype-densities create-from-profile": "atlas-building-tools mtype-densities create-from-profile",
    "atlas-building-tools mtype-densities create-from-probability-map": "atlas-building-tools mtype-densities create-from-probability-map",
    "brainbuilder cells positions-and-orientations": "brainbuilder cells positions-and-orientations",
    "atlas-building-tools direction-vectors isocortex": "atlas-building-tools direction-vectors isocortex",
    "atlas-building-tools direction-vectors cerebellum": "atlas-building-tools direction-vectors cerebellum",
    "atlas-building-tools direction-vectors interpolate": "atlas-building-tools direction-vectors interpolate",
    "atlas-building-tools orientation-field": "atlas-building-tools orientation-field",
    "atlas-building-tools region-splitter split-isocortex-layer-23": "atlas-building-tools region-splitter split-isocortex-layer-23",
    "atlas-building-tools placement-hints isocortex": "atlas-building-tools placement-hints isocortex",
    "bba-data-integrity-check nrrd-integrity": "bba-data-integrity-check nrrd-integrity",
    "bba-data-integrity-check meshes-obj-integrity": "bba-data-integrity-check meshes-obj-integrity",
    "bba-data-integrity-check atlas-sonata-integrity": "bba-data-integrity-check atlas-sonata-integrity",
    "bba-data-push push-volumetric": "bba-data-push push-volumetric",
    "bba-data-push push-meshes": "bba-data-push push-meshes",
    "bba-data-push push-cellrecords": "bba-data-push push-cellrecords",
    "bba-data-push push-regionsummary": "bba-data-push push-regionsummary"
}
#"gene-expression-volume create-volumes": "gene-expression-volume create-volumes",

# delete the log of app versions
try:
    os.remove(VERSION_FILE)
except OSError:
    pass

# fetch version of each app and write it down in a file
applications = {"applications": {}}
# UNCOMMENT TO CHECK SYSTEMATICALY EVERY MODULES PRESENCE BEFORE RUNNING THE PIPELINE:
#for app in APPS:

#    app_name_fixed = app.split()[0]
#    if MODULES_VERBOSE:
#        L.info(f"{app} [executable at] {shutil.which(app_name_fixed)}")

    # first, we need to check if each CLI is in PATH, if not we abort with exit code 1
#    if shutil.which(app_name_fixed) is None:
#        raise Exception(f"The CLI {app_name_fixed} is not installed or not in PATH. Pipeline cannot execute.")
#        exit(1)

    # Slow but simplest way to check every modules regardless of how they have been installed
#    app_version = subprocess.check_output(f"{app_name_fixed} --version", shell=True).decode('ascii').rstrip("\n\r")
#    applications["applications"].update({app: app_version})

with open(VERSION_FILE, "w") as outfile: 
    outfile.write(json.dumps(applications, indent = 4))

# Reading some Nexus file @id mapping
NEXUS_IDS = json.loads(open(NEXUS_IDS_FILE, 'r').read().strip())

# Create the rules configuration files from the template configuration files and annotate the data paths they contains
rules_config_dir = f"{WORKING_DIR}/rules_config_dir"

if not os.path.exists(rules_config_dir):
    try:
        os.mkdir(rules_config_dir)
        L.info(f"folder '{rules_config_dir}' created")
    except OSError:
        L.error(f"creation of the directory {rules_config_dir} failed")

# Generate all the configuration yaml files from the template ones located in blue_brain_atlas_pipeline/rules_config_dir_templates
repository = "rules_config_dir_templates"
files = os.listdir(repository)
pattern = "*_template.yaml"
files_list = fnmatch.filter(files, pattern)
for file in files_list:
    try:
        rule_config_file_template = open(f"{RULES_CONFIG_DIR_TEMPLATES}/{file}", "r")
        rule_config_file_name = file.replace('_template', '')
        rule_config_file = open(f"{rules_config_dir}/{rule_config_file_name}", "w+")
        rule_config_file.write(re.sub("{WORKING_DIR}", WORKING_DIR, rule_config_file_template.read()))
        rule_config_file_template.close()
        rule_config_file.seek(0)
    except FileExistsError:
        pass

with open(f"{rules_config_dir}/combine_markers_hybrid_config.yaml", "r") as file:
    COMBINE_MARKERS_HYBRID_CONFIG_FILE = yaml.safe_load(file.read().strip())

with open(f"{rules_config_dir}/combine_markers_ccfv2_config.yaml", "r") as file:
    COMBINE_MARKERS_CCFV2_CONFIG_FILE = yaml.safe_load(file.read().strip())

with open(f"{rules_config_dir}/cell_positions_hybrid_config.yaml", "r") as file:
    CELL_POSITIONS_HYBRID_CONFIG_FILE = yaml.safe_load(file.read().strip())

with open(f"{rules_config_dir}/cell_positions_ccfv2_config.yaml", "r") as file:
    CELL_POSITIONS_CCFV2_CONFIG_FILE = yaml.safe_load(file.read().strip())

with open(f"{rules_config_dir}/cell_positions_ccfv2_correctednissl_config.yaml", "r") as file:
    CELL_POSITIONS_CCFV2_CORRECTEDNISSL_CONFIG_FILE = yaml.safe_load(file.read().strip())

with open(f"{rules_config_dir}/push_dataset_config.yaml", "r") as file:
    PUSH_DATASET_CONFIG_FILE = yaml.safe_load(file.read().strip())

AVERAGE_DENSITIES_CONFIG_FILE = f"{rules_config_dir}/fit_average_densities_config.yaml"
AVERAGE_DENSITIES_CORRECTEDNISSL_CONFIG_FILE = f"{rules_config_dir}/fit_average_densities_correctednissl_config.yaml"
MTYPES_PROFILE_CCFV2_CONFIG_ = f"{rules_config_dir}/mtypes_profile_ccfv2_config.yaml"
MTYPES_PROFILE_CCFV2_CORRECTEDNISSL_CONFIG_ = f"{rules_config_dir}/mtypes_profile_ccfv2_correctednissl_config.yaml"
MTYPES_PROBABILITY_MAP_CONFIG_ = f"{rules_config_dir}/mtypes_probability_map_config.yaml"
MTYPES_PROBABILITY_MAP_CORRECTEDNISSL_CONFIG_ = f"{rules_config_dir}/mtypes_probability_map_correctednissl_config.yaml"

def write_json(asso_json_path, dict, **kwargs):
    file_path_update = open(asso_json_path, 'w')
    #new_dict = deepcopy(dict(content, **{"rule_name":f"{rule_name}"}))
    new_dict = deepcopy(dict)
    for key, value in kwargs.items():
        new_dict[key] = value
    file_path_update.write(json.dumps(new_dict, ensure_ascii=False, indent=2))
    file_path_update.close()
    return file_path_update

# Provenance metadata:
provenance_dict = {
    "activity_id": f"https://bbp.epfl.ch/neurosciencegraph/data/activity/{str(uuid4())}",
    "softwareagent_name" : "Blue Brain Atlas Annotation Pipeline",
    "software_version": "0.1.0", # later f"{distribution('pipeline').version}" or version.py
    "runtime_platform": f"{sysconfig.get_platform()}",
    "repo_adress": "https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline",
    "language": f"python {python_version()}",
    "start_time" : f"{datetime.today().strftime('%Y-%m-%dT%H:%M:%S')}",
    "input_dataset_used": {
        "hierarchy": {
          "id": "http://bbp.epfl.ch/neurosciencegraph/ontologies/mba",
          "type": "ParcellationOntology"
        },
        "brain_parcellation_ccfv3": {
          "id": "https://bbp.epfl.ch/neurosciencegraph/data/025eef5f-2a9a-4119-b53f-338452c72f2a",
          "type": "BrainParcellationDataLayer"
        }
    },
    "derivations": {
        "brain_region_mask_ccfv3_l23split": "annotation_ccfv3_l23split",
        "hierarchy_l23split": "hierarchy",
        "annotation_ccfv3_l23split": "brain_parcellation_ccfv3",
        "direction_vectors_isocortex_ccfv3": "brain_parcellation_ccfv3",
        "cell_orientations_ccfv3": "direction_vectors_isocortex_ccfv3",
        "placement_hints_ccfv3_l23split": "annotation_ccfv3_l23split"
    }
}

if not os.path.exists(PROVENANCE_METADATA_PATH):
    write_json(PROVENANCE_METADATA_PATH, provenance_dict)

with open(PROVENANCE_METADATA_PATH, "r+") as provenance_file:
    provenance_file.seek(0)
    PROVENANCE_METADATA = json.loads(provenance_file.read())

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
    output:
        f"{PUSH_DATASET_CONFIG_FILE['HierarchyJson']['hierarchy']}",
    params:
        nexus_id=NEXUS_IDS["ParcellationOntology"]["allen_mouse_ccf"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken(),
        derivation = PROVENANCE_METADATA["input_dataset_used"].update({"hierarchy" : {"id":NEXUS_IDS["ParcellationOntology"]["allen_mouse_ccf"], "type":"ParcellationOntology"}})
    log:
        f"{LOG_DIR}/fetch_ccf_brain_region_hierarchy.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ONTOLOGY_ORG} \
            --nexus-proj {NEXUS_ONTOLOGY_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --favor name:1.json \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_brain_parcellation_ccfv2 :  fetch the CCF v2 brain parcellation volume in the given resolution
rule fetch_brain_parcellation_ccfv2:
    output:
        f"{WORKING_DIR}/brain_parcellation_ccfv2.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["BrainParcellationDataLayer"]["brain_ccfv2"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken(),
    log:
        f"{LOG_DIR}/fetch_brain_parcellation_ccfv2.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """              

##>fetch_fiber_parcellation_ccfv2 : fetch the CCF v2 fiber parcellation volume in the given resolution
rule fetch_fiber_parcellation_ccfv2:
    output:
        f"{WORKING_DIR}/fiber_parcellation_ccfv2.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["BrainParcellationDataLayer"]["fiber_ccfv2"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_fiber_parcellation_ccfv2.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_brain_parcellation_ccfv3 : fetch the CCF v3 brain parcellation volume in the given resolution
rule fetch_brain_parcellation_ccfv3:
    output:
        f"{WORKING_DIR}/brain_parcellation_ccfv3.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["BrainParcellationDataLayer"]["brain_ccfv3"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken(),
        derivation = PROVENANCE_METADATA["input_dataset_used"].update({"brain_parcellation_ccfv3" : {"id":NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["BrainParcellationDataLayer"]["brain_ccfv3"], "type":"BrainParcellationDataLayer"}})
    log:
        f"{LOG_DIR}/fetch_brain_parcellation_ccfv3.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """


##>fetch_brain_template : fetch the CCF v3 brain average template volume in the given resolution
rule fetch_brain_template:
    output:
        f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['average_template_25']}"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["BrainTemplateDataLayer"]["average_template_25"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_brain_template.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """


##>fetch_nissl_stained_volume : fetch the CCF nissl stained volume in the given resolution
rule fetch_nissl_stained_volume:
    output:
        f"{WORKING_DIR}/nissl_stained_volume.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["NISSLImageDataLayer"]["ara_nissl"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_nissl_stained_volume.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_corrected_nissl_stained_volume : fetch the corrected nissl stained volume in the given resolution
rule fetch_corrected_nissl_stained_volume:
    output:
        f"{WORKING_DIR}/nissl_corrected_volume.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["NISSLImageDataLayer"]["corrected_nissl"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_corrected_nissl_stained_volume.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_annotation_stack_ccfv2_coronal : fetch the CCFv2 annotation coronal image stack stack
rule fetch_annotation_stack_ccfv2_coronal:
    output:
        directory(f"{WORKING_DIR}/annotation_stack_ccfv2_coronal")
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["ImageStack"]["annotation_stack_ccfv2_coronal"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_annotation_stack_ccfv2_coronal.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output}.tar.gz \
            --nexus-id {params.nexus_id} \
            --verbose ;
            mkdir {output} ;
            tar xf {WORKING_DIR}/annotation_stack_ccfv2_coronal.tar.gz --directory={output} --strip-components=1 ;
            rm {WORKING_DIR}/annotation_stack_ccfv2_coronal.tar.gz ;
            2>&1 | tee {log}
        """

##>fetch_nissl_stack_ccfv2_coronal : fetch the CCFv2 nissl coronal image stack stack
rule fetch_nissl_stack_ccfv2_coronal:
    output:
        directory(f"{WORKING_DIR}/nissl_stack_ccfv2_coronal")
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["ImageStack"]["nissl_stack_ccfv2_coronal"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_nissl_stack_ccfv2_coronal.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output}.tar.gz \
            --nexus-id {params.nexus_id} \
            --verbose ;
            mkdir {output} ;
            tar xf {WORKING_DIR}/nissl_stack_ccfv2_coronal.tar.gz --directory={output} --strip-components=1 ;
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

## =========================================================================================
## ============================== CELL DENSITY PIPELINE PART 1 =============================
## =========================================================================================

#### TO DO: replace all the fetch 'genes' by one rule using wildcard : ####
### WILDCARD SUCCESSFUL TEST:
###>fetch_glia_gene : fetch all the gene expression volumes using wildcard
#rule fetch_glia_gene:
#    output:
#        f"{WORKING_DIR}"+"/gene_{sample}.nrrd"
#    params:
#        nexus_id = lambda wildcards:NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"][wildcards.sample],
#        app=APPS["bba-datafetch"],
#        token = myTokenFetcher.getAccessToken()
#    shell:
#        """
#        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
#            --nexus-token {params.token} \
#            --nexus-org {NEXUS_ATLAS_ORG} \
#            --nexus-proj {NEXUS_ATLAS_PROJ} \
#            --out {output} \
#            --nexus-id {params.nexus_id} \
#            --verbose
#        """

#DATASETS = []
#for value in COMBINE_MARKERS_HYBRID_CONFIG_FILE['inputGeneVolumePath'].values():
#    DATASETS.append(value)

#rule fetch_all_glia: trigger the retrieving of all the gene expression volumes from Nexus
#    input:
#        expand("{dataset}", dataset=DATASETS)


##>fetch_gene_gad : fetch the gene expression volume corresponding to the genetic marker gad
rule fetch_gene_gad:
    output:
        f"{WORKING_DIR}/gene_gad.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["gad"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_gene_gad.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_gene_nrn1 : fetch the gene expression volume corresponding to the genetic marker nrn1
rule fetch_gene_nrn1:
    output:
        f"{WORKING_DIR}/gene_nrn1.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["nrn1"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_gene_nrn1.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_gene_aldh1l1 : fetch the gene expression volume corresponding to the genetic marker aldh1l1
rule fetch_gene_aldh1l1:
    output:
        f"{COMBINE_MARKERS_HYBRID_CONFIG_FILE['inputGeneVolumePath']['aldh1l1']}"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["aldh1l1"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_gene_aldh1l1.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_gene_cnp : fetch the gene expression volume corresponding to the genetic marker cnp
rule fetch_gene_cnp:
    output:
        f"{COMBINE_MARKERS_HYBRID_CONFIG_FILE['inputGeneVolumePath']['cnp']}"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["cnp"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_gene_cnp.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_gene_mbp : fetch the gene expression volume corresponding to the genetic marker mbp
rule fetch_gene_mbp:
    output:
        f"{COMBINE_MARKERS_HYBRID_CONFIG_FILE['inputGeneVolumePath']['mbp']}"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["mbp"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_gene_mbp.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_gene_gfap : fetch the gene expression volume corresponding to the genetic marker gfap
rule fetch_gene_gfap:
    output:
        f"{COMBINE_MARKERS_HYBRID_CONFIG_FILE['inputGeneVolumePath']['gfap']}"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["gfap"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_gene_gfap.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_gene_s100b : fetch the gene expression volume corresponding to the genetic marker s100b
rule fetch_gene_s100b:
    output:
        f"{COMBINE_MARKERS_HYBRID_CONFIG_FILE['inputGeneVolumePath']['s100b']}"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["s100b"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_gene_s100b.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_gene_tmem119 : fetch the gene expression volume corresponding to the genetic marker tmem119
rule fetch_gene_tmem119:
    output:
        f"{COMBINE_MARKERS_HYBRID_CONFIG_FILE['inputGeneVolumePath']['tmem119']}"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["tmem119"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_gene_tmem119.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """
        
##>fetch_gene_pv : fetch the gene expression volume corresponding to the genetic marker pv
rule fetch_gene_pv:
    output:
        f"{WORKING_DIR}/gene_pv.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["pv"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_gene_pv.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_gene_pv_correctednissl : fetch the gene expression volume corresponding to the genetic marker pv
rule fetch_gene_pv_correctednissl:
    output:
        f"{WORKING_DIR}/gene_pv_correctednissl.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["pv_correctednissl"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_gene_pv_correctednissl.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """
        
##>fetch_gene_sst : fetch the gene expression volume corresponding to the genetic marker sst
rule fetch_gene_sst:
    output:
        f"{WORKING_DIR}/gene_sst.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["sst"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_gene_sst.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """
        
##>fetch_gene_sst_correctednissl : fetch the gene expression volume corresponding to the genetic marker sst
rule fetch_gene_sst_correctednissl:
    output:
        f"{WORKING_DIR}/gene_sst_correctednissl.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["sst_correctednissl"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_gene_sst_correctednissl.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """
        
##>fetch_gene_vip : fetch the gene expression volume corresponding to the genetic marker vip
rule fetch_gene_vip:
    output:
        f"{WORKING_DIR}/gene_vip.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["vip"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_gene_vip.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_gene_vip_correctednissl : fetch the gene expression volume corresponding to the genetic marker vip
rule fetch_gene_vip_correctednissl:
    output:
        f"{WORKING_DIR}/gene_vip_correctednissl.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["vip_correctednissl"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_gene_vip_correctednissl.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_gene_gad67 : fetch the gene expression volume corresponding to the genetic marker gad67
rule fetch_gene_gad67:
    output:
        f"{WORKING_DIR}/gene_gad67.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["gad67"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_gene_gad67.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

##>fetch_gene_gad67_correctednissl : fetch the gene expression volume corresponding to the genetic marker gad67
rule fetch_gene_gad67_correctednissl:
    output:
        f"{WORKING_DIR}/gene_gad67_correctednissl.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["gad67_correctednissl"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.getAccessToken()
    log:
        f"{LOG_DIR}/fetch_gene_gad67_correctednissl.log"
    shell:
        """
        {params.app} --nexus-env {NEXUS_ATLAS_ENV} \
            --nexus-token {params.token} \
            --nexus-org {NEXUS_ATLAS_ORG} \
            --nexus-proj {NEXUS_ATLAS_PROJ} \
            --out {output} \
            --nexus-id {params.nexus_id} \
            --verbose \
            2>&1 | tee {log}
        """

# ##>gene_expression_volume : Compute the overall mouse brain cell density
#rule gene_expression_volume:
#    input:
#        config_file = GENE_EXPRESSION_CONFIG_FILE,
#    output:
#        pv_volume = f"{GENE_EXPRESSION_CONFIG_FILE['gene']['Pv']['outputPath']}",
#        sst_volume = f"{GENE_EXPRESSION_CONFIG_FILE['gene']['sst']['outputPath']}",
#        vip_volume = f"{GENE_EXPRESSION_CONFIG_FILE['gene']['vip']['outputPath']}",
#        gad67_volume = f"{GENE_EXPRESSION_CONFIG_FILE['gene']['gad67']['outputPath']}",
#    params:
#        app=APPS["gene-expression-volume create-volumes"]
#    log:
#        f"{LOG_DIR}/gene_expression_volume.log"
#    shell:
#        """
#        {params.app} --configuration-path {input.config_file} \
#            2>&1 | tee {log}
#        """

##>combine_markers_hybrid : Generate and save the combined glia files and the global celltype scaling factors
rule combine_markers_hybrid:
    input:
        aldh1l1 = rules.fetch_gene_aldh1l1.output,
        cnp = rules.fetch_gene_cnp.output,
        mbp = rules.fetch_gene_mbp.output,
        gfap = rules.fetch_gene_gfap.output,
        s100b = rules.fetch_gene_s100b.output,
        tmem119 = rules.fetch_gene_tmem119.output,
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.combine_annotations.output,
        markers_config_file = f"{rules_config_dir}/combine_markers_hybrid_config.yaml"
    output:
        oligodendrocyte_volume = f"{COMBINE_MARKERS_HYBRID_CONFIG_FILE['outputCellTypeVolumePath']['oligodendrocyte']}",
        astrocyte_volume = f"{COMBINE_MARKERS_HYBRID_CONFIG_FILE['outputCellTypeVolumePath']['astrocyte']}",
        microglia_volume = f"{COMBINE_MARKERS_HYBRID_CONFIG_FILE['outputCellTypeVolumePath']['microglia']}",
        glia_volume = f"{COMBINE_MARKERS_HYBRID_CONFIG_FILE['outputOverallGliaVolumePath']}",
        cell_proportion = f"{COMBINE_MARKERS_HYBRID_CONFIG_FILE['outputCellTypeProportionsPath']}"
    params:
        app=APPS["atlas-building-tools combination combine-markers"]
    log:
        f"{LOG_DIR}/combine_markers_hybrid.log"
    shell:
        """
        {params.app} --hierarchy-path {input.hierarchy} \
            --annotation-path {input.parcellation_volume} \
            --config {input.markers_config_file} \
            2>&1 | tee {log}
        """

        
##>combine_markers_ccfv2 : Generate and save the combined glia files and the global celltype scaling factors
rule combine_markers_ccfv2:
    input:
        aldh1l1 = rules.fetch_gene_aldh1l1.output,
        cnp = rules.fetch_gene_cnp.output,
        mbp = rules.fetch_gene_mbp.output,
        gfap = rules.fetch_gene_gfap.output,
        s100b = rules.fetch_gene_s100b.output,
        tmem119 = rules.fetch_gene_tmem119.output,
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.fetch_brain_parcellation_ccfv2.output,
        markers_config_file = f"{rules_config_dir}/combine_markers_ccfv2_config.yaml"
    output:
        oligodendrocyte_volume = f"{COMBINE_MARKERS_CCFV2_CONFIG_FILE['outputCellTypeVolumePath']['oligodendrocyte']}",
        astrocyte_volume = f"{COMBINE_MARKERS_CCFV2_CONFIG_FILE['outputCellTypeVolumePath']['astrocyte']}",
        microglia_volume = f"{COMBINE_MARKERS_CCFV2_CONFIG_FILE['outputCellTypeVolumePath']['microglia']}",
        glia_volume = f"{COMBINE_MARKERS_CCFV2_CONFIG_FILE['outputOverallGliaVolumePath']}",
        cell_proportion = f"{COMBINE_MARKERS_CCFV2_CONFIG_FILE['outputCellTypeProportionsPath']}"
    params:
        app=APPS["atlas-building-tools combination combine-markers"]
    log:
        f"{LOG_DIR}/combine_markers_ccfv2.log"
    shell:
        """
        {params.app} --hierarchy-path {input.hierarchy} \
            --annotation-path {input.parcellation_volume} \
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

##>cell_density_hybrid : Compute the overall mouse brain cell density
rule cell_density_hybrid:
    input:
        hierarchy = rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume = rules.combine_annotations.output,
        nissl_volume = rules.fetch_nissl_stained_volume.output
    output:
        f"{WORKING_DIR}/cell_density_hybrid.nrrd"
    params:
        app=APPS["atlas-building-tools cell-densities cell-density"]
    log:
        f"{LOG_DIR}/cell_density_hybrid.log"
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --hierarchy-path {input.hierarchy} \
            --nissl-path {input.nissl_volume} \
            --output-path {output} \
            2>&1 | tee {log}
        """
        
##>cell_density_ccfv2 : Compute the overall mouse brain cell density
rule cell_density_ccfv2:
    input:
        hierarchy = rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume = rules.fetch_brain_parcellation_ccfv2.output,
        nissl_volume = rules.fetch_nissl_stained_volume.output
    output:
        f"{WORKING_DIR}/cell_density_ccfv2.nrrd"
    params:
        app=APPS["atlas-building-tools cell-densities cell-density"]
    log:
        f"{LOG_DIR}/cell_density_ccfv2.log"
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --hierarchy-path {input.hierarchy} \
            --nissl-path {input.nissl_volume} \
            --output-path {output} \
            2>&1 | tee {log}
        """
        
##>cell_density_ccfv2_correctednissl : Compute the overall mouse brain cell density
rule cell_density_ccfv2_correctednissl:
    input:
        hierarchy = rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume = rules.fetch_brain_parcellation_ccfv2.output,
        nissl_volume = rules.fetch_corrected_nissl_stained_volume.output
    output:
        f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['overall_cell_density_ccfv2_correctednissl']}"
    params:
        app=APPS["atlas-building-tools cell-densities cell-density"]
    log:
        f"{LOG_DIR}/cell_density_ccfv2_correctednissl.log"
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --hierarchy-path {input.hierarchy} \
            --nissl-path {input.nissl_volume} \
            --output-path {output} \
            2>&1 | tee {log}
        """

##>glia_cell_densities_hybrid : Compute and save the glia cell densities
rule glia_cell_densities_hybrid:
    input:
        hierarchy = rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume = rules.combine_annotations.output,
        overall_cell_density = rules.cell_density_hybrid.output,
        glia_density = rules.combine_markers_hybrid.output.glia_volume,
        astro_density = rules.combine_markers_hybrid.output.astrocyte_volume,
        oligo_density = rules.combine_markers_hybrid.output.oligodendrocyte_volume,
        microglia_density = rules.combine_markers_hybrid.output.microglia_volume,
        glia_proportion = rules.combine_markers_hybrid.output.cell_proportion
    output:
        cell_densities = directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['cell_densities_hybrid']}"),
        glia_density = f"{WORKING_DIR}/cell_densities_hybrid/glia_density.nrrd",
        astrocyte_density = f"{CELL_POSITIONS_HYBRID_CONFIG_FILE['inputDensityVolumePath']['astrocyte']}",
        oligodendrocyte_density = f"{CELL_POSITIONS_HYBRID_CONFIG_FILE['inputDensityVolumePath']['oligodendrocyte']}",
        microglia_density = f"{CELL_POSITIONS_HYBRID_CONFIG_FILE['inputDensityVolumePath']['microglia']}",
        neuron_density = f"{WORKING_DIR}/cell_densities_hybrid/neuron_density.nrrd"
    params:
        app=APPS["atlas-building-tools cell-densities glia-cell-densities"]
    log:
        f"{LOG_DIR}/glia_cell_densities_hybrid.log"
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

        
##>glia_cell_densities_ccfv2 : Compute and save the glia cell densities
rule glia_cell_densities_ccfv2:
    input:
        hierarchy = rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume = rules.fetch_brain_parcellation_ccfv2.output,
        overall_cell_density = rules.cell_density_ccfv2.output,
        glia_density = rules.combine_markers_ccfv2.output.glia_volume,
        astro_density = rules.combine_markers_ccfv2.output.astrocyte_volume,
        oligo_density = rules.combine_markers_ccfv2.output.oligodendrocyte_volume,
        microglia_density = rules.combine_markers_ccfv2.output.microglia_volume,
        glia_proportion = rules.combine_markers_ccfv2.output.cell_proportion
    output:
        cell_densities = directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['cell_densities_ccfv2']}"),
        glia_density = f"{WORKING_DIR}/cell_densities_ccfv2/glia_density.nrrd",
        astrocyte_density = f"{CELL_POSITIONS_CCFV2_CONFIG_FILE['inputDensityVolumePath']['astrocyte']}",
        oligodendrocyte_density = f"{CELL_POSITIONS_CCFV2_CONFIG_FILE['inputDensityVolumePath']['oligodendrocyte']}",
        microglia_density = f"{CELL_POSITIONS_CCFV2_CONFIG_FILE['inputDensityVolumePath']['microglia']}",
        neuron_density = f"{WORKING_DIR}/cell_densities_ccfv2/neuron_density.nrrd"
    params:
        app=APPS["atlas-building-tools cell-densities glia-cell-densities"]
    log:
        f"{LOG_DIR}/glia_cell_densities_ccfv2.log"
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
        
##>glia_cell_densities_ccfv2_correctednissl : Compute and save the glia cell densities
rule glia_cell_densities_ccfv2_correctednissl:
    input:
        hierarchy = rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume = rules.fetch_brain_parcellation_ccfv2.output,
        overall_cell_density = rules.cell_density_ccfv2_correctednissl.output,
        glia_density = rules.combine_markers_ccfv2.output.glia_volume,
        astro_density = rules.combine_markers_ccfv2.output.astrocyte_volume,
        oligo_density = rules.combine_markers_ccfv2.output.oligodendrocyte_volume,
        microglia_density = rules.combine_markers_ccfv2.output.microglia_volume,
        glia_proportion = rules.combine_markers_ccfv2.output.cell_proportion
    output:
        cell_densities = directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['cell_densities_ccfv2_correctednissl']}"),
        glia_density = f"{WORKING_DIR}/cell_densities_ccfv2_correctednissl/glia_density.nrrd",
        astrocyte_density = f"{CELL_POSITIONS_CCFV2_CORRECTEDNISSL_CONFIG_FILE['inputDensityVolumePath']['astrocyte']}",
        oligodendrocyte_density = f"{CELL_POSITIONS_CCFV2_CORRECTEDNISSL_CONFIG_FILE['inputDensityVolumePath']['oligodendrocyte']}",
        microglia_density = f"{CELL_POSITIONS_CCFV2_CORRECTEDNISSL_CONFIG_FILE['inputDensityVolumePath']['microglia']}",
        neuron_density = f"{WORKING_DIR}/cell_densities_ccfv2_correctednissl/neuron_density.nrrd"
    params:
        app=APPS["atlas-building-tools cell-densities glia-cell-densities"]
    log:
        f"{LOG_DIR}/glia_cell_densities_ccfv2_correctednissl.log"
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

##>inhibitory_excitatory_neuron_densities_hybrid : Compute the inhibitory and excitatory neuron densities
rule inhibitory_excitatory_neuron_densities_hybrid:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.combine_annotations.output,
        gad1_volume = rules.fetch_gene_gad.output,
        nrn1_volume = rules.fetch_gene_nrn1.output,
        neuron_density = rules.glia_cell_densities_hybrid.output.neuron_density,
    output:
        neuron_densities = directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['neuron_densities_hybrid']}"),
        inhibitory_neuron_density = f"{CELL_POSITIONS_HYBRID_CONFIG_FILE['inputDensityVolumePath']['inhibitory_neuron']}",
        excitatory_neuron_density = f"{CELL_POSITIONS_HYBRID_CONFIG_FILE['inputDensityVolumePath']['excitatory_neuron']}",
    params:
        app=APPS["atlas-building-tools cell-densities inhibitory-and-excitatory-neuron-densities"]
    log:
        f"{LOG_DIR}/inhibitory_excitatory_neuron_densities_hybrid.log"
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

        
##>inhibitory_excitatory_neuron_densities_ccfv2 : Compute the inhibitory and excitatory neuron densities
rule inhibitory_excitatory_neuron_densities_ccfv2:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.fetch_brain_parcellation_ccfv2.output,
        gad1_volume = rules.fetch_gene_gad.output,
        nrn1_volume = rules.fetch_gene_nrn1.output,
        neuron_density = rules.glia_cell_densities_ccfv2.output.neuron_density,
    output:
        neuron_densities = directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['neuron_densities_ccfv2']}"),
        inhibitory_neuron_density = f"{CELL_POSITIONS_CCFV2_CONFIG_FILE['inputDensityVolumePath']['inhibitory_neuron']}",
        excitatory_neuron_density = f"{CELL_POSITIONS_CCFV2_CONFIG_FILE['inputDensityVolumePath']['excitatory_neuron']}",
    params:
        app=APPS["atlas-building-tools cell-densities inhibitory-and-excitatory-neuron-densities"]
    log:
        f"{LOG_DIR}/inhibitory_excitatory_neuron_densities_ccfv2.log"
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
        
##>inhibitory_excitatory_neuron_densities_ccfv2_correctednissl : Compute the inhibitory and excitatory neuron densities
rule inhibitory_excitatory_neuron_densities_ccfv2_correctednissl:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.fetch_brain_parcellation_ccfv2.output,
        gad1_volume = rules.fetch_gene_gad.output,
        nrn1_volume = rules.fetch_gene_nrn1.output,
        neuron_density = rules.glia_cell_densities_ccfv2_correctednissl.output.neuron_density,
    output:
        neuron_densities = directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['neuron_densities_ccfv2_correctednissl']}"),
        inhibitory_neuron_density = f"{CELL_POSITIONS_CCFV2_CORRECTEDNISSL_CONFIG_FILE['inputDensityVolumePath']['inhibitory_neuron']}",
        excitatory_neuron_density = f"{CELL_POSITIONS_CCFV2_CORRECTEDNISSL_CONFIG_FILE['inputDensityVolumePath']['excitatory_neuron']}",
    params:
        app=APPS["atlas-building-tools cell-densities inhibitory-and-excitatory-neuron-densities"]
    log:
        f"{LOG_DIR}/inhibitory_excitatory_neuron_densities_ccfv2_correctednissl.log"
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

## =========================================================================================
## =============================== ANNOTATION PIPELINE PART 1 ==============================
## =========================================================================================

##>direction_vectors_isocortex_ccfv2 : Compute a volume with 3 elements per voxel that are the direction in Euler angles (x, y, z) of the neurons. This uses Regiodesics under the hood. The output is only for the top regions of the isocortex.
rule direction_vectors_isocortex_ccfv2:
    input:
        parcellation_volume=rules.fetch_brain_parcellation_ccfv2.output,
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output
    output:
        f"{WORKING_DIR}/direction_vectors_isocortex_ccfv2.nrrd"
    params:
        app=APPS["atlas-building-tools direction-vectors isocortex"]
    log:
        f"{LOG_DIR}/direction_vectors_isocortex_ccfv2.log"
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --hierarchy-path {input.hierarchy} \
            --output-path {output} \
            --algorithm shading-blur-gradient \
            2>&1 | tee {log}
        """

##>direction_vectors_isocortex_ccfv3 : Compute a volume with 3 elements per voxel that are the direction in Euler angles (x, y, z) of the neurons. This uses Regiodesics under the hood. The output is only for the top regions of the isocortex.
rule direction_vectors_isocortex_ccfv3:
    input:
        parcellation_volume=rules.fetch_brain_parcellation_ccfv3.output,
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output
    output:
        f"{WORKING_DIR}/direction_vectors_isocortex_ccfv3.nrrd"
    params:
        app=APPS["atlas-building-tools direction-vectors isocortex"]
    log:
        f"{LOG_DIR}/direction_vectors_isocortex_ccfv3.log"
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --hierarchy-path {input.hierarchy} \
            --output-path {output} \
            --algorithm shading-blur-gradient \
            2>&1 | tee {log}
        """

##>direction_vectors_isocortex_hybrid : Compute a volume with 3 elements per voxel that are the direction in Euler angles (x, y, z) of the neurons. This uses Regiodesics under the hood. The output is only for the top regions of the isocortex.
rule direction_vectors_isocortex_hybrid:
    input:
        parcellation_volume=rules.combine_annotations.output,
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output
    output:
        f"{WORKING_DIR}/direction_vectors_isocortex_hybrid.nrrd"
    params:
        app=APPS["atlas-building-tools direction-vectors isocortex"]
    log:
        f"{LOG_DIR}/direction_vectors_isocortex_hybrid.log"
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --hierarchy-path {input.hierarchy} \
            --output-path {output} \
            --algorithm shading-blur-gradient \
            2>&1 | tee {log}
        """


##>direction_vectors_cerebellum : Compute a volume with 3 elements per voxel that are the direction in Euler angles (x, y, z) of the neurons. This uses Regiodesics under the hood. The output is only for some regions of the cerebellum.
rule direction_vectors_cerebellum:
    input:
        parcellation_volume=rules.fetch_brain_parcellation_ccfv2.output
    output:
        f"{WORKING_DIR}/direction_vectors_cerebellum.nrrd"
    params:
        app=APPS["atlas-building-tools direction-vectors cerebellum"]
    log:
        f"{LOG_DIR}/direction_vectors_cerebellum.log"
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --output-path {output} \
            --algorithm shading-blur-gradient \
            2>&1 | tee {log}
        """

##>interpolate_direction_vectors_isocortex_ccfv2 : Interpolate the [NaN, NaN, NaN] direction vectors by non-[NaN, NaN, NaN] ones.
rule interpolate_direction_vectors_isocortex_ccfv2:
    input:
        parcellation_volume=rules.fetch_brain_parcellation_ccfv2.output,
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        direction_vectors=rules.direction_vectors_isocortex_ccfv2.output
    output:
        f"{WORKING_DIR}/interpolated_direction_vectors_isocortex_ccfv2.nrrd"
    params:
        app=APPS["atlas-building-tools direction-vectors interpolate"]
    log:
        f"{LOG_DIR}/interpolate_direction_vectors_isocortex_ccfv2.log"
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --hierarchy-path {input.hierarchy} \
            --direction-vectors-path {input.direction_vectors} \
            --metadata-path f"{rules_config_dir}/isocortex_metadata.json" \
            --nans \
            --output-path {output} \
            --algorithm shading-blur-gradient \
            2>&1 | tee {log}
        """


##>split_isocortex_layer_23_ccfv3 : Refine annotations by splitting brain regions 
rule split_isocortex_layer_23_ccfv3:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.fetch_brain_parcellation_ccfv3.output,
        direction_vectors=rules.direction_vectors_isocortex_ccfv3.output
    output:
        hierarchy_l23split=f"{PUSH_DATASET_CONFIG_FILE['HierarchyJson']['hierarchy_l23split']}",
        annotation_l23split=f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['annotation_ccfv3_l23split']}"
    params:
        app=APPS["atlas-building-tools region-splitter split-isocortex-layer-23"]
    log:
        f"{LOG_DIR}/split_isocortex_layer_23_ccfv3.log"
    shell:
        """
        {params.app} --hierarchy-path {input.hierarchy} \
            --annotation-path {input.parcellation_volume} \
            --direction-vectors-path {input.direction_vectors} \
            --output-hierarchy-path {output.hierarchy_l23split} \
            --output-annotation-path {output.annotation_l23split} \
            2>&1 | tee {log}
        """

##>split_isocortex_layer_23_hybrid : Refine annotations by splitting brain regions 
rule split_isocortex_layer_23_hybrid:
    input:
        parcellation_volume=rules.combine_annotations.output,
        direction_vectors=rules.direction_vectors_isocortex_hybrid.output
    output:
        annotation_l23split=f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['annotation_hybrid_l23split']}"
    params:
        app=APPS["atlas-building-tools region-splitter split-isocortex-layer-23"]
    log:
        f"{LOG_DIR}/split_isocortex_layer_23_hybrid.log"
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --direction-vectors-path {input.direction_vectors} \
            --output-annotation-path {output.annotation_l23split} \
            2>&1 | tee {log}
        """

        
##>split_isocortex_layer_23_ccfv2 : Refine annotations by splitting brain regions 
rule split_isocortex_layer_23_ccfv2:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.fetch_brain_parcellation_ccfv2.output,
        direction_vectors=rules.interpolate_direction_vectors_isocortex_ccfv2.output
    output:
        annotation_l23split=f"annotation_ccfv2_l23split.nrrd"
    params:
        app=APPS["atlas-building-tools region-splitter split-isocortex-layer-23"]
    log:
        f"{LOG_DIR}/split_isocortex_layer_23_ccfv2.log"
    shell:
        """
        {params.app} --hierarchy-path {input.hierarchy} \
            --annotation-path {input.parcellation_volume} \
            --direction-vectors-path {input.direction_vectors} \
            --output-hierarchy-path {output.hierarchy_l23split} \
            --output-annotation-path {output.annotation_l23split} \
            2>&1 | tee {log}
        """

##>orientation_field_ccfv3 : Turn direction vectors into quaternions interpreted as 3D orientations
rule orientation_field_ccfv3:
    input:
        direction_vectors=rules.direction_vectors_isocortex_ccfv3.output,
    output:
        f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['cell_orientations_ccfv3']}"
    params:
        app=APPS["atlas-building-tools orientation-field"]
    log:
        f"{LOG_DIR}/orientation_field_ccfv3.log"
    shell:
        """
        {params.app} --direction-vectors-path {input.direction_vectors} \
            --output-path {output} \
            2>&1 | tee {log}
        """

##>orientation_field_hybrid : Turn direction vectors into quaternions interpreted as 3D orientations
rule orientation_field_hybrid:
    input:
        direction_vectors=rules.direction_vectors_isocortex_hybrid.output,
    output:
        f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['cell_orientations_hybrid']}"
    params:
        app=APPS["atlas-building-tools orientation-field"]
    log:
        f"{LOG_DIR}/orientation_field_hybrid.log"
    shell:
        """
        {params.app} --direction-vectors-path {input.direction_vectors} \
            --output-path {output} \
            2>&1 | tee {log}
        """


##>placement_hints_isocortex_ccfv3_l23split : Generate and save the placement hints of different regions of the AIBS mouse brain
rule placement_hints_isocortex_ccfv3_l23split:
    input:
        parcellation_volume=rules.split_isocortex_layer_23_ccfv3.output.annotation_l23split,
        hierarchy=rules.split_isocortex_layer_23_ccfv3.output.hierarchy_l23split,
        direction_vectors=rules.direction_vectors_isocortex_ccfv3.output
    output:
        directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['placement_hints_ccfv3_l23split']}")
    params:
        app=APPS["atlas-building-tools placement-hints isocortex"],
        derivation = PROVENANCE_METADATA["derivations"].update({"placement_hints_ccfv3_l23split": "annotation_ccfv3_l23split"})
    log:
        f"{LOG_DIR}/placement_hints_isocortex_ccfv3_l23split.log"
    shell:
        """
        {params.app} --annotation-path {input.parcellation_volume} \
            --hierarchy-path {input.hierarchy} \
            --direction-vectors-path {input.direction_vectors} \
            --output-dir {output} \
            --algorithm voxel-based \
            2>&1 | tee {log}
        """


## =========================================================================================
## ============================== CELL DENSITY PIPELINE PART 2 =============================
## =========================================================================================

##======== Optimized inhibitory neuron densities and mtypes ========


##>compile_densities_measurements : Compile the cell density related measurements of mmc3.xlsx and `gaba_papers.xsls` into a CSV file.
rule compile_densities_measurements:
    output:
        measurements_csv = f"{WORKING_DIR}/measurements.csv",
        homogenous_regions_csv = f"{WORKING_DIR}/homogenous_regions.csv"
    params:
        app=APPS["atlas-building-tools cell-densities compile-measurements"]
    log:
        f"{LOG_DIR}/compile_densities_measurements.log"
    shell:
        """
        {params.app} --measurements-output-path {output.measurements_csv} \
            --homogenous-regions-output-path {output.homogenous_regions_csv} \
            2>&1 | tee {log}
        """

        
##>average_densities_ccfv2 : Compute cell densities based on measurements and AIBS region volumes.
rule average_densities_ccfv2:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.fetch_brain_parcellation_ccfv2.output,
        overall_cell_density = rules.cell_density_ccfv2.output,
        neuron_density = rules.glia_cell_densities_ccfv2.output.neuron_density,
        measurements_csv = rules.compile_densities_measurements.output.measurements_csv,
    output:
        f"{WORKING_DIR}/average_cell_densities_ccfv2.csv"
    params:
        app=APPS["atlas-building-tools cell-densities measurements-to-average-densities"]
    log:
        f"{LOG_DIR}/average_densities_ccfv2.log"
    shell:
        """
        {params.app} --hierarchy-path {input.hierarchy} \
            --annotation-path {input.parcellation_volume} \
            --cell-density-path {input.overall_cell_density} \
            --neuron-density-path {input.neuron_density} \
            --measurements-path {input.measurements_csv} \
            --output-path {output} \
            2>&1 | tee {log}
        """
        
##>average_densities_ccfv2_correctednissl : Compute cell densities based on measurements and AIBS region volumes.
rule average_densities_ccfv2_correctednissl:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.fetch_brain_parcellation_ccfv2.output,
        overall_cell_density = rules.cell_density_ccfv2_correctednissl.output,
        neuron_density = rules.glia_cell_densities_ccfv2_correctednissl.output.neuron_density,
        measurements_csv = rules.compile_densities_measurements.output.measurements_csv,
    output:
        f"{WORKING_DIR}/average_cell_densities_ccfv2_correctednissl.csv"
    params:
        app=APPS["atlas-building-tools cell-densities measurements-to-average-densities"]
    log:
        f"{LOG_DIR}/average_densities_ccfv2_correctednissl.log"
    shell:
        """
        {params.app} --hierarchy-path {input.hierarchy} \
            --annotation-path {input.parcellation_volume} \
            --cell-density-path {input.overall_cell_density} \
            --neuron-density-path {input.neuron_density} \
            --measurements-path {input.measurements_csv} \
            --output-path {output} \
            2>&1 | tee {log}
        """

        
##>fit_average_densities_ccfv2 : Estimate average cell densities of brain regions.
rule fit_average_densities_ccfv2:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.fetch_brain_parcellation_ccfv2.output,
        neuron_density = rules.glia_cell_densities_ccfv2.output.neuron_density,
        average_densities =rules.average_densities_ccfv2.output,
        gene_config = f"{AVERAGE_DENSITIES_CONFIG_FILE}",
        homogenous_regions_csv = f"{WORKING_DIR}/homogenous_regions.csv"
    output:
        fitted_densities = f"{WORKING_DIR}/fitted_densities_ccfv2.csv",
        fitting_maps = f"{WORKING_DIR}/fitting_maps_ccfv2.json"
    params:
        app=APPS["atlas-building-tools cell-densities fit-average-densities"]
    log:
        f"{LOG_DIR}/fit_average_densities_ccfv2.log"
    shell:
        """
        {params.app} --hierarchy-path {input.hierarchy} \
            --annotation-path {input.parcellation_volume} \
            --average-densities-path {input.average_densities} \
            --neuron-density-path {input.neuron_density} \
            --gene-config-path {input.gene_config} \
            --homogenous-regions-path {input.homogenous_regions_csv} \
            --fitted-densities-output-path {output.fitted_densities} \
            --fitting-maps-output-path {output.fitting_maps} \
            2>&1 | tee {log}
        """
        
##>fit_average_densities_ccfv2_correctednissl : Estimate average cell densities of brain regions.
rule fit_average_densities_ccfv2_correctednissl:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.fetch_brain_parcellation_ccfv2.output,
        neuron_density = rules.glia_cell_densities_ccfv2_correctednissl.output.neuron_density,
        average_densities =rules.average_densities_ccfv2_correctednissl.output,
        gene_config = f"{AVERAGE_DENSITIES_CORRECTEDNISSL_CONFIG_FILE}",
        homogenous_regions_csv = f"{WORKING_DIR}/homogenous_regions.csv"
    output:
        fitted_densities = f"{WORKING_DIR}/fitted_densities_ccfv2_correctednissl.csv",
        fitting_maps = f"{WORKING_DIR}/fitting_maps_ccfv2_correctednissl.json"
    params:
        app=APPS["atlas-building-tools cell-densities fit-average-densities"]
    log:
        f"{LOG_DIR}/fit_average_densities_ccfv2_correctednissl.log"
    shell:
        """
        {params.app} --hierarchy-path {input.hierarchy} \
            --annotation-path {input.parcellation_volume} \
            --average-densities-path {input.average_densities} \
            --neuron-density-path {input.neuron_density} \
            --gene-config-path {input.gene_config} \
            --homogenous-regions-path {input.homogenous_regions_csv} \
            --fitted-densities-output-path {output.fitted_densities} \
            --fitting-maps-output-path {output.fitting_maps} \
            2>&1 | tee {log}
        """

##>inhibitory_neuron_densities_linprog_ccfv2_correctednissl : Create inhibitory neuron densities for the cell types in the csv file containing the fitted densities. Use algorithm 'lingprog'.
rule inhibitory_neuron_densities_linprog_ccfv2_correctednissl:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.fetch_brain_parcellation_ccfv2.output,
        neuron_density = rules.glia_cell_densities_ccfv2_correctednissl.output.neuron_density,
        average_densities = rules.fit_average_densities_ccfv2_correctednissl.output.fitted_densities,
    output:
        directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['inhibitory_neuron_densities_linprog_ccfv2_correctednissl']}")
    params:
        app=APPS["atlas-building-tools cell-densities inhibitory-neuron-densities"]
    log:
        f"{LOG_DIR}/inhibitory_neuron_densities_linprog_ccfv2_correctednissl.log"
    shell:
        """
        {params.app} --hierarchy-path {input.hierarchy} \
            --annotation-path {input.parcellation_volume} \
            --neuron-density-path {input.neuron_density} \
            --average-densities-path {input.average_densities} \
            --algorithm linprog \
            --output-dir {output} \
            2>&1 | tee {log}
        """

##>inhibitory_neuron_densities_preserveprop_ccfv2_correctednissl : Create inhibitory neuron densities for the cell types in the csv file containing the fitted densities. Use algorithm 'keep-proportions'.
rule inhibitory_neuron_densities_preserveprop_ccfv2_correctednissl:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.fetch_brain_parcellation_ccfv2.output,
        neuron_density = rules.glia_cell_densities_ccfv2_correctednissl.output.neuron_density,
        average_densities = rules.fit_average_densities_ccfv2_correctednissl.output.fitted_densities,
    output:
        directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['inhibitory_neuron_densities_preserveprop_ccfv2_correctednissl']}")
    params:
        app=APPS["atlas-building-tools cell-densities inhibitory-neuron-densities"]
    log:
        f"{LOG_DIR}/inhibitory_neuron_densities_preserveprop_ccfv2_correctednissl.log"
    shell:
        """
        {params.app} --hierarchy-path {input.hierarchy} \
            --annotation-path {input.parcellation_volume} \
            --neuron-density-path {input.neuron_density} \
            --average-densities-path {input.average_densities} \
            --algorithm keep-proportions \
            --output-dir {output} \
            2>&1 | tee {log}
        """

##>create_mtypes_densities_from_profile_ccfv2_correctednissl : Create neuron density nrrd files for the mtypes listed in the mapping tsv file.
rule create_mtypes_densities_from_profile_ccfv2_correctednissl:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.fetch_brain_parcellation_ccfv2.output,
        metadata_file = f"{rules_config_dir}/isocortex_metadata.json",
        direction_vectors=rules.interpolate_direction_vectors_isocortex_ccfv2.output,
        mtypes_config = f"{MTYPES_PROFILE_CCFV2_CORRECTEDNISSL_CONFIG_}",
    output:
        directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['mtypes_densities_profile_ccfv2_correctednissl']}")
    params:
        app=APPS["atlas-building-tools mtype-densities create-from-profile"]
    log:
        f"{LOG_DIR}/create_mtypes_densities_from_profile_ccfv2_correctednissl.log"
    shell:
        """
        {params.app} --hierarchy-path {input.hierarchy} \
            --annotation-path {input.parcellation_volume} \
            --metadata-path {input.metadata_file} \
            --direction-vectors-path {input.direction_vectors} \
            --mtypes-config-path {input.mtypes_config} \
            --output-dir {output} \
            2>&1 | tee {log}
        """
        
##>create_mtypes_densities_from_probability_map_ccfv2_correctednissl : Create neuron density nrrd files for the mtypes listed in the probability mapping csv file.
rule create_mtypes_densities_from_probability_map_ccfv2_correctednissl:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.fetch_brain_parcellation_ccfv2.output,
        metadata_file = f"{rules_config_dir}/isocortex_23_metadata.json",
        mtypes_config = f"{MTYPES_PROBABILITY_MAP_CORRECTEDNISSL_CONFIG_}",
    output:
        directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['mtypes_densities_probability_map_ccfv2_correctednissl']}")
    params:
        app=APPS["atlas-building-tools mtype-densities create-from-probability-map"]
    log:
        f"{LOG_DIR}/create_mtypes_densities_from_probability_map_ccfv2_correctednissl.log"
    shell:
        """
        {params.app} --hierarchy-path {input.hierarchy} \
            --annotation-path {input.parcellation_volume} \
            --metadata-path {input.metadata_file} \
            --mtypes-config-path {input.mtypes_config} \
            --output-dir {output} \
            2>&1 | tee {log}
        """

## =========================================================================================
## ======================== EXPORT MASKS,MESHES,SUMMARIES,CELLRECORDS ======================
## =========================================================================================

##>export_brain_region_ccfv3_l23split : export a mesh, a volumetric mask and a region summary json file for every brain region available in the ccfv3 isocortex layer 2-3 split brain parcellation volume. Create a hierarchy JSONLD file from the input hierarchy JSON file as well. Note: not only the leaf regions are exported but also the above regions that are combinaisons of leaves
rule export_brain_region_ccfv3_l23split:
    input:
        hierarchy=rules.split_isocortex_layer_23_ccfv3.output.hierarchy_l23split,
        parcellation_volume=rules.split_isocortex_layer_23_ccfv3.output.annotation_l23split
    output:
        mesh_dir = directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['MeshFile']['brain_region_meshes_ccfv3_l23split']}"),
        mask_dir = directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['brain_region_mask_ccfv3_l23split']}"),
        json_metadata_parcellations = f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['MetadataFile']['metadata_parcellations_ccfv3_l23split']}",
        hierarchy_jsonld = f"{PUSH_DATASET_CONFIG_FILE['HierarchyJson']['mba_hierarchy_l23split']}"
    params:
        app=APPS["parcellationexport"],
    log:
        f"{LOG_DIR}/export_brain_region_ccfv3_l23split.log"
    shell:
        """
        {params.app} --hierarchy {input.hierarchy} \
            --parcellation-volume {input.parcellation_volume} \
            --out-mesh-dir {output.mesh_dir} \
            --out-mask-dir {output.mask_dir} \
            --out-metadata {output.json_metadata_parcellations} \
            --out-hierarchy-jsonld {output.hierarchy_jsonld} \
            2>&1 | tee {log}
        """


##>cell_records : Generate 3D cell records for the whole mouse brain and save them with the orientations and the region_ID in an hdf5 file. OUTDATED
rule cell_records:
    input:
        parcellation_volume = rules.combine_annotations.output,
        orientation_file = rules.orientation_field_hybrid.output,
        glia_densities = rules.glia_cell_densities_hybrid.output,
        neuron_densities = rules.inhibitory_excitatory_neuron_densities_hybrid.output,
        cell_densities_config_file = f"{CELL_POSITIONS_HYBRID_CONFIG_FILE}"
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

## =========================================================================================
## ====================== ANNOTATION PIPELINE DATASET INTEGRITY CHECK ======================
## =========================================================================================


##>check_annotation_pipeline_volume_datasets : Check the integrity of the .nrrd volumetric datasets generated by the annotation pipeline
rule check_annotation_pipeline_volume_datasets:
    input:
        annotation_ccfv3_split=rules.split_isocortex_layer_23_ccfv3.output.annotation_l23split,
        direction_vectors_ccfv3=rules.direction_vectors_isocortex_ccfv3.output,
        orientation_ccfv3=rules.orientation_field_ccfv3.output,
        placement_hints_ccfv3_split=rules.placement_hints_isocortex_ccfv3_l23split.output,
        mask_ccfv3_split=rules.export_brain_region_ccfv3_l23split.output.mask_dir
    output:
        f"{WORKING_DIR}/data_check_report/report_volumetric_nrrd.json"
    params:
        app=APPS["bba-data-integrity-check nrrd-integrity"]
    log:
        f"{LOG_DIR}/check_annotation_pipeline_volume_datasets.log"
    shell:
        """
        {params.app} --input-dataset {input.annotation_ccfv3_split} \
            --input-dataset {input.orientation_ccfv3} \
            --input-dataset {input.direction_vectors_ccfv3} \
            --input-dataset {input.placement_hints_ccfv3_split} \
            --input-dataset {input.mask_ccfv3_split} \
            --report-path {output} \
            2>&1 | tee {log}
        """


##>check_annotation_pipeline_mesh_datasets : Check the integrity of the annotation pipeline mesh datasets
rule check_annotation_pipeline_mesh_datasets:
    input:
        mesh_ccfv3_split=rules.export_brain_region_ccfv3_l23split.output.mesh_dir
    output:
        f"{WORKING_DIR}/data_check_report/report_obj_brain_meshes.json"
    params:
        app=APPS["bba-data-integrity-check meshes-obj-integrity"]
    log:
        f"{LOG_DIR}/check_annotation_pipeline_mesh_datasets.log"
    shell:
        """
        {params.app} --input-dataset {input.mesh_ccfv3_split} \
            --report-path {output} \
            2>&1 | tee {log}
        """


##>check_annotation_pipeline : Verify that the report files generated by the module verifying the annotation pipeline datasets integrity do not contain any issues before starting to push datasets into Nexus. These are contained in the folder data_check_report.
rule check_annotation_pipeline:
    priority: 10
    input:
        nrrd_report = rules.check_annotation_pipeline_volume_datasets.output,
        obj_report = rules.check_annotation_pipeline_mesh_datasets.output,
    output:
        touch(f"{WORKING_DIR}/data_check_report/report_valid.txt")
    log:
        f"{LOG_DIR}/check_annotation_pipeline.log"
    run:
        with open(log[0], "w") as logfile:
            report_files = input
            for f in report_files:
                report_file = open(f,'r')
                report_json = json.load(report_file)
                for k in report_json.keys():
                    if not report_json[k]['success'] == 'true':
                        logfile.write(f"The report file '{f}' contains errors:"\ 
                                      "All the data_check_report need to show valid dataset or else those "\
                                      "will not be pushed in Nexus.")
                        L.error(f"The report file '{f}' contains errors")
                        exit(1)
                report_file.close()
            logfile.write(f"All report files show successful datasets integrity check.\nUpdating '{output}'")


## =========================================================================================
## ============================= ANNOTATION PIPELINE USER RULES ============================
## =========================================================================================


##>generate_annotation_pipeline_datasets : Global rule to generate and check the integrity of every products of the annotation pipeline
rule generate_annotation_pipeline_datasets:
    input:
        all_datasets = rules.check_annotation_pipeline.output,


##>push_annotation_pipeline_datasets : Global rule to generate, check and push into Nexus every products of the annotation pipeline.
rule push_annotation_pipeline_datasets:
    input:
        all_datasets = rules.check_annotation_pipeline.output,
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        hierarchy_jsonld=rules.export_brain_region_ccfv3_l23split.output.hierarchy_jsonld,
        brain_template=rules.fetch_brain_template.output,
        annotation_ccfv3_split=rules.split_isocortex_layer_23_ccfv3.output.annotation_l23split,
        mask=rules.export_brain_region_ccfv3_l23split.output.mask_dir,
        mesh=rules.export_brain_region_ccfv3_l23split.output.mesh_dir,
        metadata=rules.export_brain_region_ccfv3_l23split.output.json_metadata_parcellations,
        placement_hints_ccfv3_split =rules.placement_hints_isocortex_ccfv3_l23split.output,
        direction_vectors_ccfv3 =rules.direction_vectors_isocortex_ccfv3.output,
        orientation_field_ccfv3=rules.orientation_field_ccfv3.output,
        push_dataset_config = f"{rules_config_dir}/push_dataset_config.yaml",
    output:
        link_regions = f"{WORKING_DIR}/link_regions_path.json",
        touch = temp(touch(f"{WORKING_DIR}/push_annotation_pipeline_datasets_success.txt"))
    params:
        app1=APPS["bba-data-push push-volumetric"].split(),
        app2=APPS["bba-data-push push-meshes"].split(),
        app3=APPS["bba-data-push push-regionsummary"].split(),
        token = myTokenFetcher.getAccessToken(),
        create_provenance_json = write_json(PROVENANCE_METADATA_PATH, PROVENANCE_METADATA, rule_name = "push_annotation_pipeline_datasets"),
        resource_tag = RESOURCE_TAG
    log:
        f"{LOG_DIR}/push_annotation_pipeline_datasets.log"
    shell:
        """
        {params.app1[0]} --forge-config-file {FORGE_CONFIG} \
            --nexus-env {NEXUS_DESTINATION_ENV} \
            --nexus-org {NEXUS_DESTINATION_ORG} \
            --nexus-proj {NEXUS_DESTINATION_PROJ} \
            --nexus-token {params.token} \
        {params.app1[1]} --dataset-path {input.annotation_ccfv3_split} \
            --dataset-path {input.brain_template} \
            --dataset-path {input.mask} \
            --dataset-path {input.orientation_field_ccfv3} \
            --dataset-path {input.direction_vectors_ccfv3} \
            --hierarchy-path {input.hierarchy} \
            --hierarchy-jsonld-path {input.hierarchy_jsonld} \
            --atlasrelease-config-path {ATLAS_CONFIG_PATH} \
            --config-path {input.push_dataset_config} \
            --link-regions-path {output.link_regions} \
            --provenance-metadata-path {PROVENANCE_METADATA_PATH} \
            --resource-tag {params.resource_tag} ;
        {params.app2[0]} --forge-config-file {FORGE_CONFIG} \
            --nexus-env {NEXUS_DESTINATION_ENV} \
            --nexus-org {NEXUS_DESTINATION_ORG} \
            --nexus-proj {NEXUS_DESTINATION_PROJ} \
            --nexus-token {params.token} \
        {params.app2[1]} --dataset-path {input.mesh} \
            --hierarchy-path {input.hierarchy} \
            --hierarchy-jsonld-path {input.hierarchy_jsonld} \
            --config-path {input.push_dataset_config} \
            --link-regions-path {output.link_regions} \
            --atlasrelease-config-path {ATLAS_CONFIG_PATH} \
            --provenance-metadata-path {PROVENANCE_METADATA_PATH} \
            --resource-tag {params.resource_tag} ;
        {params.app3[0]} --forge-config-file {FORGE_CONFIG} \
            --nexus-env {NEXUS_DESTINATION_ENV} \
            --nexus-org {NEXUS_DESTINATION_ORG} \
            --nexus-proj {NEXUS_DESTINATION_PROJ} \
            --nexus-token {params.token} \
        {params.app3[1]} --dataset-path {input.metadata} \
            --hierarchy-path {input.hierarchy} \
            --hierarchy-jsonld-path {input.hierarchy_jsonld} \
            --config-path {input.push_dataset_config} \
            --atlasrelease-config-path {ATLAS_CONFIG_PATH} \
            --link-regions-path {output.link_regions} \
            --provenance-metadata-path {PROVENANCE_METADATA_PATH} \
            --resource-tag {params.resource_tag} \
            2>&1 | tee {log}
        """
