import os
import json
from pathlib import Path
import hashlib
from kgforge.core import KnowledgeGraphForge

nexus_token = os.environ["NEXUS_STAGING_TOKEN"]
nexus_ids_path = os.environ["NEXUS_IDS_PATH"]
nexus_env = "https://staging.nise.bbp.epfl.ch/nexus/v1"


def increment_minor(res_tag):
    # tag version: "vM.m.p" (vMajor.minor.patch)
    vMajor, minor, patch = res_tag.split(".")
    new_tag = res_tag.replace(f"{vMajor}.{minor}.{patch}", f"{vMajor}.{int(minor) +1}.0")
    return new_tag


def synch_nexus():
    bucket = "bbp/atlas"
    forge = KnowledgeGraphForge("forge-config.yml", bucket=bucket, endpoint=nexus_env, token=nexus_token)

    with open(nexus_ids_path, 'r') as nexus_ids_file:
        nexus_ids = json.loads(nexus_ids_file.read().strip())

    metadata_dir = "metadata"
    file_nexus_map_path = os.path.join(metadata_dir, "file_nexus_map.json")
    with open(file_nexus_map_path) as file_nexus_map_:
        file_nexus_map = json.loads(file_nexus_map_.read().strip())
    file_nexus_map_keys = list(file_nexus_map.keys())

    prob_maps = [str(path) for path in Path(metadata_dir).rglob("probability_map_*.csv")]
    for prob_map_path in prob_maps:
        prob_map = os.path.basename(prob_map_path)
        if prob_map not in file_nexus_map:
            print(f"File {prob_map} not found in map {file_nexus_map_path}")
            continue
        file_nexus_map_keys.remove(prob_map)

        nexus_id_key = file_nexus_map[prob_map]
        steps = nexus_id_key.split("/")
        nexus_id_path = nexus_ids
        for step in steps[:-1]:
            if step not in nexus_id_path:
                raise Exception(f"No key '{step}' in {nexus_id_path} from {nexus_ids_path}")
            nexus_id_path = nexus_id_path[step]
        res_id_tag = nexus_id_path[steps[-1]]

        print(f"\nRetrieving Resource for {prob_map} (Nexus id: '{res_id_tag}'")
        res = forge.retrieve(res_id_tag)
        if not res:
            raise Exception(f"No Resource with id '{res_id_tag}' found in project '{bucket}' (Nexus env: '{nexus_env}')")
        with open(prob_map_path) as prob_map_file:
            if res.distribution.digest.value == hashlib.sha256(prob_map_file.read().encode('utf-8')).hexdigest():
                print(f"Hash of Resource distribution is identical to current file, nothing to update")
                continue

        print(f"Hash of Resource distribution is different from hash of current file, updating the Resource")
        res.distribution = forge.attach(prob_map_path, content_type="text/csv")
        forge.update(res)
        if not res._last_action.succeeded:
            raise Exception(f"The Resource update failed with error:\n{res._last_action.message}")

        res_id, res_tag = res_id_tag.split("?tag=")
        print(f"Increment minor version of tag '{res_tag}' for Resource id '{res_id}'")
        new_tag = increment_minor(res_tag)
        forge.tag(res, new_tag)
        if not res._last_action.succeeded:
            raise Exception(f"The Resource tagging failed with error:\n{res._last_action.message}")

        print(f"Update tag of Resource at '{nexus_id_key}' in {nexus_ids_path} to '{new_tag}'")
        nexus_id_path[steps[-1]] = res_id_tag.replace(res_tag, new_tag)

    if len(file_nexus_map_keys):
        print(f"The following elements from {file_nexus_map_path} are not found in {metadata_dir}: {', '.join(file_nexus_map_keys)}")

    with open(nexus_ids_path, 'w') as nexus_ids_file:
        nexus_ids_file.write(json.dumps(nexus_ids, indent=2))


if __name__ == "__main__":
    synch_nexus()
