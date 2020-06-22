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
    "parcellation2mesh": "parcellation2mesh",
    "atlas-building-tools annotations-combinator": "atlas-building-tools annotations-combinator",
    "atlas-building-tools direction-vectors isocortex": "atlas-building-tools direction-vectors isocortex",
    "atlas-building-tools direction-vectors cerebellum": "atlas-building-tools direction-vectors cerebellum",
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


# combine the volumes
rule combine:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        brain_ccfv2=rules.fetch_brain_parcellation_ccfv2.output,
        fiber_ccfv2=rules.fetch_fiber_parcellation_ccfv2.output,
        brain_ccfv3=rules.fetch_brain_parcellation_ccfv3.output
    output:
        f"{WORKING_DIR}/annotation_hybrid.nrrd"
    params:
        app=APPS["atlas-building-tools annotations-combinator"]
    shell:
        """
        {params.app} --hierarchy {input.hierarchy} \
            --brain-annotation-ccfv2 {input.brain_ccfv2} \
            --fiber-annotation-ccfv2 {input.fiber_ccfv2} \
            --brain-annotation-ccfv3 {input.brain_ccfv3} \
            --output-path {output}
        """

# fetch the gene expression volume for gene aldh1l1
rule fetch_gene_aldh1l1:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{WORKING_DIR}/gene_aldh1l1.nrrd"
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
        f"{WORKING_DIR}/gene_cnp.nrrd"
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

# fetch the gene expression volume for gene gfap
rule fetch_gene_gfap:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{WORKING_DIR}/gene_gfap.nrrd"
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

# fetch the gene expression volume for gene s100b
rule fetch_gene_s100b:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        f"{WORKING_DIR}/gene_s100b.nrrd"
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
        f"{WORKING_DIR}/gene_tmem119.nrrd"
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

# export a mesh for every brain region available in the parcellation volume
# generated by the rule combine (still in development)
# Note: not only the leaf regions are exported but also the above regions
# that are combinaisons of leeaves
rule brain_region_meshes_generator:
    input:
        hierarchy=rules.fetch_ccf_brain_region_hierarchy.output,
        parcellation_volume=rules.combine.output
    output:
        f"{WORKING_DIR}/brain_region_meshes/"
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
        parcellation_volume=rules.combine.output,
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
        parcellation_volume=rules.combine.output
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
