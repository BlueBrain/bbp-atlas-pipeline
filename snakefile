import os
import subprocess
import shutil
import json

# loading the config
configfile: "config.yaml"

# placing the config values into local variable
WORKING_DIR = config["WORKING_DIR"]
NEXUS_ENV = config["NEXUS_ENV"]
NEXUS_ORG = config["NEXUS_ORG"]
NEXUS_PROJ = config["NEXUS_PROJ"]
NEXUS_TOKEN_FILE = config["NEXUS_TOKEN_FILE"]
NEXUS_IDS_FILE = config["NEXUS_IDS_FILE"]
RESOLUTION = str(config["RESOLUTION"])
LOG_FILE = os.path.join(WORKING_DIR, "log.log")
VERSION_FILE = os.path.join(WORKING_DIR, "versions.txt")

# All the apps must be listed here so that we can fetch all the versions
APPS = {
    "bba-datafetch": "bba-datafetch",
    "parcellation2mesh": "parcellation2mesh"
}

# delete the log of app versions
try:
    os.remove(VERSION_FILE)
except OSError:
    pass

# fetch version of each app and write it down in a file
version_file = open(VERSION_FILE,"a")
for app in APPS:
    # first, we need to check if each CLI is in PATH, if not we abort with exit code 1
    if shutil.which(app) is None:
        raise Exception("The CLI {} is not installed or not in PATH. Pipeline cannot execute.".format(app))
        exit(1)

    app_version = subprocess.check_output("{} --version".format(app), shell=True).decode('ascii').rstrip("\n\r")
    version_file.write(app_version)
    version_file.write("\n")
version_file.close()

# Reading some Nexus file @id mapping
NEXUS_IDS = json.loads(open(NEXUS_IDS_FILE, 'r').read().strip())

# fetch the hierarchy file, originally called 1.json
rule fetch_ccf_brain_region_hierarchy:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        "{}/hierarchy.json".format(WORKING_DIR)
    params:
        nexus_id=NEXUS_IDS["brain_region_hierarchies"]["allen_mouse_ccf"],
        app=APPS["bba-datafetch"]
    log:
        LOG_FILE
    shell:
        """
        {params.app} --nexus-env {NEXUS_ENV} \
            --nexus-token-file {input.token} \
            --nexus-org {NEXUS_ORG} \
            --nexus-proj {NEXUS_PROJ} \
            --payload \
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
        "{}/brain_parcellation_ccfv2.nrrd".format(WORKING_DIR)
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
        "{}/fiber_parcellation_ccfv2.nrrd".format(WORKING_DIR)
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
        "{}/brain_parcellation_ccfv3.nrrd".format(WORKING_DIR)
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


# /!\ FAKE TASK FOR TESTING
# combine the volumes
rule combine:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        brain_ccfv2=rules.fetch_brain_parcellation_ccfv2.output,
        fiber_ccfv2=rules.fetch_fiber_parcellation_ccfv2.output,
        brain_ccfv3=rules.fetch_brain_parcellation_ccfv3.output
    output:
        "{}/annotation_hybrid.FAKE".format(WORKING_DIR)
    shell:
        """
        echo "this is the fake combine task" > {output}
        """

# fetch the gene expression volume for gene aldh1l1
rule fetch_gene_aldh1l1:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        "{}/gene_aldh1l1.nrrd".format(WORKING_DIR)
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

# fetch the gene expression volume for gene cnp
rule fetch_gene_cnp:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        "{}/gene_cnp.nrrd".format(WORKING_DIR)
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

# fetch the gene expression volume for gene gad
rule fetch_gene_gad:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        "{}/gene_gad.nrrd".format(WORKING_DIR)
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

# fetch the gene expression volume for gene gfap
rule fetch_gene_gfap:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        "{}/gene_gfap.nrrd".format(WORKING_DIR)
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

# fetch the gene expression volume for gene nrn1
rule fetch_gene_nrn1:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        "{}/gene_nrn1.nrrd".format(WORKING_DIR)
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

# fetch the gene expression volume for gene s100b
rule fetch_gene_s100b:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        "{}/gene_s100b.nrrd".format(WORKING_DIR)
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

# fetch the gene expression volume for gene tmem119
rule fetch_gene_tmem119:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        "{}/gene_tmem119.nrrd".format(WORKING_DIR)
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

# /!\ THIS TASK RELIES ON A UNFINISHED TASK! (combine)
# export a mesh for every brain region available in the parcellation volume
# generated by the rule combine (still in development)
# Note: not only the leaf regions are exported but also the above regions
# that are combinaisons of leeaves
rule brain_region_meshes_generator:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        #parcellation_volume=rules.combine.output
        parcellation_volume=rules.fetch_brain_parcellation_ccfv3.output
    output:
        "{}/brain_region_meshes/".format(WORKING_DIR)
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
