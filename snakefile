##
## Snakemake - Cell Atlas Pipeline
##
## nabil.alibou@epfl.ch
## jonathan.lurie@epfl.ch
## leonardo.cristella@epfl.ch
##

import os
from datetime import datetime
import fnmatch
import subprocess
import shutil
import json
import yaml
import re
import logging
import sysconfig
from copy import deepcopy
from uuid import uuid4
# from importlib.metadata import distribution
from platform import python_version
from snakemake.logging import logger as L
from kgforge.core import KnowledgeGraphForge
from blue_brain_token_fetch.token_fetcher_user import TokenFetcherUser
from blue_brain_token_fetch.token_fetcher_service import TokenFetcherService

# Loading the config
configfile: "config.yaml"

# Placing the config values into local variables
WORKING_DIR = config["WORKING_DIR"]
REPO_PATH = config["REPO_PATH"]
KEYCLOAK_CONFIG = os.path.join(REPO_PATH, config["KEYCLOAK_CONFIG"])
TOKEN_USERNAME = config["TOKEN_USERNAME"]
TOKEN_PASSWORD = config["TOKEN_PASSWORD"]
SERVICE_TOKEN = config["SERVICE_TOKEN"]
NEXUS_IDS_FILE = os.path.join(REPO_PATH, config["NEXUS_IDS_FILE"])
FORGE_CONFIG = os.path.join(os.getcwd(), REPO_PATH, config["FORGE_CONFIG"])
RULES_CONFIG_DIR_TEMPLATES = os.path.join(REPO_PATH, config["RULES_CONFIG_DIR_TEMPLATES"])
RESOLUTION = str(config["RESOLUTION"])
DISPLAY_HELP = config["DISPLAY_HELP"]
RESOURCE_TAG = config["RESOURCE_TAG"]
NEXUS_REGISTRATION = config["NEXUS_REGISTRATION"]
NEW_ATLAS = config["NEW_ATLAS"]
EXPORT_MESHES = config["EXPORT_MESHES"]
PROVENANCE_METADATA_V2_PATH = f"{WORKING_DIR}/provenance_metadata_v2.json"
PROVENANCE_METADATA_V3_PATH = f"{WORKING_DIR}/provenance_metadata_v3.json"
METADATA_PATH = os.path.join(REPO_PATH, "metadata") if REPO_PATH != "." else "metadata"

IS_PROD_ENV = config["IS_PROD_ENV"]
if IS_PROD_ENV:
    env = "prod"
    NEXUS_ATLAS_ENV = config["NEXUS_PROD_ENV"]
    NEXUS_DESTINATION_ENV = config["NEXUS_PROD_ENV"]
else:
    env = "staging"
    NEXUS_ATLAS_ENV = config["NEXUS_STAGING_ENV"]
    NEXUS_DESTINATION_ENV = config["NEXUS_STAGING_ENV"]

ATLAS_RELEASE_NAME = config["ATLAS_RELEASE_NAME"]
ATLAS_RELEASE_DESC = config["ATLAS_RELEASE_DESCRIPTION"]

NEXUS_ATLAS_ORG = config["NEXUS_ATLAS_ORG"]
NEXUS_ATLAS_PROJ = config["NEXUS_ATLAS_PROJ"]
NEXUS_ONTOLOGY_ORG = config["NEXUS_ONTOLOGY_ORG"]
NEXUS_ONTOLOGY_PROJ = config["NEXUS_ONTOLOGY_PROJ"]

NEXUS_DESTINATION_ORG = config["NEXUS_DESTINATION_ORG"]
NEXUS_DESTINATION_PROJ = config["NEXUS_DESTINATION_PROJ"]
NEXUS_DESTINATION_BUCKET = "/".join([NEXUS_DESTINATION_ORG, NEXUS_DESTINATION_PROJ])

CELL_COMPOSITION_NAME = config["CELL_COMPOSITION_NAME"]
CELL_COMPOSITION_SUMMARY_NAME = config["CELL_COMPOSITION_SUMMARY_NAME"]
CELL_COMPOSITION_VOLUME_NAME = config["CELL_COMPOSITION_VOLUME_NAME"]

VERSION_FILE = os.path.join(WORKING_DIR, "versions.txt")

nexus_dryrun = not NEXUS_REGISTRATION
if nexus_dryrun:
    L.info("This is a Nexus dryrun execution, no data will be pushed in Nexus")

L.info(f"Executing pipeline with {workflow.cores} cores (snakemake option '--cores')")

if not os.path.exists(WORKING_DIR):
    try:
        os.mkdir(WORKING_DIR)
        L.info(f"folder '{WORKING_DIR}' created")
    except OSError:
        L.error(f"creation of the directory {WORKING_DIR} failed")

# Create logs directory
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
logfile = os.path.abspath(os.path.join(
    snakemake_run_logs,
    datetime.now().isoformat().replace(":", "-") + ".log"))
logfile_handler = logging.FileHandler(logfile)
L.logger.addHandler(logfile_handler)

if NEW_ATLAS:
    print("\nYou requested a new atlas release\n")

# All the apps must be listed here so that we can fetch all the versions
APPS = {
    "bba-data-fetch": "bba-data-fetch",
    "parcellationexport": "parcellationexport",
    "atlas-building-tools combination combine-v2-annotations": "atlas-densities combination combine-ccfv2-annotations",
    "atlas-building-tools combination combine-v2v3-annotations": "atlas-densities combination combine-v2-v3-annotations",
    "atlas-building-tools combination combine-markers": "atlas-densities combination combine-markers",
    "atlas-building-tools cell-densities cell-density": "atlas-densities cell-densities cell-density",
    "atlas-building-tools cell-densities glia-cell-densities": "atlas-densities cell-densities glia-cell-densities",
    "atlas-building-tools cell-densities inhibitory-and-excitatory-neuron-densities": "atlas-densities cell-densities inhibitory-and-excitatory-neuron-densities",
    "atlas-densities cell-densities excitatory-split": "atlas-densities cell-densities excitatory-split",
    "atlas-building-tools cell-densities measurements-to-average-densities": "atlas-densities cell-densities measurements-to-average-densities",
    "atlas-building-tools cell-densities fit-average-densities": "atlas-densities cell-densities fit-average-densities",
    "atlas-building-tools cell-densities inhibitory-neuron-densities": "atlas-densities cell-densities inhibitory-neuron-densities",
    "atlas-building-tools mtype-densities create-from-profile": "atlas-densities mtype-densities create-from-profile",
    "atlas-building-tools mtype-densities create-from-probability-map": "atlas-densities mtype-densities create-from-probability-map",
    "celltransplant": "celltransplant",
    "brainbuilder cells positions-and-orientations": "brainbuilder cells positions-and-orientations",
    "atlas-direction-vectors direction-vectors from-center": "atlas-direction-vectors direction-vectors from-center",
    "atlas-building-tools direction-vectors isocortex": "atlas-direction-vectors direction-vectors isocortex",
    "atlas-building-tools direction-vectors cerebellum": "atlas-direction-vectors direction-vectors cerebellum",
    "atlas-building-tools direction-vectors interpolate": "atlas-direction-vectors direction-vectors interpolate",
    "atlas-building-tools orientation-field": "atlas-direction-vectors orientation-field",
    "atlas-building-tools region-splitter split-isocortex-layer-23": "atlas-splitter split-isocortex-layer-23",
    "atlas-splitter split-barrel-columns": "atlas-splitter split-barrel-columns",
    "atlas-building-tools placement-hints isocortex": "atlas-placement-hints isocortex",
    "bba-data-integrity-check nrrd-integrity": "bba-data-integrity-check nrrd-integrity",
    "bba-data-integrity-check meshes-obj-integrity": "bba-data-integrity-check meshes-obj-integrity",
    "bba-data-integrity-check atlas-sonata-integrity": "bba-data-integrity-check atlas-sonata-integrity",
    "bba-data-push push-atlasrelease": "bba-data-push push-atlasrelease",
    "bba-data-push push-volumetric": "bba-data-push push-volumetric",
    "bba-data-push push-meshes": "bba-data-push push-meshes",
    "bba-data-push push-cellrecords": "bba-data-push push-cellrecords",
    "bba-data-push push-regionsummary": "bba-data-push push-regionsummary",
    "bba-data-push push-cellcomposition": "bba-data-push push-cellcomposition"
}

# delete the log of app versions
try:
    os.remove(VERSION_FILE)
except OSError:
    pass

# UNCOMMENT TO CHECK SYSTEMATICALLY EVERY MODULE PRESENCE BEFORE RUNNING THE PIPELINE:
# fetch version of each app and write it down in a file
# #applications = {"applications": {}}
#for app in APPS:

#    app_name_fixed = app.split()[0]

    # first, we need to check if each CLI is in PATH, if not we abort with exit code 1
#    if shutil.which(app_name_fixed) is None:
#        raise Exception(f"The CLI {app_name_fixed} is not installed or not in PATH. Pipeline cannot execute.")
#        exit(1)

    # Slow but simplest way to check every modules regardless of how they have been installed
#    app_version = subprocess.check_output(f"{app_name_fixed} --version", shell=True).decode('ascii').rstrip("\n\r")
#    applications["applications"].update({app: app_version})

#with open(VERSION_FILE, "w") as outfile:
#    outfile.write(json.dumps(applications, indent = 4))

# Reading some Nexus file @id mapping
NEXUS_IDS = json.loads(open(NEXUS_IDS_FILE, 'r').read().strip())

atlas_release_id = NEXUS_IDS["AtlasRelease"][env]
cell_composition_id = NEXUS_IDS["CellComposition"][env]

# Create the rules configuration files from the template configuration files and annotate the data paths they contains
rules_config_dir = os.path.join(WORKING_DIR, "rules_config_dir")

if not os.path.exists(rules_config_dir):
    try:
        os.mkdir(rules_config_dir)
        L.info(f"folder '{rules_config_dir}' created")
    except OSError:
        L.error(f"creation of the directory {rules_config_dir} failed")

# Generate all the configuration yaml files from the template ones located in blue_brain_atlas_pipeline/rules_config_dir_templates
files = os.listdir(RULES_CONFIG_DIR_TEMPLATES)
pattern = "*_template.yaml"
files_list = fnmatch.filter(files, pattern)
for file in files_list:
    template_path = os.path.join(RULES_CONFIG_DIR_TEMPLATES, file)
    rule_config_file_template = open(template_path, "r")
    rule_config_file_name = file.replace('_template', '')
    file_path = os.path.join(rules_config_dir, rule_config_file_name)
    if os.path.isfile(file_path):
        continue
    rule_config_file = open(file_path, "w+")
    rule_config_file.write(re.sub("{WORKING_DIR}", WORKING_DIR, rule_config_file_template.read()))
    rule_config_file_template.close()
    rule_config_file.seek(0)


with open(f"{rules_config_dir}/combine_markers_config.yaml", "r") as file:
    COMBINE_MARKERS_CONFIG_FILE = yaml.safe_load(file.read().strip())

with open(f"{rules_config_dir}/cell_positions_correctednissl_config.yaml", "r") as file:
    CELL_POSITIONS_CORRECTEDNISSL_CONFIG_FILE = yaml.safe_load(file.read().strip())

with open(f"{rules_config_dir}/push_dataset_config.yaml", "r") as file:
    PUSH_DATASET_CONFIG_FILE = yaml.safe_load(file.read().strip())

AVERAGE_DENSITIES_CORRECTEDNISSL_CONFIG_FILE = f"{rules_config_dir}/fit_average_densities_correctednissl_config.yaml"
MTYPES_PROBABILITY_MAP_CORRECTEDNISSL_LINPROG_CONFIG_ = f"{rules_config_dir}/mtypes_probability_map_correctednissl_linprog_config.yaml"

with open(f"{MTYPES_PROBABILITY_MAP_CORRECTEDNISSL_LINPROG_CONFIG_}", "r") as file:
    MTYPES_PROBABILITY_MAP_CORRECTEDNISSL_LINPROG_CONFIG_FILE = yaml.safe_load(file.read().strip())

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
provenance_dict_v2 = {
    "activity_id": f"https://bbp.epfl.ch/neurosciencegraph/data/activity/{str(uuid4())}",
    "softwareagent_name" : "Blue Brain Atlas Annotation Pipeline",
    "software_version": "0.1.0", # later f"{distribution('pipeline').version}" or version.py
    "runtime_platform": f"{sysconfig.get_platform()}",
    "repo_address": "https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline",
    "language": f"python {python_version()}",
    "start_time" : f"{datetime.today().strftime('%Y-%m-%dT%H:%M:%S')}",
    "input_dataset_used": {
        "hierarchy": {
          "id": "http://bbp.epfl.ch/neurosciencegraph/ontologies/mba",
          "type": "ParcellationOntology"
        },
        "brain_parcellation_ccfv2": {
          "id": "",
          "type": "BrainParcellationDataLayer"
        }
    },
    "derivations": {
        #"brain_region_mask_ccfv2_l23split": "annotation_ccfv2_l23split", # no longer produced by default
        "hierarchy_ccfv2_l23split": "hierarchy",
        "annotation_ccfv2_l23split": "brain_parcellation_ccfv2",
        "interpolated_direction_vectors_isocortex_ccfv2": "brain_parcellation_ccfv2",
        "cell_orientations_ccfv2": "direction_vectors_isocortex_ccfv2",
        #"placement_hints_ccfv2_l23split": "annotation_ccfv2_l23split" # not always part of the payload
    }
}

provenance_dict_v3 = {
    "activity_id": f"https://bbp.epfl.ch/neurosciencegraph/data/activity/{str(uuid4())}",
    "softwareagent_name" : "Blue Brain Atlas Annotation Pipeline",
    "software_version": "0.1.0", # later f"{distribution('pipeline').version}" or version.py
    "runtime_platform": f"{sysconfig.get_platform()}",
    "repo_address": "https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline",
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
        #"brain_region_mask_ccfv3_l23split": "annotation_ccfv3_l23split", # no longer produced by default
        "hierarchy_ccfv3_l23split": "hierarchy",
        "annotation_ccfv3_l23split": "brain_parcellation_ccfv3",
        "direction_vectors_isocortex_ccfv3": "brain_parcellation_ccfv3",
        "cell_orientations_ccfv3": "direction_vectors_isocortex_ccfv3",
        #"placement_hints_ccfv3_l23split": "annotation_ccfv3_l23split" # not always part of the payload
    }
}

if not os.path.exists(PROVENANCE_METADATA_V2_PATH):
    write_json(PROVENANCE_METADATA_V2_PATH, provenance_dict_v2)

with open(PROVENANCE_METADATA_V2_PATH, "r+") as provenance_file:
    provenance_file.seek(0)
    PROVENANCE_METADATA_V2 = json.loads(provenance_file.read())

if not os.path.exists(PROVENANCE_METADATA_V3_PATH):
    write_json(PROVENANCE_METADATA_V3_PATH, provenance_dict_v3)

with open(PROVENANCE_METADATA_V3_PATH, "r+") as provenance_file:
    provenance_file.seek(0)
    PROVENANCE_METADATA_V3 = json.loads(provenance_file.read())

help_filepath = os.path.join(WORKING_DIR, "HELP_RULES.txt")
if DISPLAY_HELP:
    try:
        L.info((open(help_filepath, "r")).read())
        os._exit(0)
    except OSError as e:
        L.error(f"{e}. Could not open '{help_filepath}'. Its content can also be accessed by running the 'help' rule.")


##>help : prints help comments for Snakefile
rule help:
    input: os.path.join(REPO_PATH, "snakefile")
    output: help_filepath
    shell:
        """
        sed -n 's/^##//p' {input} \
        | tee {output}
        """


# Launch the automatic token refreshing
if not SERVICE_TOKEN:
    myTokenFetcher = TokenFetcherUser(TOKEN_USERNAME, TOKEN_PASSWORD, keycloak_config_file=KEYCLOAK_CONFIG)
else:
    myTokenFetcher = TokenFetcherService(TOKEN_USERNAME, TOKEN_PASSWORD, keycloak_config_file=KEYCLOAK_CONFIG)

forge = KnowledgeGraphForge(FORGE_CONFIG, bucket = "/".join([NEXUS_ATLAS_ORG, NEXUS_ATLAS_PROJ]),
    endpoint = NEXUS_ATLAS_ENV, token = myTokenFetcher.get_access_token())

default_fetch = """{params.app} \
                    --forge-config {FORGE_CONFIG} \
                    --nexus-env {NEXUS_ATLAS_ENV} --nexus-token {params.token} \
                    --nexus-org {NEXUS_ATLAS_ORG} --nexus-proj {NEXUS_ATLAS_PROJ} \
                    --out {output} --nexus-id {params.nexus_id} \
                    --verbose 2>&1 | tee {log}"""

# -v for logging.INFO, -vv for logging.DEBUG
default_push = """{params.app[0]} \
                  -v \
                  --forge-config-file {FORGE_CONFIG} \
                  --nexus-env {NEXUS_DESTINATION_ENV} \
                  --nexus-org {NEXUS_DESTINATION_ORG} \
                  --nexus-proj {NEXUS_DESTINATION_PROJ} \
                  --nexus-token {params.token}"""

##>fetch_ccf_brain_region_hierarchy : fetch the hierarchy file, originally called 1.json
rule fetch_ccf_brain_region_hierarchy:
    output:
        f"{PUSH_DATASET_CONFIG_FILE['HierarchyJson']['hierarchy']}",
    params:
        nexus_id=NEXUS_IDS["ParcellationOntology"]["allen_mouse_ccf"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token(),
        #derivation = PROVENANCE_METADATA_V2["input_dataset_used"].update({"hierarchy" : {"id":NEXUS_IDS["ParcellationOntology"]["allen_mouse_ccf"], "type":"ParcellationOntology"}})
    log:
        f"{LOG_DIR}/fetch_ccf_brain_region_hierarchy.log"
    shell:
        default_fetch.replace("--nexus-id {params.nexus_id}", "--nexus-id {params.nexus_id}  --favor name:1.json")

orig_hierarchy = rules.fetch_ccf_brain_region_hierarchy.output
root_region_name = "root"
#root_region_name = "Whole mouse brain"

##>fetch_brain_parcellation_ccfv2 : fetch the CCF v2 brain parcellation volume in the given resolution
rule fetch_brain_parcellation_ccfv2:
    output:
        f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['annotation_ccfv2']}"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["BrainParcellationDataLayer"]["brain_ccfv2"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token(),
    log:
        f"{LOG_DIR}/fetch_brain_parcellation_ccfv2.log"
    shell:
        default_fetch

##>fetch_fiber_parcellation_ccfv2 : fetch the CCF v2 fiber parcellation volume in the given resolution
rule fetch_fiber_parcellation_ccfv2:
    output:
        f"{WORKING_DIR}/fiber_parcellation_ccfv2.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["BrainParcellationDataLayer"]["fiber_ccfv2"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_fiber_parcellation_ccfv2.log"
    shell:
        default_fetch

##>fetch_brain_parcellation_ccfv3 : fetch the CCF v3 brain parcellation volume in the given resolution
rule fetch_brain_parcellation_ccfv3:
    output:
        f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['annotation_ccfv3']}"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["BrainParcellationDataLayer"]["brain_ccfv3"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token(),
        derivation = PROVENANCE_METADATA_V2["input_dataset_used"].update({"brain_parcellation_ccfv3" : {"id":NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["BrainParcellationDataLayer"]["brain_ccfv3"], "type":"BrainParcellationDataLayer"}})
    log:
        f"{LOG_DIR}/fetch_brain_parcellation_ccfv3.log"
    shell:
        default_fetch

orig_annotation_v3 = rules.fetch_brain_parcellation_ccfv3.output

brain_template_id = NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["BrainTemplateDataLayer"]["average_template_25"]

##>fetch_brain_template : fetch the CCF v3 brain average template volume in the given resolution
rule fetch_brain_template:
    output:
        f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['average_template_25']}"
    params:
        nexus_id=brain_template_id,
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_brain_template.log"
    shell:
        default_fetch

##>fetch_barrel_positions : fetch barrel columns positions
rule fetch_barrel_positions:
    output:
        f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['barrel_positions_25']}"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["BrainParcellationDataLayer"]["barrel_positions"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_barrel_positions.log"
    shell:
        default_fetch

##>fetch_regions_layers_map : fetch the mapping between brain regions and layers
rule fetch_regions_layers_map:
    output:
        f"{WORKING_DIR}/regions_layers_map.json"
    params:
        nexus_id=NEXUS_IDS["metadata"]["regions_layers_map"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_regions_layers_map.log"
    shell:
        default_fetch


## atlas-densities fetchings

##>fetch_regions_config : fetch configuration of regions groups
rule fetch_regions_config:
    output:
        f"{rules_config_dir}/regions_groups.json"
    params:
        nexus_id=NEXUS_IDS["metadata"]["regions_configuration"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_regions_config.log"
    shell:
        default_fetch

##>fetch_corrected_nissl_stained_volume : fetch the corrected nissl stained volume in the given resolution
rule fetch_corrected_nissl_stained_volume:
    output:
        f"{WORKING_DIR}/nissl_corrected_volume.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["NISSLImageDataLayer"]["corrected_nissl"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_corrected_nissl_stained_volume.log"
    shell:
        default_fetch

##>fetch_annotation_stack_ccfv2_coronal : fetch the CCFv2 annotation coronal image stack stack
rule fetch_annotation_stack_ccfv2_coronal:
    output:
        directory(f"{WORKING_DIR}/annotation_stack_ccfv2_coronal")
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["ImageStack"]["annotation_stack_ccfv2_coronal"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_annotation_stack_ccfv2_coronal.log"
    shell:
        default_fetch.replace("{output}", "{output}.tar.gz").replace("--verbose", "--verbose ; \
            mkdir {output} ; \
            tar xf {WORKING_DIR}/annotation_stack_ccfv2_coronal.tar.gz --directory={output} --strip-components=1 ; \
            rm {WORKING_DIR}/annotation_stack_ccfv2_coronal.tar.gz")

##>fetch_nissl_stack_ccfv2_coronal : fetch the CCFv2 nissl coronal image stack stack
rule fetch_nissl_stack_ccfv2_coronal:
    output:
        directory(f"{WORKING_DIR}/nissl_stack_ccfv2_coronal")
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["ImageStack"]["nissl_stack_ccfv2_coronal"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_nissl_stack_ccfv2_coronal.log"
    shell:
        default_fetch.replace("{output}", "{output}.tar.gz").replace("--verbose", "--verbose ; \
            mkdir {output} ; \
            tar xf {WORKING_DIR}/nissl_stack_ccfv2_coronal.tar.gz --directory={output} --strip-components=1 ; \
            rm {WORKING_DIR}/nissl_stack_ccfv2_coronal.tar.gz")

##>fetch_mapping_cortex_all_to_exc_mtypes : fetch the cortex_all_to_exc_mtypes mapping
rule fetch_mapping_cortex_all_to_exc_mtypes:
    output:
        f"{WORKING_DIR}/mapping_cortex_all_to_exc_mtypes.csv"
    params:
        nexus_id=NEXUS_IDS["metadata"]["mapping_cortex_all_to_exc_mtypes"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token(),
    log:
        f"{LOG_DIR}/fetch_mapping_cortex_all_to_exc_mtypes.log"
    shell:
        default_fetch

##>fetch_probability_map_L1 : fetch the probability mapping for layer 1
rule fetch_probability_map_L1:
    output:
        f"{MTYPES_PROBABILITY_MAP_CORRECTEDNISSL_LINPROG_CONFIG_FILE['L1_probabilityMapPath']}"
    params:
        nexus_id=NEXUS_IDS["metadata"]["probability_map_L1"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token(),
    log:
        f"{LOG_DIR}/fetch_probability_map_L1.log"
    shell:
        default_fetch

##>fetch_probability_map_L23 : fetch the probability mapping for layer 23
rule fetch_probability_map_L23:
    output:
        f"{MTYPES_PROBABILITY_MAP_CORRECTEDNISSL_LINPROG_CONFIG_FILE['L23_probabilityMapPath']}"
    params:
        nexus_id=NEXUS_IDS["metadata"]["probability_map_L23"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token(),
    log:
        f"{LOG_DIR}/fetch_probability_map_L23.log"
    shell:
        default_fetch

##>fetch_probability_map_L4 : fetch the probability mapping for layer 4
rule fetch_probability_map_L4:
    output:
        f"{MTYPES_PROBABILITY_MAP_CORRECTEDNISSL_LINPROG_CONFIG_FILE['L4_probabilityMapPath']}"
    params:
        nexus_id=NEXUS_IDS["metadata"]["probability_map_L4"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token(),
    log:
        f"{LOG_DIR}/fetch_probability_map_L4.log"
    shell:
        default_fetch

##>fetch_probability_map_L5 : fetch the probability mapping for layer 5
rule fetch_probability_map_L5:
    output:
        f"{MTYPES_PROBABILITY_MAP_CORRECTEDNISSL_LINPROG_CONFIG_FILE['L5_probabilityMapPath']}"
    params:
        nexus_id=NEXUS_IDS["metadata"]["probability_map_L5"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token(),
    log:
        f"{LOG_DIR}/fetch_probability_map_L5.log"
    shell:
        default_fetch

##>fetch_probability_map_L6 : fetch the probability mapping for layer 6
rule fetch_probability_map_L6:
    output:
        f"{MTYPES_PROBABILITY_MAP_CORRECTEDNISSL_LINPROG_CONFIG_FILE['L6_probabilityMapPath']}"
    params:
        nexus_id=NEXUS_IDS["metadata"]["probability_map_L6"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token(),
    log:
        f"{LOG_DIR}/fetch_probability_map_L6.log"
    shell:
        default_fetch

##>fetch_probability_map_TH_INH : fetch the probability mapping for inhibitory cells of thalamus region
rule fetch_probability_map_TH_INH:
    output:
        f"{MTYPES_PROBABILITY_MAP_CORRECTEDNISSL_LINPROG_CONFIG_FILE['TH_INH_probabilityMapPath']}"
    params:
        nexus_id=NEXUS_IDS["metadata"]["probability_map_TH_INH"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token(),
    log:
        f"{LOG_DIR}/fetch_probability_map_TH_INH.log"
    shell:
        default_fetch

##>combine_v2_annotations : Generate and save the combined annotation file
rule combine_v2_annotations:
    input:
        brain_ccfv2=rules.fetch_brain_parcellation_ccfv2.output,
        fiber_ccfv2=rules.fetch_fiber_parcellation_ccfv2.output,
    output:
        f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['annotation_v2_withfiber']}"
    params:
        app=APPS["atlas-building-tools combination combine-v2-annotations"]
    log:
        f"{LOG_DIR}/combine_v2_annotations.log"
    shell:
        """
        {params.app} \
            --brain-annotation-ccfv2 {input.brain_ccfv2} \
            --fiber-annotation-ccfv2 {input.fiber_ccfv2} \
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
#        token = myTokenFetcher.get_access_token()
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

##>fetch_gene_gad : fetch the gene expression volume corresponding to the genetic marker gad
rule fetch_gene_gad:
    output:
        f"{WORKING_DIR}/gene_gad.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["gad"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_gene_gad.log"
    shell:
        default_fetch

##>fetch_gene_nrn1 : fetch the gene expression volume corresponding to the genetic marker nrn1
rule fetch_gene_nrn1:
    output:
        f"{WORKING_DIR}/gene_nrn1.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["nrn1"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_gene_nrn1.log"
    shell:
        default_fetch

##>fetch_gene_aldh1l1 : fetch the gene expression volume corresponding to the genetic marker aldh1l1
rule fetch_gene_aldh1l1:
    output:
        f"{COMBINE_MARKERS_CONFIG_FILE['inputGeneVolumePath']['aldh1l1']}"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["aldh1l1"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_gene_aldh1l1.log"
    shell:
        default_fetch

##>fetch_gene_cnp : fetch the gene expression volume corresponding to the genetic marker cnp
rule fetch_gene_cnp:
    output:
        f"{COMBINE_MARKERS_CONFIG_FILE['inputGeneVolumePath']['cnp']}"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["cnp"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_gene_cnp.log"
    shell:
        default_fetch

##>fetch_gene_mbp : fetch the gene expression volume corresponding to the genetic marker mbp
rule fetch_gene_mbp:
    output:
        f"{COMBINE_MARKERS_CONFIG_FILE['inputGeneVolumePath']['mbp']}"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["mbp"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_gene_mbp.log"
    shell:
        default_fetch

##>fetch_gene_gfap : fetch the gene expression volume corresponding to the genetic marker gfap
rule fetch_gene_gfap:
    output:
        f"{COMBINE_MARKERS_CONFIG_FILE['inputGeneVolumePath']['gfap']}"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["gfap"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_gene_gfap.log"
    shell:
        default_fetch

##>fetch_gene_s100b : fetch the gene expression volume corresponding to the genetic marker s100b
rule fetch_gene_s100b:
    output:
        f"{COMBINE_MARKERS_CONFIG_FILE['inputGeneVolumePath']['s100b']}"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["s100b"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_gene_s100b.log"
    shell:
        default_fetch

##>fetch_gene_tmem119 : fetch the gene expression volume corresponding to the genetic marker tmem119
rule fetch_gene_tmem119:
    output:
        f"{COMBINE_MARKERS_CONFIG_FILE['inputGeneVolumePath']['tmem119']}"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["tmem119"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_gene_tmem119.log"
    shell:
        default_fetch
        
##>fetch_gene_pv_correctednissl : fetch the gene expression volume corresponding to the genetic marker pv
rule fetch_gene_pv_correctednissl:
    output:
        f"{WORKING_DIR}/gene_pv_correctednissl.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["pv_correctednissl"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_gene_pv_correctednissl.log"
    shell:
        default_fetch
        
##>fetch_gene_sst_correctednissl : fetch the gene expression volume corresponding to the genetic marker sst
rule fetch_gene_sst_correctednissl:
    output:
        f"{WORKING_DIR}/gene_sst_correctednissl.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["sst_correctednissl"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_gene_sst_correctednissl.log"
    shell:
        default_fetch

##>fetch_gene_vip_correctednissl : fetch the gene expression volume corresponding to the genetic marker vip
rule fetch_gene_vip_correctednissl:
    output:
        f"{WORKING_DIR}/gene_vip_correctednissl.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["vip_correctednissl"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_gene_vip_correctednissl.log"
    shell:
        default_fetch

##>fetch_gene_gad67_correctednissl : fetch the gene expression volume corresponding to the genetic marker gad67
rule fetch_gene_gad67_correctednissl:
    output:
        f"{WORKING_DIR}/gene_gad67_correctednissl.nrrd"
    params:
        nexus_id=NEXUS_IDS["VolumetricDataLayer"][RESOLUTION]["GeneExpressionVolumetricDataLayer"]["gad67_correctednissl"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_gene_gad67_correctednissl.log"
    shell:
        default_fetch

##>fetch_genes_correctednissl : fetch all the gene expression volumes
rule fetch_genes_correctednissl:
    input:
        rules.fetch_gene_pv_correctednissl.output,
        rules.fetch_gene_sst_correctednissl.output,
        rules.fetch_gene_vip_correctednissl.output,
        rules.fetch_gene_gad67_correctednissl.output
    output:
        touch(f"{WORKING_DIR}/fetched_genes_correctednissl.log")
    log:
        f"{LOG_DIR}/fetch_genes_correctednissl.log"


##>fetch_isocortex_metadata : fetch isocortex metadata
rule fetch_isocortex_metadata:
    output:
        f"{WORKING_DIR}/isocortex_metadata.json"
    params:
        nexus_id=NEXUS_IDS["metadata"]["isocortex"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_isocortex_metadata.log"
    shell:
        default_fetch

##>fetch_measurements : fetch measurements
rule fetch_measurements:
    output:
        f"{rules_config_dir}/measurements.csv"
    params:
        nexus_id=NEXUS_IDS["metadata"]["measurements"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_measurements.log"
    shell:
        default_fetch

##>fetch_realigned_slices : fetch realigned_slices
rule fetch_realigned_slices:
    output:
        f"{rules_config_dir}/realigned_slices.json"
    params:
        nexus_id=NEXUS_IDS["metadata"]["realigned_slices"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_realigned_slices.log"
    shell:
        default_fetch

##>fetch_std_cells : fetch std_cells
rule fetch_std_cells:
    output:
        f"{rules_config_dir}/std_cells.json"
    params:
        nexus_id=NEXUS_IDS["metadata"]["std_cells"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_std_cells.log"
    shell:
        default_fetch

##>fetch_homogenous_regions : fetch homogenous_regions
rule fetch_homogenous_regions:
    output:
        f"{rules_config_dir}/homogenous_regions.csv"
    params:
        nexus_id=NEXUS_IDS["metadata"]["homogenous_regions"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_homogenous_regions.log"
    shell:
        default_fetch

##>fetch_isocortex_23_metadata : fetch isocortex 23 metadata
rule fetch_isocortex_23_metadata:
    output:
        f"{WORKING_DIR}/isocortex_23_metadata.json"
    params:
        nexus_id=NEXUS_IDS["metadata"]["isocortex_23"],
        app=APPS["bba-data-fetch"],
        token = myTokenFetcher.get_access_token()
    log:
        f"{LOG_DIR}/fetch_isocortex_23_metadata.log"
    shell:
        default_fetch


## =========================================================================================
## =============================== ANNOTATION PIPELINE PART 1.1 ============================
## =========================================================================================

##>direction_vectors_default_ccfv3 : Compute a volume with 3 elements per voxel that are the direction in Euler angles (x, y, z) of the neurons.
rule direction_vectors_default_ccfv3:
    input:
        hierarchy= orig_hierarchy,
        annotation= orig_annotation_v3
    output:
        dir = directory(os.path.dirname(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['direction_vectors_ccfv3']}")),
        file = f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['direction_vectors_ccfv3']}"
    params:
        app=APPS["atlas-direction-vectors direction-vectors from-center"]
    log:
        f"{LOG_DIR}/direction_vectors_default_ccfv3.log"
    shell:
        """{params.app} \
            --hierarchy-path {input.hierarchy} \
            --annotation-path {input.annotation} \
            --region {root_region_name} \
            --output-path {output.file} \
            2>&1 | tee {log}
        """

##>direction_vectors_isocortex_ccfv2 : Compute a volume with 3 elements per voxel that are the direction in Euler angles (x, y, z) of the neurons. This uses Regiodesics under the hood. The output is only for the top regions of the isocortex.
rule direction_vectors_isocortex_ccfv2:
    input:
        annotation=rules.combine_v2_annotations.output,
        hierarchy= orig_hierarchy
    output:
        f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['direction_vectors_isocortex_ccfv2']}"
    params:
        app=APPS["atlas-building-tools direction-vectors isocortex"]
    log:
        f"{LOG_DIR}/direction_vectors_isocortex_ccfv2.log"
    shell:
        """
        {params.app} --annotation-path {input.annotation} \
            --hierarchy-path {input.hierarchy} \
            --output-path {output} \
            --algorithm shading-blur-gradient \
            2>&1 | tee {log}
        """

##>direction_vectors_isocortex_ccfv3 : Compute a volume with 3 elements per voxel that are the direction in Euler angles (x, y, z) of the neurons. This uses Regiodesics under the hood. The output is only for the top regions of the isocortex.
rule direction_vectors_isocortex_ccfv3:
    input:
        annotation= orig_annotation_v3,
        hierarchy= orig_hierarchy
    output:
        f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['direction_vectors_isocortex_ccfv3']}"
    params:
        app=APPS["atlas-building-tools direction-vectors isocortex"]
    log:
        f"{LOG_DIR}/direction_vectors_isocortex_ccfv3.log"
    shell:
        """{params.app} --annotation-path {input.annotation} \
            --hierarchy-path {input.hierarchy} \
            --output-path {output} \
            --algorithm shading-blur-gradient \
            2>&1 | tee {log}
        """

direction_vectors = rules.direction_vectors_default_ccfv3.output.file

##>interpolate_direction_vectors_isocortex_ccfv2 : Interpolate the [NaN, NaN, NaN] direction vectors by non-[NaN, NaN, NaN] ones.
rule interpolate_direction_vectors_isocortex_ccfv2:
    input:
        annotation=rules.combine_v2_annotations.output,
        hierarchy= orig_hierarchy,
        direction_vectors=rules.direction_vectors_isocortex_ccfv2.output,
        metadata = rules.fetch_isocortex_metadata.output
    output:
        f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['interpolated_direction_vectors_isocortex_ccfv2']}"
    params:
        app=APPS["atlas-building-tools direction-vectors interpolate"]
    log:
        f"{LOG_DIR}/interpolate_direction_vectors_isocortex_ccfv2.log"
    shell:
        """
        {params.app} --annotation-path {input.annotation} \
            --hierarchy-path {input.hierarchy} \
            --direction-vectors-path {input.direction_vectors} \
            --metadata-path {input.metadata} \
            --nans \
            --output-path {output} \
            2>&1 | tee {log}
        """

##>interpolate_direction_vectors_isocortex_ccfv3 : Interpolate the [NaN, NaN, NaN] direction vectors by non-[NaN, NaN, NaN] ones.
rule interpolate_direction_vectors_isocortex_ccfv3:
    input:
        annotation= orig_annotation_v3,
        hierarchy= orig_hierarchy,
        direction_vectors=rules.direction_vectors_isocortex_ccfv3.output,
        metadata = rules.fetch_isocortex_metadata.output
    output:
        f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['interpolated_direction_vectors_isocortex_ccfv3']}"
    params:
        app=APPS["atlas-building-tools direction-vectors interpolate"]
    log:
        f"{LOG_DIR}/interpolate_direction_vectors_isocortex_ccfv3.log"
    shell:
        """
        {params.app} --annotation-path {input.annotation} \
            --hierarchy-path {input.hierarchy} \
            --direction-vectors-path {input.direction_vectors} \
            --metadata-path {input.metadata} \
            --nans \
            --output-path {output} \
            2>&1 | tee {log}
        """


default_split = """{params.app} \
                    --hierarchy-path {input.hierarchy} \
                    --annotation-path {input.annotation} \
                    --output-hierarchy-path {output.hierarchy} \
                    --output-annotation-path {output.annotation} \
                    2>&1 | tee {log}"""

##>split_isocortex_layer_23_ccfv2 : Refine ccfv2 annotation by splitting brain regions
rule split_isocortex_layer_23_ccfv2:
    input:
        hierarchy= orig_hierarchy,
        annotation=rules.combine_v2_annotations.output,
        direction_vectors=rules.interpolate_direction_vectors_isocortex_ccfv2.output
    output:
        hierarchy=f"{PUSH_DATASET_CONFIG_FILE['HierarchyJson']['hierarchy_ccfv2_l23split']}",
        annotation=f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['annotation_ccfv2_l23split']}"
    params:
        app=APPS["atlas-building-tools region-splitter split-isocortex-layer-23"]
    log:
        f"{LOG_DIR}/split_isocortex_layer_23_ccfv2.log"
    shell:
        default_split.replace("{params.app}", "{params.app}  --direction-vectors-path {input.direction_vectors}")

##>split_isocortex_layer_23_ccfv3 : Refine ccfv3 annotation by splitting brain regions
rule split_isocortex_layer_23_ccfv3:
    input:
        hierarchy= orig_hierarchy,
        annotation= orig_annotation_v3,
        direction_vectors=rules.direction_vectors_isocortex_ccfv3.output
    output:
        hierarchy=f"{PUSH_DATASET_CONFIG_FILE['HierarchyJson']['hierarchy_ccfv3_l23split']}",
        annotation=f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['annotation_ccfv3_l23split']}"
    params:
        app=APPS["atlas-building-tools region-splitter split-isocortex-layer-23"]
    log:
        f"{LOG_DIR}/split_isocortex_layer_23_ccfv3.log"
    shell:
        default_split.replace("{params.app}", "{params.app}  --direction-vectors-path {input.direction_vectors}")

##>create_leaves_only_hierarchy_annotation_ccfv2 :
rule create_leaves_only_hierarchy_annotation_ccfv2:
    input:
        hierarchy = rules.split_isocortex_layer_23_ccfv2.output.hierarchy,
        annotation = rules.split_isocortex_layer_23_ccfv2.output.annotation
    output:
        hierarchy=f"{PUSH_DATASET_CONFIG_FILE['HierarchyJson']['hierarchy_ccfv2_leaves_only']}",
        annotation=f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['annotation_ccfv2_leaves_only']}"
    log:
        f"{LOG_DIR}/create_leaves_only_hierarchy_annotation_ccfv2.log"
    script:
        "scripts/leaves_only.py"

##>create_leaves_only_hierarchy_annotation_ccfv3 :
rule create_leaves_only_hierarchy_annotation_ccfv3:
    input:
        hierarchy = rules.split_isocortex_layer_23_ccfv3.output.hierarchy,
        annotation = rules.split_isocortex_layer_23_ccfv3.output.annotation
    output:
        hierarchy=f"{PUSH_DATASET_CONFIG_FILE['HierarchyJson']['hierarchy_ccfv3_leaves_only']}",
        annotation=f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['annotation_ccfv3_leaves_only']}"
    log:
        f"{LOG_DIR}/create_leaves_only_hierarchy_annotation_ccfv3.log"
    script:
        "scripts/leaves_only.py"

##>split_barrel_ccfv2_l23split : Refine ccfv2_l23split annotation by splitting barrel regions
rule split_barrel_ccfv2_l23split:
    input:
        hierarchy=rules.create_leaves_only_hierarchy_annotation_ccfv2.output.hierarchy,
        annotation=rules.create_leaves_only_hierarchy_annotation_ccfv2.output.annotation,
        barrel_positions=rules.fetch_barrel_positions.output
    output:
        hierarchy=f"{PUSH_DATASET_CONFIG_FILE['HierarchyJson']['hierarchy_ccfv2_l23split_barrelsplit']}",
        annotation=f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['annotation_ccfv2_l23split_barrelsplit']}"
    params:
        app=APPS["atlas-splitter split-barrel-columns"],
        derivation = PROVENANCE_METADATA_V2["derivations"].update({"hierarchy_ccfv2_l23split_barrelsplit": "hierarchy_ccfv2_l23split"})
    log:
        f"{LOG_DIR}/split_barrel_ccfv2_l23split.log"
    shell:
        default_split.replace("{params.app}", "{params.app}  --barrels-path {input.barrel_positions}")

##>split_barrel_ccfv3_l23split : Refine ccfv3_l23split annotation by splitting barrel regions
rule split_barrel_ccfv3_l23split:
    input:
        hierarchy=rules.create_leaves_only_hierarchy_annotation_ccfv3.output.hierarchy,
        annotation=rules.create_leaves_only_hierarchy_annotation_ccfv3.output.annotation,
        barrel_positions=rules.fetch_barrel_positions.output
    output:
        hierarchy=f"{PUSH_DATASET_CONFIG_FILE['HierarchyJson']['hierarchy_ccfv3_l23split_barrelsplit']}",
        annotation=f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['annotation_ccfv3_l23split_barrelsplit']}"
    params:
        app=APPS["atlas-splitter split-barrel-columns"],
        derivation = PROVENANCE_METADATA_V3["derivations"].update({"hierarchy_ccfv3_l23split_barrelsplit": "hierarchy_ccfv3_l23split"})
    log:
        f"{LOG_DIR}/split_barrel_ccfv3_l23split.log"
    shell:
        default_split.replace("{params.app}", "{params.app}  --barrels-path {input.barrel_positions}")


nrrd_ext = ".nrrd"

##>validate_annotation_v2 : validate CCFv2 annotation
rule validate_annotation_v2:
    input:
        rules.split_barrel_ccfv2_l23split.output.annotation
    output:
        rules.split_barrel_ccfv2_l23split.output.annotation.replace(nrrd_ext, "_validated"+nrrd_ext)
    params:
        os.path.basename(rules.split_barrel_ccfv2_l23split.output.annotation)
    log:
        f"{LOG_DIR}/validate_annotation_v2.log"
    shell:
        """
        densities-validation --annotation {input} \
            2>&1 | tee {log}  && \
        ln -s {params} {output}
        """

##>validate_annotation_v3 : validate CCFv3 annotation
rule validate_annotation_v3:
    input:
        rules.split_barrel_ccfv3_l23split.output.annotation
    output:
        rules.split_barrel_ccfv3_l23split.output.annotation.replace(nrrd_ext, "_validated"+nrrd_ext)
    params:
        os.path.basename(rules.split_barrel_ccfv3_l23split.output.annotation)
    log:
        f"{LOG_DIR}/validate_annotation_v3.log"
    shell:
        """
        densities-validation --annotation {input} \
            2>&1 | tee {log}  && \
        ln -s {params} {output}
        """

# Blue Brain default version (Allen_v3 + layer_2/3_split + leaves_only + barrel_split)
hierarchy_v2 = rules.split_barrel_ccfv2_l23split.output.hierarchy
annotation_v2 = rules.validate_annotation_v2.output
hierarchy_v3 = rules.split_barrel_ccfv3_l23split.output.hierarchy
annotation_v3 = rules.validate_annotation_v3.output


##>create_hemispheres_ccfv3 :
rule create_hemispheres_ccfv3:
    input:
        annotation_v3
    output:
        f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['hemispheres']}"
    log:
        f"{LOG_DIR}/create_hemispheres_ccfv3.log"
    script:
        "scripts/create_hemispheres.py"

##>combine_markers : Generate and save the combined glia files and the global celltype scaling factors
rule combine_markers:
    input:
        aldh1l1 = rules.fetch_gene_aldh1l1.output,
        cnp = rules.fetch_gene_cnp.output,
        mbp = rules.fetch_gene_mbp.output,
        gfap = rules.fetch_gene_gfap.output,
        s100b = rules.fetch_gene_s100b.output,
        tmem119 = rules.fetch_gene_tmem119.output,
        hierarchy = hierarchy_v3,
        annotation = annotation_v3
    output:
        oligodendrocyte_volume = f"{COMBINE_MARKERS_CONFIG_FILE['outputCellTypeVolumePath']['oligodendrocyte']}",
        astrocyte_volume = f"{COMBINE_MARKERS_CONFIG_FILE['outputCellTypeVolumePath']['astrocyte']}",
        microglia_volume = f"{COMBINE_MARKERS_CONFIG_FILE['outputCellTypeVolumePath']['microglia']}",
        glia_volume = f"{COMBINE_MARKERS_CONFIG_FILE['outputOverallGliaVolumePath']}",
        cell_proportion = f"{COMBINE_MARKERS_CONFIG_FILE['outputCellTypeProportionsPath']}"
    params:
        app=APPS["atlas-building-tools combination combine-markers"],
        markers_config_file = f"{rules_config_dir}/combine_markers_config.yaml"
    log:
        f"{LOG_DIR}/combine_markers.log"
    shell:
        """
        {params.app} --hierarchy-path {input.hierarchy} \
            --annotation-path {input.annotation} \
            --config {params.markers_config_file} \
            2>&1 | tee {log}
        """

##>cell_density_correctednissl : Compute the overall mouse brain cell density
rule cell_density_correctednissl:
    input:
        hierarchy = hierarchy_v3,
        annotation = annotation_v3,
        nissl_volume = rules.fetch_corrected_nissl_stained_volume.output,
        regions_config = rules.fetch_regions_config.output
    output:
        f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['overall_cell_density_correctednissl']}"
    params:
        app=APPS["atlas-building-tools cell-densities cell-density"]
    log:
        f"{LOG_DIR}/cell_density_correctednissl.log"
    shell:
        """
        {params.app} --annotation-path {input.annotation} \
            --hierarchy-path {input.hierarchy} \
            --nissl-path {input.nissl_volume} \
            --group-ids-config-path {input.regions_config} \
            --output-path {output} \
            2>&1 | tee {log}
	"""

##>validate_cell_density : validate overall cell density
rule validate_cell_density:
    input:
        annotation = annotation_v3,
        density = rules.cell_density_correctednissl.output
    output:
        rules.cell_density_correctednissl.output[0].replace(nrrd_ext, "_validated"+nrrd_ext)
    params:
        os.path.basename(rules.cell_density_correctednissl.output[0])
    log:
        f"{LOG_DIR}/validate_cell_density.log"
    shell:
        """
        densities-validation --annotation {input.annotation} \
            --cell_density {input.density} \
            2>&1 | tee {log}  && \
        ln -s {params} {output}
        """

overall_cell_density = rules.validate_cell_density.output

##>glia_cell_densities_correctednissl : Compute and save the glia cell densities
rule glia_cell_densities_correctednissl:
    input:
        hierarchy = hierarchy_v3,
        annotation = annotation_v3,
        overall_cell_density = overall_cell_density,
        glia_density = rules.combine_markers.output.glia_volume,
        astro_density = rules.combine_markers.output.astrocyte_volume,
        oligo_density = rules.combine_markers.output.oligodendrocyte_volume,
        microglia_density = rules.combine_markers.output.microglia_volume,
        glia_proportion = rules.combine_markers.output.cell_proportion,
        regions_config = rules.fetch_regions_config.output
    output:
        cell_densities = directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['cell_densities_correctednissl']}"),
        glia_density = f"{CELL_POSITIONS_CORRECTEDNISSL_CONFIG_FILE['inputDensityVolumePath']['glia']}",
        astrocyte_density = f"{CELL_POSITIONS_CORRECTEDNISSL_CONFIG_FILE['inputDensityVolumePath']['astrocyte']}",
        oligodendrocyte_density = f"{CELL_POSITIONS_CORRECTEDNISSL_CONFIG_FILE['inputDensityVolumePath']['oligodendrocyte']}",
        microglia_density = f"{CELL_POSITIONS_CORRECTEDNISSL_CONFIG_FILE['inputDensityVolumePath']['microglia']}",
        neuron_density = f"{CELL_POSITIONS_CORRECTEDNISSL_CONFIG_FILE['inputDensityVolumePath']['neuron']}"
    params:
        app=APPS["atlas-building-tools cell-densities glia-cell-densities"]
    log:
        f"{LOG_DIR}/glia_cell_densities_correctednissl.log"
    shell:
        """
        {params.app} --annotation-path {input.annotation} \
            --hierarchy-path {input.hierarchy} \
            --cell-density-path {input.overall_cell_density} \
            --glia-density-path {input.glia_density} \
            --astrocyte-density-path {input.astro_density} \
            --oligodendrocyte-density-path {input.oligo_density} \
            --microglia-density-path {input.microglia_density} \
            --glia-proportions-path {input.glia_proportion} \
            --group-ids-config-path {input.regions_config} \
            --output-dir {output.cell_densities} \
            2>&1 | tee {log}
        """

validated_cell_densities = "".join([rules.glia_cell_densities_correctednissl.output.cell_densities, "_validated"])

##>validate_neuron_glia_cell_densities : validate neuron and glia densities
# No need to manually create the destination directory of the ln command below because
# snakemake creates it in advance being marked as a "directory" and having more than
# one output
rule validate_neuron_glia_cell_densities:
    input:
        annotation = annotation_v3,
        densities_dir = ancient(rules.glia_cell_densities_correctednissl.output.cell_densities)
    output:
        cell_densities = directory(validated_cell_densities),
        neuron_density = os.path.join(validated_cell_densities, "neuron_density.nrrd")
    params:
        rules.glia_cell_densities_correctednissl.output.cell_densities
    log:
        f"{LOG_DIR}/validate_neuron_glia_cell_densities.log"
    shell:
        """
        densities-validation --annotation {input.annotation} \
            --neuron_glia_density_folder {input.densities_dir} \
            2>&1 | tee {log}  && \
        ln -s -r {params}/* {output.cell_densities}
        """

neuron_glia_densities = rules.validate_neuron_glia_cell_densities.output.cell_densities
neuron_density = rules.validate_neuron_glia_cell_densities.output.neuron_density

##>inhibitory_excitatory_neuron_densities_correctednissl : Compute the inhibitory and excitatory neuron densities
rule inhibitory_excitatory_neuron_densities_correctednissl:
    input:
        hierarchy = hierarchy_v3,
        annotation = annotation_v3,
        gad1_volume = rules.fetch_gene_gad.output,
        nrn1_volume = rules.fetch_gene_nrn1.output,
        neuron_density = neuron_density,
        regions_config = rules.fetch_regions_config.output
    output:
        neuron_densities = directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['neuron_densities_correctednissl']}"),
        inhibitory_neuron_density = f"{CELL_POSITIONS_CORRECTEDNISSL_CONFIG_FILE['inputDensityVolumePath']['inhibitory_neuron']}",
        excitatory_neuron_density = f"{CELL_POSITIONS_CORRECTEDNISSL_CONFIG_FILE['inputDensityVolumePath']['excitatory_neuron']}",
    params:
        app=APPS["atlas-building-tools cell-densities inhibitory-and-excitatory-neuron-densities"]
    log:
        f"{LOG_DIR}/inhibitory_excitatory_neuron_densities_correctednissl.log"
    shell:
        """
        {params.app} --annotation-path {input.annotation} \
            --hierarchy-path {input.hierarchy} \
            --gad1-path {input.gad1_volume} \
            --nrn1-path {input.nrn1_volume} \
            --neuron-density-path {input.neuron_density} \
            --group-ids-config-path {input.regions_config} \
            --output-dir {output.neuron_densities} \
            2>&1 | tee {log}
        """


## =========================================================================================
## =============================== ANNOTATION PIPELINE PART 1.2 ============================
## =========================================================================================

##>orientation_field : Turn direction vectors into quaternions interpreted as 3D orientations
rule orientation_field:
    input:
        direction_vectors = direction_vectors,
    output:
        f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['cell_orientations']}"
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

##>placement_hints : Generate and save the placement hints of different regions of the AIBS mouse brain
rule placement_hints:
    input:
        annotation = annotation_v3,
        hierarchy = hierarchy_v3,
        region_filter = rules.fetch_isocortex_metadata.output,
        direction_vectors = direction_vectors
    output:
        dir = directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['placement_hints']}"),
        metadata = os.path.join(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['placement_hints']}", "metadata.json")
    params:
        app=APPS["atlas-building-tools placement-hints isocortex"],
        files_ext = nrrd_ext,
        region = "Isocortex",
        derivation = PROVENANCE_METADATA_V3["derivations"].update({"placement_hints_ccfv3_l23split": "annotation_ccfv3_l23split"})
    log:
        f"{LOG_DIR}/placement_hints.log"
    script:
        "scripts/placement_hints.py"

## =========================================================================================
## ============================== CELL DENSITY PIPELINE PART 2 =============================
## =========================================================================================

##======== Optimized inhibitory neuron densities and mtypes ========

##>average_densities_correctednissl : Compute cell densities based on measurements and AIBS region volumes.
rule average_densities_correctednissl:
    input:
        hierarchy = hierarchy_v3,
        annotation = annotation_v3,
        overall_cell_density = overall_cell_density,
        neuron_density = neuron_density,
        measurements_csv = rules.fetch_measurements.output,
    output:
        f"{WORKING_DIR}/average_cell_densities_correctednissl.csv"
    params:
        app=APPS["atlas-building-tools cell-densities measurements-to-average-densities"]
    log:
        f"{LOG_DIR}/average_densities_correctednissl.log"
    shell:
        """{params.app} --hierarchy-path {input.hierarchy} \
            --annotation-path {input.annotation} \
            --cell-density-path {input.overall_cell_density} \
            --neuron-density-path {input.neuron_density} \
            --measurements-path {input.measurements_csv} \
            --output-path {output} \
            2>&1 | tee {log}
        """

##>fit_average_densities_correctednissl : Estimate average cell densities of brain regions.
rule fit_average_densities_correctednissl:
    input:
        rules.fetch_genes_correctednissl.output,
        rules.fetch_realigned_slices.output,
        rules.fetch_std_cells.output,
        hierarchy = hierarchy_v3,
        annotation = annotation_v3,
        neuron_density = neuron_density,
        average_densities = rules.average_densities_correctednissl.output,
        gene_config = f"{AVERAGE_DENSITIES_CORRECTEDNISSL_CONFIG_FILE}",
        homogenous_regions_csv = rules.fetch_homogenous_regions.output,
        regions_config = rules.fetch_regions_config.output
    output:
        fitted_densities = f"{WORKING_DIR}/fitted_densities_correctednissl.csv",
        fitting_maps = f"{WORKING_DIR}/fitting_maps_correctednissl.json"
    params:
        app=APPS["atlas-building-tools cell-densities fit-average-densities"]
    log:
        f"{LOG_DIR}/fit_average_densities_correctednissl.log"
    shell:
        """{params.app} --hierarchy-path {input.hierarchy} \
            --region-name {root_region_name} \
            --annotation-path {input.annotation} \
            --average-densities-path {input.average_densities} \
            --neuron-density-path {input.neuron_density} \
            --gene-config-path {input.gene_config} \
            --homogenous-regions-path {input.homogenous_regions_csv} \
            --group-ids-config-path {input.regions_config} \
            --fitted-densities-output-path {output.fitted_densities} \
            --fitting-maps-output-path {output.fitting_maps} \
            2>&1 | tee {log}
        """

##>inhibitory_neuron_densities_linprog_correctednissl : Create inhibitory neuron densities for the cell types in the csv file containing the fitted densities. Use default algorithm 'lingprog'.
rule inhibitory_neuron_densities_linprog_correctednissl:
    input:
        hierarchy = hierarchy_v3,
        annotation = annotation_v3,
        neuron_density = neuron_density,
        average_densities = rules.fit_average_densities_correctednissl.output.fitted_densities,
    output:
        directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['inhibitory_neuron_densities_linprog_correctednissl']}")
    params:
        app=APPS["atlas-building-tools cell-densities inhibitory-neuron-densities"]
    log:
        f"{LOG_DIR}/inhibitory_neuron_densities_linprog_correctednissl.log"
    shell:
        """{params.app} --hierarchy-path {input.hierarchy} \
            --region-name {root_region_name} \
            --annotation-path {input.annotation} \
            --neuron-density-path {input.neuron_density} \
            --average-densities-path {input.average_densities} \
            --algorithm linprog \
            --output-dir {output} \
            2>&1 | tee {log}
        """

##>validate_inhibitory_densities : validate inhibitory densities
rule validate_inhibitory_densities:
    input:
        annotation = annotation_v3,
        density = ancient(rules.inhibitory_neuron_densities_linprog_correctednissl.output),
        hierarchy = hierarchy_v3,
        overall_cell_density = overall_cell_density,
        neuron_glia_densities = ancient(neuron_glia_densities)
    output:
        directory("".join([rules.inhibitory_neuron_densities_linprog_correctednissl.output[0], "_validated"]))
    params:
        os.path.basename(rules.inhibitory_neuron_densities_linprog_correctednissl.output[0])
    log:
        f"{LOG_DIR}/validate_inhibitory_densities.log"
    shell:
        """
        densities-validation --annotation {input.annotation} \
            --inhibitory_density_folder {input.density} \
            --hierarchy {input.hierarchy} \
            --cell_density {input.overall_cell_density} \
            --neuron_glia_density_folder {input.neuron_glia_densities} \
            2>&1 | tee {log}  && \
        ln -s {params} {output}
        """

inhibitory_densities_dir = rules.validate_inhibitory_densities.output[0]

marker_density_map = {
    "gad67": os.path.join(inhibitory_densities_dir, "gad67+_density.nrrd"),
    "vip": os.path.join(inhibitory_densities_dir, "vip+_density.nrrd"),
    "sst": os.path.join(inhibitory_densities_dir, "sst+_density.nrrd"),
    "pv": os.path.join(inhibitory_densities_dir, "pv+_density.nrrd"),
    "lamp5": os.path.join(WORKING_DIR, "lamp5_density.nrrd")
}

# https://github.com/BlueBrain/atlas-densities/commit/db30d0b4c7d6b6356dcf48a766ffd98a18ac9248#commitcomment-124751923
##>compute_lamp5_density : compute lamp5 density from the other marker densities
rule compute_lamp5_density:
    input:
        inhibitory_densities_dir
    params:
        gad67 = marker_density_map["gad67"],
        vip = marker_density_map["vip"],
        sst = marker_density_map["sst"],
        pv = marker_density_map["pv"]
    log:
        f"{LOG_DIR}/compute_lamp5_density.log"
    output:
        marker_density_map["lamp5"]
    script:
        "scripts/compute_lamp5.py"

##>excitatory_split : Subdivide excitatory files into pyramidal subtypes
rule excitatory_split:
    input:
        inhibitory_densities_dir,
        hierarchy = hierarchy_v3,
        annotation = annotation_v3,
        neuron_density = neuron_density,
        mapping_cortex_all_to_exc_mtypes = rules.fetch_mapping_cortex_all_to_exc_mtypes.output,
        metadata = rules.fetch_isocortex_metadata.output
    output:
        directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['excitatory_split']}")
    params:
        app=APPS["atlas-densities cell-densities excitatory-split"]
    log:
        f"{LOG_DIR}/excitatory_split.log"
    shell:
        """
        {params.app} --annotation-path {input.annotation} \
            --hierarchy-path {input.hierarchy} \
            --neuron-density {input.neuron_density} \
            --inhibitory-density """ + marker_density_map["gad67"] + """ \
            --cortex-all-to-exc-mtypes {input.mapping_cortex_all_to_exc_mtypes} \
            --metadata-path {input.metadata} \
            --output-dir {output} \
            2>&1 | tee {log}
        """

##>validate_excitatory_ME_densities : validate excitatory ME densities
rule validate_excitatory_ME_densities:
    input:
        annotation = annotation_v3,
        density = rules.excitatory_split.output
    log:
        f"{LOG_DIR}/validate_excitatory_ME_densities.log"
    shell:
        """
        densities-validation --annotation {input.annotation} \
            --excitatory_ME_types_folder {input.density} \
            2>&1 | tee {log}
        """

##>create_mtypes_densities_from_probability_map : Create neuron density nrrd files for the mtypes listed in the probability mapping csv file.
rule create_mtypes_densities_from_probability_map:
    input:
        inhibitory_densities_dir,
        hierarchy = hierarchy_v3,
        annotation = annotation_v3,
        L1_prob_map = rules.fetch_probability_map_L1.output,
        L23_prob_map = rules.fetch_probability_map_L23.output,
        L4_prob_map = rules.fetch_probability_map_L4.output,
        L5_prob_map = rules.fetch_probability_map_L5.output,
        L6_prob_map = rules.fetch_probability_map_L6.output,
        TH_INH_prob_map = rules.fetch_probability_map_TH_INH.output,
        lamp5 = rules.compute_lamp5_density.output
    output:
        directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['mtypes_densities_probability_map']}")
    params:
        app=APPS["atlas-building-tools mtype-densities create-from-probability-map"]
    log:
        f"{LOG_DIR}/create_mtypes_densities_from_probability_map.log"
    shell:
        """{params.app} \
            --hierarchy-path {input.hierarchy} \
            --annotation-path {input.annotation} \
            --probability-map {input.L1_prob_map} \
            --probability-map {input.L23_prob_map} \
            --probability-map {input.L4_prob_map} \
            --probability-map {input.L5_prob_map} \
            --probability-map {input.L6_prob_map} \
            --probability-map {input.TH_INH_prob_map} \
            --marker gad67 """ + marker_density_map["gad67"] + """ \
            --marker pv """ + marker_density_map["pv"] + """ \
            --marker sst """ + marker_density_map["sst"] + """ \
            --marker vip """ + marker_density_map["vip"] + """ \
            --marker approx_lamp5 {input.lamp5} \
            --synapse-class INH \
            --n-jobs {workflow.cores} \
            --output-dir {output} \
            2>&1 | tee {log}
        """

##>validate_inhibitory_ME_densities : validate inhibitory ME densities
rule validate_inhibitory_ME_densities:
    input:
        annotation = annotation_v3,
        density = rules.create_mtypes_densities_from_probability_map.output
    log:
        f"{LOG_DIR}/validate_inhibitory_ME_densities.log"
    shell:
        """
        densities-validation --annotation {input.annotation} \
            --inhibitory_ME_types_folder {input.density} \
            2>&1 | tee {log}
        """

##>validate_all_ME_densities : validate all ME densities
rule validate_all_ME_densities:
    input:
        annotation = annotation_v3,
        densities_inh = rules.create_mtypes_densities_from_probability_map.output,
        densities_exc = rules.excitatory_split.output
    output:
        densities_inh = directory("".join([rules.create_mtypes_densities_from_probability_map.output[0], "_validated"])),
        densities_exc = directory("".join([rules.excitatory_split.output[0], "_validated"]))
    params:
        densities_inh = os.path.basename(rules.create_mtypes_densities_from_probability_map.output[0]),
        densities_exc = os.path.basename(rules.excitatory_split.output[0])
    log:
        f"{LOG_DIR}/validate_sll_ME_densities.log"
    shell:
        """
        densities-validation --annotation {input.annotation} \
            --inhibitory_ME_types_folder {input.densities_inh} \
            --excitatory_ME_types_folder {input.densities_exc} \
            2>&1 | tee {log}  && \
        ln -s {params.densities_inh} {output.densities_inh}  && \
        ln -s {params.densities_exc} {output.densities_exc}
        """

inhibitory_ME_densities_dir = rules.validate_all_ME_densities.output.densities_inh
excitatory_ME_densities_dir = rules.validate_all_ME_densities.output.densities_exc

## =========================================================================================
## ======================== TRANSPLANT DENSITIES ===========================================
## =========================================================================================

default_transplant = """{params.app} \
                        --hierarchy {input.hierarchy} \
                        --src-annot-volume {input.src_annotation} \
                        --dst-annot-volume {input.dst_annotation} \
                        --src-cell-volume {input.src_cell_volume} \
                        --dst-cell-volume {output} \
                        --max-cores {workflow.cores} \
                        2>&1 | tee {log}
                     """

##>transplant_neuron_glia_cell_densities_correctednissl : Transplant neuron and glia density nrrd files
rule transplant_neuron_glia_cell_densities_correctednissl:
    input:
        hierarchy = hierarchy_v3,
        src_annotation = annotation_v2,
        dst_annotation = annotation_v3,
        src_cell_volume = neuron_glia_densities
    output:
        directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['glia_cell_densities_transplant_correctednissl']}")
    params:
        app=APPS["celltransplant"]
    log:
        f"{LOG_DIR}/transplant_neuron_glia_cell_densities_correctednissl.log"
    shell:
        default_transplant

##>transplant_inhibitory_neuron_densities_linprog_correctednissl : Transplant inhibitory neuron density nrrd files
rule transplant_inhibitory_neuron_densities_linprog_correctednissl:
    input:
        hierarchy = hierarchy_v3,
        src_annotation = annotation_v2,
        dst_annotation = annotation_v3,
        src_cell_volume = inhibitory_densities_dir
    output:
        directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['inhibitory_neuron_densities_linprog_transplant_correctednissl']}")
    params:
        app=APPS["celltransplant"]
    log:
        f"{LOG_DIR}/transplant_inhibitory_neuron_densities_linprog_correctednissl.log"
    shell:
        default_transplant

##>transplant_excitatory_split : Transplant excitatory-split neuron density nrrd files
rule transplant_excitatory_split:
    input:
        hierarchy = hierarchy_v3,
        src_annotation = annotation_v2,
        dst_annotation = annotation_v3,
        src_cell_volume = excitatory_ME_densities_dir
    output:
        directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['excitatory_split_transplant']}")
    params:
        app=APPS["celltransplant"]
    log:
        f"{LOG_DIR}/transplant_excitatory_split.log"
    shell:
        default_transplant

##>transplant_mtypes_densities_from_probability_map : Transplant neuron density nrrd files for the mtypes listed in the probability mapping csv file.
rule transplant_mtypes_densities_from_probability_map:
    input:
        hierarchy = hierarchy_v3,
        src_annotation = annotation_v2,
        dst_annotation = annotation_v3,
        src_cell_volume = inhibitory_ME_densities_dir
    output:
        directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['mtypes_densities_probability_map_transplant']}")
    params:
        app=APPS["celltransplant"]
    log:
        f"{LOG_DIR}/transplant_mtypes_densities_from_probability_map.log"
    shell:
        default_transplant

## =========================================================================================
## ======================== EXPORT MASKS,MESHES,SUMMARIES ==================================
## =========================================================================================

##>export_brain_region : export a mesh, a volumetric mask and a region summary json file for every brain region available in the brain parcellation volume. Create a hierarchy JSONLD file from the input hierarchy JSON file as well. Note: not only the leaf regions are exported but also the above regions that are combinaisons of leaves
rule export_brain_region:
    input:
        hierarchy = hierarchy_v3,
        annotation = annotation_v3,
        region_layer_map = rules.fetch_regions_layers_map.output
    output:
        mesh_dir = directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['MeshFile']['brain_region_meshes']}"),
        mask_dir = directory(f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['VolumetricFile']['brain_region_mask']}"),
        json_metadata_parcellations = f"{PUSH_DATASET_CONFIG_FILE['GeneratedDatasetPath']['MetadataFile']['metadata_parcellations']}",
        hierarchy_volume = f"{PUSH_DATASET_CONFIG_FILE['HierarchyJson']['mba_hierarchy']}",
        hierarchy_jsonld = f"{PUSH_DATASET_CONFIG_FILE['HierarchyJson']['mba_hierarchy_ld']}"
    params:
        app=APPS["parcellationexport"],
        export_meshes = EXPORT_MESHES
    log:
        f"{LOG_DIR}/export_brain_region.log"
    script:
        "scripts/export_brain_regions_meshes.py"

hierarchy_mba = rules.export_brain_region.output.hierarchy_volume
hierarchy_jsonld = rules.export_brain_region.output.hierarchy_jsonld

## =========================================================================================
## ====================== ANNOTATION PIPELINE DATASET INTEGRITY CHECK ======================
## =========================================================================================

##>check_annotation_pipeline_v3_volume_datasets : Check the integrity of the .nrrd volumetric datasets generated by the annotation pipeline
rule check_annotation_pipeline_v3_volume_datasets:
    input:
        annotation_ccfv3_split=rules.split_isocortex_layer_23_ccfv3.output.annotation,
        direction_vectors_ccfv3=direction_vectors,
        orientation_ccfv3=rules.orientation_field.output,
        placement_hints = rules.placement_hints.output.dir,
        mask_ccfv3_split=rules.export_brain_region.output.mask_dir
    output:
        f"{WORKING_DIR}/data_check_report/report_v3_volumetric_nrrd.json"
    params:
        app=APPS["bba-data-integrity-check nrrd-integrity"]
    log:
        f"{LOG_DIR}/check_annotation_pipeline_v3_volume_datasets.log"
    shell:
        """{params.app} --input-dataset {input.annotation_ccfv3_split} \
            --input-dataset {input.orientation_ccfv3} \
            --input-dataset {input.direction_vectors_ccfv3} \
            --input-dataset {input.placement_hints} \
            --input-dataset {input.mask_ccfv3_split} \
            --report-path {output} \
            2>&1 | tee {log}
        """

##>check_annotation_pipeline_v3_mesh_datasets : Check the integrity of the annotation pipeline mesh datasets
rule check_annotation_pipeline_v3_mesh_datasets:
    input:
        mesh_split=rules.export_brain_region.output.mesh_dir
    output:
        f"{WORKING_DIR}/data_check_report/report_obj_brain_v3_meshes.json"
    params:
        app=APPS["bba-data-integrity-check meshes-obj-integrity"]
    log:
        f"{LOG_DIR}/check_annotation_pipeline_v3_mesh_datasets.log"
    shell:
        """{params.app} --input-dataset {input.mesh_split} \
            --report-path {output} \
            2>&1 | tee {log}
        """

##>check_annotation_pipeline_v3 : Verify that the report files generated by the module verifying the annotation pipeline datasets integrity do not contain any issues before starting to push datasets into Nexus. These are contained in the folder data_check_report.
rule check_annotation_pipeline_v3:
    priority: 10
    input:
        nrrd_report = rules.check_annotation_pipeline_v3_volume_datasets.output,
        obj_report = rules.check_annotation_pipeline_v3_mesh_datasets.output,
    output:
        touch(f"{WORKING_DIR}/data_check_report/report_valid_v3.txt")
    log:
        f"{LOG_DIR}/check_annotation_pipeline_v3.log"
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

brain_region_id = "http://api.brain-map.org/api/v2/data/Structure/997"

atlas_release_res = forge.retrieve(atlas_release_id)

if not RESOURCE_TAG:
    RESOURCE_TAG = f"Atlas pipeline ({datetime.today().strftime('%Y-%m-%dT%H:%M:%S')})"
    atlas_release_rev = atlas_release_res._store_metadata._rev
else:
    atlas_release_rev = 0  # will use the one from the atlas_release_id at tag RESOURCE_TAG

##>push_atlas_release : rule to push into Nexus an atlas release
rule push_atlas_release:
    input:
        hierarchy = hierarchy_mba,
        hierarchy_jsonld = hierarchy_jsonld,
        annotation = annotation_v3,
        hemisphere = rules.create_hemispheres_ccfv3.output,
        placement_hints = rules.placement_hints.output.dir,
        placement_hints_metadata = rules.placement_hints.output.metadata,
        layers_regions_map = os.path.join(METADATA_PATH, "PH_layers_regions_map.json"),
        direction_vectors = direction_vectors,
        cell_orientations = rules.orientation_field.output,
    params:
        app=APPS["bba-data-push push-atlasrelease"].split(),
        token = myTokenFetcher.get_access_token(),
        resource_tag = RESOURCE_TAG,
        species=NEXUS_IDS["species"],
        reference_system=NEXUS_IDS["reference_system"],
        brain_template=brain_template_id,
    output:
        touch(f"{WORKING_DIR}/pushed_atlas_release.log")
    log:
        f"{LOG_DIR}/push_atlas_release.log"
    shell:
        default_push + """ \
        {params.app[1]} \
            --hierarchy-path {input.hierarchy} \
            --hierarchy-ld-path {input.hierarchy_jsonld} \
            --annotation-path {input.annotation} \
            --hemisphere-path {input.hemisphere} \
            --placement-hints-path {input.placement_hints} \
            --placement-hints-metadata {input.placement_hints_metadata} \
            --layers-regions-map {input.layers_regions_map} \
            --direction-vectors-path {input.direction_vectors} \
            --cell-orientations-path {input.cell_orientations} \
            --atlas-release-id {atlas_release_id} \
            --species {params.species} \
            --brain-region {brain_region_id} \
            --reference-system-id {params.reference_system} \
            --brain-template-id {params.brain_template} \
            --resource-tag '{params.resource_tag}' \
            --dryrun {nexus_dryrun} \
            2>&1 | tee {log}
        """

##>push_meshes : rule to push into Nexus brain regions meshes
rule push_meshes:
    input:
        hierarchy = hierarchy_mba,
        meshes = rules.export_brain_region.output.mesh_dir,
    params:
        app=APPS["bba-data-push push-meshes"].split(),
        token = myTokenFetcher.get_access_token(),
        resource_tag = RESOURCE_TAG,
        species=NEXUS_IDS["species"],
        reference_system=NEXUS_IDS["reference_system"],
    output:
        touch(f"{WORKING_DIR}/pushed_meshes.log")
    log:
        f"{LOG_DIR}/push_meshes.log"
    shell:
        default_push + """ \
        {params.app[1]} \
            --dataset-path {input.meshes} \
            --dataset-type BrainParcellationMesh \
            --hierarchy-path {input.hierarchy} \
            --atlas-release-id {atlas_release_id} \
            --atlas-release-rev {atlas_release_rev} \
            --species {params.species} \
            --brain-region None \
            --reference-system-id {params.reference_system} \
            --resource-tag '{params.resource_tag}' \
            --dryrun {nexus_dryrun} \
            2>&1 | tee {log}
        """

##>push_masks : rule to push into Nexus brain regions masks
rule push_masks:
    input:
        masks = rules.export_brain_region.output.mask_dir,
        hierarchy = hierarchy_mba,
    params:
        app=APPS["bba-data-push push-volumetric"].split(),
        token = myTokenFetcher.get_access_token(),
        species=NEXUS_IDS["species"],
        reference_system=NEXUS_IDS["reference_system"],
        resource_tag = RESOURCE_TAG
    output:
        touch(f"{WORKING_DIR}/pushed_masks.log")
    log:
        f"{LOG_DIR}/push_masks.log"
    shell:
        default_push + """ \
        {params.app[1]} \
            --dataset-path {input.masks} \
            --dataset-type BrainParcellationMask \
            --atlas-release-id {atlas_release_id} \
            --atlas-release-rev {atlas_release_rev} \
            --species {params.species} \
            --hierarchy-path {input.hierarchy} \
            --reference-system-id {params.reference_system} \
            --resource-tag '{params.resource_tag}' \
            --dryrun {nexus_dryrun} \
            2>&1 | tee {log}
        """

##>push_direction_vectors : rule to push into Nexus direction vectors
rule push_direction_vectors:
    input:
        direction_vectors = direction_vectors,
        hierarchy = hierarchy_v3,
    params:
        app=APPS["bba-data-push push-volumetric"].split(),
        token = myTokenFetcher.get_access_token(),
        species=NEXUS_IDS["species"],
        reference_system=NEXUS_IDS["reference_system"],
        resource_tag = RESOURCE_TAG
    output:
        touch(f"{WORKING_DIR}/pushed_direction_vectors.log")
    log:
        f"{LOG_DIR}/push_direction_vectors.log"
    shell:
        default_push + """ \
        {params.app[1]} \
            --dataset-path {input.direction_vectors} \
            --dataset-type DirectionVectorsField \
            --atlas-release-id {atlas_release_id} \
            --atlas-release-rev {atlas_release_rev} \
            --species {params.species} \
            --brain-region {brain_region_id} \
            --hierarchy-path {input.hierarchy} \
            --reference-system-id {params.reference_system} \
            --resource-tag '{params.resource_tag}' \
            --dryrun {nexus_dryrun} \
            2>&1 | tee {log}
        """

##>push_orientation_field : rule to push into Nexus orientation fields
rule push_orientation_field:
    input:
        orientation_field = rules.orientation_field.output,
        hierarchy = hierarchy_v3,
    params:
        app=APPS["bba-data-push push-volumetric"].split(),
        token = myTokenFetcher.get_access_token(),
        species=NEXUS_IDS["species"],
        reference_system=NEXUS_IDS["reference_system"],
        resource_tag = RESOURCE_TAG
    output:
        touch(f"{WORKING_DIR}/pushed_orientation_field.log")
    log:
        f"{LOG_DIR}/push_orientation_field.log"
    shell:
        default_push + """ \
        {params.app[1]} \
            --dataset-path {input.orientation_field} \
            --dataset-type CellOrientationField \
            --atlas-release-id {atlas_release_id} \
            --atlas-release-rev {atlas_release_rev} \
            --species {params.species} \
            --brain-region {brain_region_id} \
            --hierarchy-path {input.hierarchy} \
            --reference-system-id {params.reference_system} \
            --resource-tag '{params.resource_tag}' \
            --dryrun {nexus_dryrun} \
            2>&1 | tee {log}
        """

##>generate_annotation_pipeline_v3_datasets : Global rule to generate and check the integrity of every products of the annotation pipeline
rule generate_annotation_pipeline_v3_datasets:
    input:
        all_datasets = rules.check_annotation_pipeline_v3.output,


## =========================================================================================
## ============================= CELL DENSITY PIPELINE USER RULES ============================
## =========================================================================================

##>push_neuron_glia_densities : rule to push into Nexus neuron and glia densities
rule push_neuron_glia_densities:
    input:
        densities_dir = neuron_glia_densities,
        hierarchy = hierarchy_v3,
    params:
        app=APPS["bba-data-push push-volumetric"].split(),
        token = myTokenFetcher.get_access_token(),
        species=NEXUS_IDS["species"],
        reference_system=NEXUS_IDS["reference_system"],
        resource_tag = RESOURCE_TAG
    output:
        touch(f"{WORKING_DIR}/pushed_neuron_glia_densities.log")
    log:
        f"{LOG_DIR}/push_neuron_glia_densities.log"
    shell:
        default_push + """ \
        {params.app[1]} \
            --dataset-path {input.densities_dir} \
            --dataset-type GliaCellDensity \
            --atlas-release-id {atlas_release_id} \
            --atlas-release-rev {atlas_release_rev} \
            --species {params.species} \
            --brain-region {brain_region_id} \
            --hierarchy-path {input.hierarchy} \
            --reference-system-id {params.reference_system} \
            --resource-tag '{params.resource_tag}' \
            --dryrun {nexus_dryrun} \
            2>&1 | tee {log}
        """

##>push_inhibitory_neuron_densities : rule to push into Nexus inhibitory neuron densities
rule push_inhibitory_neuron_densities:
    input:
        inhibitory_densities = inhibitory_densities_dir,
        hierarchy = hierarchy_v3,
    params:
        app=APPS["bba-data-push push-volumetric"].split(),
        token = myTokenFetcher.get_access_token(),
        species=NEXUS_IDS["species"],
        reference_system=NEXUS_IDS["reference_system"],
        resource_tag = RESOURCE_TAG
    output:
        touch(f"{WORKING_DIR}/pushed_inhibitory_neuron_densities.log")
    log:
        f"{LOG_DIR}/push_inhibitory_neuron_densities.log"
    shell:
        default_push + """ \
        {params.app[1]} \
            --dataset-path {input.inhibitory_densities} \
            --dataset-type NeuronDensity \
            --atlas-release-id {atlas_release_id} \
            --atlas-release-rev {atlas_release_rev} \
            --species {params.species} \
            --brain-region {brain_region_id} \
            --hierarchy-path {input.hierarchy} \
            --reference-system-id {params.reference_system} \
            --resource-tag '{params.resource_tag}' \
            --dryrun {nexus_dryrun} \
            2>&1 | tee {log}
        """

##>push_metype_pipeline_datasets : rule to push into Nexus ME-type densities
rule push_metype_pipeline_datasets:
    input:
        excitatory_split_transplanted = excitatory_ME_densities_dir,
        densities_from_probability_map_transplanted = inhibitory_ME_densities_dir,
        hierarchy = hierarchy_v3,
    params:
        app=APPS["bba-data-push push-volumetric"].split(),
        token = myTokenFetcher.get_access_token(),
        #create_provenance_json = write_json(PROVENANCE_METADATA_V3_PATH, PROVENANCE_METADATA_V3, rule_name = "push_metype_pipeline_datasets"),
        species=NEXUS_IDS["species"],
        reference_system=NEXUS_IDS["reference_system"],
        resource_tag = RESOURCE_TAG
    output:
        touch(f"{WORKING_DIR}/pushed_metype_datasets.log")
    log:
        f"{LOG_DIR}/push_metype_pipeline_datasets.log"
    shell:
        default_push + """ \
        {params.app[1]} \
            --dataset-path {input.densities_from_probability_map_transplanted} \
            --dataset-path {input.excitatory_split_transplanted} \
            --dataset-type METypeDensity \
            --atlas-release-id {atlas_release_id} \
            --atlas-release-rev {atlas_release_rev} \
            --species {params.species} \
            --brain-region {brain_region_id} \
            --hierarchy-path {input.hierarchy} \
            --reference-system-id {params.reference_system} \
            --resource-tag '{params.resource_tag}' \
            --dryrun {nexus_dryrun} \
            2>&1 | tee {log}
        """

##>push_volumetric_datasets : push into Nexus the volumetric datasets that are not inputs of push_atlas_release
rule push_volumetric_datasets:
    input:
        rules.push_masks.output,
        rules.push_neuron_glia_densities.output,
        rules.push_inhibitory_neuron_densities.output,
        rules.push_metype_pipeline_datasets.output,
    output:
        touch(f"{WORKING_DIR}/pushed_volumetric_datasets.log")
    log:
        f"{LOG_DIR}/push_volumetric_datasets.log"


##>create_cellCompositionVolume_payload :
rule create_cellCompositionVolume_payload:
    input:
        rules.push_metype_pipeline_datasets.output
    params:
        input_paths = rules.push_metype_pipeline_datasets.input,
        files_ext = nrrd_ext,
        forge_config = FORGE_CONFIG,
        nexus_env = NEXUS_DESTINATION_ENV,
        nexus_bucket = NEXUS_DESTINATION_BUCKET,
        nexus_token = myTokenFetcher.get_access_token(),
        atlas_release_id = atlas_release_id,
        resource_tag = RESOURCE_TAG
    output:
        payload = f"{WORKING_DIR}/cellCompositionVolume_payload_{env}.json"
    log:
        f"{LOG_DIR}/create_cellCompositionVolume_payload_{env}.log"
    script:
        "scripts/cellCompositionVolume_payload.py"

##>create_cellCompositionSummary_payload :
rule create_cellCompositionSummary_payload:
    input:
        hierarchy = hierarchy_v3,
        annotation = annotation_v3,
        cellCompositionVolume = rules.create_cellCompositionVolume_payload.output.payload
    params:
        forge_config = FORGE_CONFIG,
        nexus_env = NEXUS_DESTINATION_ENV,
        nexus_bucket = NEXUS_DESTINATION_BUCKET,
        nexus_token = myTokenFetcher.get_access_token(),
	cores = workflow.cores
    output:
        intermediate_density_distribution = f"{WORKING_DIR}/density_distribution_{env}.json",
        summary_statistics = f"{WORKING_DIR}/cellCompositionSummary_payload_{env}.json"
    log:
        f"{LOG_DIR}/create_cellCompositionSummary_payload_{env}.log"
    script:
        "scripts/cellCompositionSummary_payload.py"

##>push_cellComposition : Final rule to generate and push into Nexus the CellComposition along with its dependencies (Volume and Summary)
rule push_cellComposition:
    input:
        hierarchy = hierarchy_v3,
        volume_path = rules.create_cellCompositionVolume_payload.output.payload,
        summary_path = rules.create_cellCompositionSummary_payload.output.summary_statistics,
    params:
        app=APPS["bba-data-push push-cellcomposition"].split(),
        token = myTokenFetcher.get_access_token(),
        resource_tag = RESOURCE_TAG,
        species=NEXUS_IDS["species"],
        reference_system=NEXUS_IDS["reference_system"],
    output:
        touch(f"{WORKING_DIR}/pushed_cellComposition.log")
    log:
        f"{LOG_DIR}/push_cellComposition.log"
    shell:
        default_push.replace("{NEXUS_DESTINATION_PROJ}", "atlasdatasetrelease") + """ \
        {params.app[1]} \
            --atlas-release-id {atlas_release_id} \
            --atlas-release-rev {atlas_release_rev} \
            --cell-composition-id {cell_composition_id} \
            --species {params.species} \
            --brain-region {brain_region_id} \
            --hierarchy-path {input.hierarchy} \
            --reference-system-id {params.reference_system} \
            --volume-path {input.volume_path} \
            --summary-path {input.summary_path} \
            --name '{CELL_COMPOSITION_NAME}' '{CELL_COMPOSITION_SUMMARY_NAME}' '{CELL_COMPOSITION_VOLUME_NAME}' \
            --log-dir {LOG_DIR} \
            --resource-tag '{params.resource_tag}' \
            --dryrun {nexus_dryrun} \
            2>&1 | tee {log}
        """

##>push_atlas_datasets : push into Nexus all the Atlas datasets
rule push_atlas_datasets:
    input:
        rules.push_atlas_release.output,
        rules.push_meshes.output,
        rules.push_volumetric_datasets.output,
        rules.push_cellComposition.output
    output:
        touch(f"{WORKING_DIR}/pushed_atlas_datasets.log")
    log:
        f"{LOG_DIR}/push_atlas_datasets.log"
