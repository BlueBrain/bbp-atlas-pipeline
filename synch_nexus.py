import os
import json
import yaml
from pathlib import Path
import hashlib

from kgforge.core import KnowledgeGraphForge
from kgforge.core import Resource

nexus_token = os.environ["NEXUS_TOKEN"]
nexus_token_staging = os.environ["NEXUS_STAGING_TOKEN"]
nexus_ids_path = os.environ["NEXUS_IDS_PATH"]
res_tag_sep = "?tag="
metadata_dir = os.environ["METADATA_DIR"]
file_nexus_id_map = os.environ["FILE_NEXUS_ID_MAP"]
commit_sha = os.environ["COMMIT_SHA"]
is_prod_env = os.environ["IS_PROD_ENV"]


def create_prob_map_resource(name, description):
    res = Resource(
        name=name,
        description=description,
        type=["Dataset", "PipelineConfigResource"],
        generation=Resource(
            type="Generation",
            activity=Resource(
                id=commit_sha,
                type="Activity")
        )
    )
    return res


def increment_minor(res_tag):
    # tag version: "vM.m.p" (vMajor.minor.patch)
    vMajor, minor, patch = res_tag.split(".")
    new_tag = res_tag.replace(f"{vMajor}.{minor}.{patch}", f"{vMajor}.{int(minor) +1}.0")
    return new_tag


def synch_nexus():
    with open(nexus_ids_path, 'r') as nexus_ids_file:
        nexus_ids = json.loads(nexus_ids_file.read().strip())

    pipeline_config = yaml.safe_load(open("config.yaml").read().strip())

    if is_prod_env:
        forge = KnowledgeGraphForge("forge-config.yml", bucket="bbp/atlas",
                                    endpoint=pipeline_config["NEXUS_PROD_ENV"],
                                    token=nexus_token)
        synch_nexus_prod(nexus_ids, forge, pipeline_config["NEXUS_STAGING_ENV"])
    else:
        forge = KnowledgeGraphForge("forge-config.yml", bucket="bbp/atlas",
                                    endpoint=pipeline_config["NEXUS_STAGING_ENV"],
                                    token=nexus_token)
        update_nexus_staging(nexus_ids, forge)


def synch_nexus_prod(nexus_ids, forge_prod, staging_env):
    skip_synch = ["AtlasRelease", "CellComposition", "species", "ParcellationOntology", "10"]
    for res_type, res_names in nexus_ids.items():
        if res_type in skip_synch:
            continue

        if isinstance(res_names, str):
            res_id = res_names
            synch_resource(res_id, forge_prod, res_names, staging_env)
            continue

        for res_name in res_names:
            if isinstance(res_names[res_name], str):
                res_id = res_names[res_name]
                synch_resource(res_id, forge_prod, res_name, staging_env)
            else:
                resolution = res_name
                if resolution in skip_synch:
                    continue
                for res_sub_type, res_sub_names in res_names[resolution].items():
                    for res_sub_name, res_id in res_sub_names.items():
                        synch_resource(res_id, forge_prod, res_sub_name, staging_env)


def synch_resource(res_id_tag, forge_prod, res_name, staging_env):
    res_tag = None
    if res_tag_sep in res_id_tag:
        res_id, res_tag = res_id_tag.split(res_tag_sep)
    else:
        res_id = res_id_tag

    if not res_tag:
        print(f"\nResource {res_name} (Nexus id: '{res_id}') has no tag, skipping it.")
        return

    nexus_prod_string = f"in project '{forge_prod._store.bucket}' (Nexus env: '{forge_prod._store.endpoint}')"
    print(f"\n\nRetrieving Resource for '{res_name}' (Nexus id: '{res_id}', at tag '{res_tag}) {nexus_prod_string}")
    res_prod = forge_prod.retrieve(res_id, version=res_tag)
    if res_prod:
        print(f"\tFound Resource with id '{res_id}' and tag '{res_tag}' {nexus_prod_string})")
        print("\tNo synchronization will be performed")
        return

    print(f"\tNo Resource with id '{res_id}' and tag '{res_tag}' found {nexus_prod_string}")
    print(f"\tLooking for Resource with id '{res_id}' (dropping tag requirement)")
    res_prod = forge_prod.retrieve(res_id)
    if not res_prod:
        print(f"\tNo Resource with id '{res_id}' found {nexus_prod_string}")
        print(f"\tRegistering a new Resource for '{res_name}':")
        res_prod = Resource(id=res_id)
        forge_prod.register(res_prod)
    else:
        print(f"Resource found")

    print(f"\tSynchronizing Resource for '{res_name}' with staging version:")
    forge_staging = KnowledgeGraphForge("forge-config.yml",
        bucket=forge_prod._store.bucket, endpoint=staging_env, token=nexus_token_staging)
    nexus_staging_string = f"in project '{forge_prod._store.bucket}' (Nexus env: '{forge_staging._store.endpoint}'"
    print(f"\t\tRetrieving Resource for '{res_name}' (Nexus id: '{res_id}', at tag '{res_tag}) {nexus_staging_string}")
    res_staging = forge_staging.retrieve(res_id, version=res_tag)
    if not res_staging:
        if res_name in ["brain_realigned"]:
            print("\t\tIgnoring Resource")
            return
        else:
            raise Exception(f"\t\tNo Resource with id '{res_id}' and tag '{res_tag}' found {nexus_staging_string}")

    print("\t\tSynchronize Resource distribution")
    if not hasattr(res_staging.distribution.atLocation, "location"):
        raise Exception("The Resource.distribution.atLocation has no property 'location', maybe the Resource hsa not been migrated to gpfs?")
    distribution_file = res_staging.distribution.atLocation.location.replace("file:///gpfs", "/gpfs")
    res_prod.distribution = forge_prod.attach(distribution_file,
        content_type=res_staging.distribution.encodingFormat)

    print("\t\tSynchronize Resource attributes")
    skip_props = ["context", "id", "atlasRelease", "brainLocation", "distribution", "generation", "isRegisteredIn"]
    for attr, value in vars(res_staging).items():
        if attr.startswith("_") or attr in skip_props:
            continue
        setattr(res_prod, attr, value)

    print(f"\t\tUpdating Resource with id '{res_id}' {nexus_prod_string}")
    forge_prod.update(res_prod)
    print(f"\t\tTagging Resource with tag '{res_tag}' {nexus_prod_string}")
    forge_prod.tag(res_prod, res_tag)


def update_nexus_staging(nexus_ids, forge):
    file_nexus_map_path = os.path.join(metadata_dir, file_nexus_id_map)
    with open(file_nexus_map_path) as file_nexus_map_:
        file_nexus_map = json.loads(file_nexus_map_.read().strip())
    file_nexus_map_keys = list(file_nexus_map.keys())

    updated_map = False

    prob_maps = [str(path) for path in Path(metadata_dir).glob("probability_map_*.csv")]
    for prob_map_path in prob_maps:
        prob_map_doc_path = prob_map_path.replace(metadata_dir, os.path.join(metadata_dir, "docs")).replace(".csv", ".txt")
        if not os.path.isfile(prob_map_doc_path):
            raise Exception(f"No file {prob_map_doc_path} found, please provide it")
        with open(prob_map_doc_path) as prob_map_doc:
            prob_map_desc = prob_map_doc.read()

        nexus_id_path = nexus_ids[metadata_dir]

        prob_map = os.path.basename(prob_map_path)
        new_file = False
        nexus_id_key = None
        steps = None
        res_tag = None
        if prob_map not in file_nexus_map:
            print(f"File {prob_map} not found in map {file_nexus_map_path}, a new Resource will be created")
            new_file = True
            res = create_prob_map_resource(prob_map, prob_map_desc)
        else:
            file_nexus_map_keys.remove(prob_map)

            # Get Nexus ID
            nexus_id_key = file_nexus_map[prob_map]
            steps = nexus_id_key.split("/")
            # steps[0] is metadata_dir
            for step in steps[1:-1]:
                if step not in nexus_id_path:
                    raise Exception(f"No key '{step}' in {nexus_id_path} from {nexus_ids_path}")
                nexus_id_path = nexus_id_path[step]
            res_id_tag = nexus_id_path[steps[-1]]

            print(f"\nRetrieving Resource for {prob_map} (Nexus id: '{res_id_tag}'")
            res = forge.retrieve(res_id_tag)
            if not res:
                raise Exception(f"No Resource with id '{res_id_tag}' found in project '{forge._store.bucket}' (Nexus env: '{forge._store.endpoint}')")
            with open(prob_map_path, "rb") as prob_map_file:
                if res.distribution.digest.value == hashlib.sha256(prob_map_file.read()).hexdigest():
                    print(f"Hash of Resource distribution is identical to current file, nothing to update")
                    continue
            print(f"Hash of Resource distribution is different from hash of current file, updating the Resource")
            res.description = prob_map_desc

        res.distribution = forge.attach(prob_map_path, content_type="text/csv")
        if new_file:
            forge.register(res)
            new_tag = "v0.1.0"
            res_id_tag = res_tag_sep.join([res.id, new_tag])
            updated_map = True
        else:
            res._store_metadata._rev += 1  # current rev = tagged rev + 1
            forge.update(res)
            res_id, res_tag = res_id_tag.split(res_tag_sep)
            print(f"Increment minor version of tag '{res_tag}' for Resource id '{res_id}'")
            new_tag = increment_minor(res_tag)
        if not res._last_action.succeeded:
            raise Exception(f"The Resource registration/update failed with error:\n{res._last_action.message}")

        forge.tag(res, new_tag)
        if not res._last_action.succeeded:
            raise Exception(f"The Resource tagging failed with error:\n{res._last_action.message}")
        if new_file:
            print(f"Add entry of Resource {res_id_tag} in {nexus_ids_path}")
            prob_map_no_ext = prob_map.split(".")[0]
            nexus_id_path[prob_map_no_ext] = res_id_tag
            file_nexus_map[prob_map] = "/".join([metadata_dir, prob_map_no_ext])
        else:
            print(f"Update tag of Resource at '{nexus_id_key}' in {nexus_ids_path} to '{new_tag}'")
            nexus_id_path[steps[-1]] = res_id_tag.replace(res_tag, new_tag)

    if len(file_nexus_map_keys):
        print(f"The following elements from {file_nexus_map_path} are not found in {metadata_dir}: {', '.join(file_nexus_map_keys)}")

    with open(nexus_ids_path, 'w') as nexus_ids_file:
        nexus_ids_file.write(json.dumps(nexus_ids, indent=2))
    if updated_map:
        with open(file_nexus_map_path, 'w') as file_nexus_map_:
            file_nexus_map_.write(json.dumps(file_nexus_map, indent=2))


if __name__ == "__main__":
    synch_nexus()
