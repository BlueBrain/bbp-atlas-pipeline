import os
import subprocess

# loading the config
configfile: "config.yaml"

# placing the config values into local variable
WORKING_DIR = config["WORKING_DIR"]
NEXUS_ENV = config["NEXUS_ENV"]
NEXUS_ORG = config["NEXUS_ORG"]
NEXUS_PROJ = config["NEXUS_PROJ"]
NEXUS_TOKEN_FILE = config["NEXUS_TOKEN_FILE"]
RESOLUTION = str(config["RESOLUTION"])
LOG_FILE = os.path.join(WORKING_DIR, "log.log")
VERSION_FILE = os.path.join(WORKING_DIR, "versions.txt")

# All the apps must be listed here so that we can fetch all the versions
APPS = {
    "bba-datafetch": "bba-datafetch"
}

# delete the log of app versions
try:
    os.remove(VERSION_FILE)
except OSError:
    pass

# fetch version of each app and write it down in a file
version_file = open(VERSION_FILE,"a")
for app in APPS:
    app_version = subprocess.check_output("{} --version".format(app), shell=True).decode('ascii').rstrip("\n\r")
    version_file.write(app_version)
    version_file.write("\n")
version_file.close()

# defining some Nexus file @id mapping
NEXUS_IDS = {

    "hierarchy": "https://bbp.epfl.ch/neurosciencegraph/data/10856ee4-5426-4386-91eb-4f1c7e77d86d",

    # resolution 10 microns
    "10": {
        "brain_parcellation_ccfv2" : "https://bbp.epfl.ch/neurosciencegraph/data/7f85cd66-d212-4799-bb4c-0732b8534442",
        "brain_parcellation_ccfv3" : "https://bbp.epfl.ch/neurosciencegraph/data/e238a1f6-0b30-48df-ac8b-6185efe10a59",
        "fiber_parcellation_ccfv2" : "https://bbp.epfl.ch/neurosciencegraph/data/2f26c63b-6d01-4540-bf8b-b0a2a7c59597"
    },

    # resolution 25 microns
    "25": {
        "brain_parcellation_ccfv2" : "https://bbp.epfl.ch/neurosciencegraph/data/7b4b36ad-911c-4758-8686-2bf7943e10fb",
        "brain_parcellation_ccfv3" : "https://bbp.epfl.ch/neurosciencegraph/data/025eef5f-2a9a-4119-b53f-338452c72f2a",
        "fiber_parcellation_ccfv2" : "https://bbp.epfl.ch/neurosciencegraph/data/a4552116-607b-469e-ad2a-50bba00c23d8"
    }
}


# fetch the hierarchy file, originally called 1.json
rule fetch_ccf_brain_region_hierarchy:
    input:
        token=NEXUS_TOKEN_FILE
    output:
        "{}/hierarchy.json".format(WORKING_DIR)
    params:
        nexus_id=NEXUS_IDS["hierarchy"],
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
        nexus_id=NEXUS_IDS[RESOLUTION]["brain_parcellation_ccfv2"],
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
        nexus_id=NEXUS_IDS[RESOLUTION]["fiber_parcellation_ccfv2"],
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
        nexus_id=NEXUS_IDS[RESOLUTION]["brain_parcellation_ccfv3"],
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
        "{}/combine_FAKE_TASK.txt".format(WORKING_DIR)
    shell:
        """
        echo "this is the fake combine task" > {output}
        """
