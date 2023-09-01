import json
import os
from pathlib import Path
import yaml
import numpy as np

from voxcell import RegionMap, VoxelData
from pipeline_validator.pipeline_validator import pipeline_validator


user_config_file = "user_config.json"


def main(hierarchy, annotation_volume, user_config_file):
    user_config = json.load(open(user_config_file).read())

    from blue_brain_token_fetch.Token_refresher import TokenFetcher
    my_token_fetcher = TokenFetcher(keycloak_config_file="./keycloak_config.yml")
    token = my_token_fetcher.getAccessToken()

    with open("../rules_config_dir_templates/push_dataset_config_template.yaml", "r") as file:
        dataset_path_config = yaml.safe_load(file.read().strip())
    default_output = dataset_path_config['GeneratedDatasetPath']['VolumetricFile']

    available_vars = {**dataset_path_config["HierarchyJson"], **default_output}
    whitelisted_vars = list(available_vars.keys())

    pipeline_validator(user_config_file, token, whitelisted_vars)

    region_map = RegionMap.load_json(hierarchy)
    annotation = VoxelData.load_nrrd(annotation_volume)

    user_rules = user_config["rules"]
    # Customize snakefile rules per user_config and run it
    # ToDo

    for user_rule in user_rules:
        rule = user_rule["rule"]
        default_rule_output = default_output[rule]

        region_volume_map = {}
        customized_regions = user_rule["execute"]
        for custom_region in customized_regions:
            region_id = get_region_id(custom_region["brainRegion"])
            region_volume_map[region_id] = custom_region["output_dir"]

        merged_output_dir = os.path.join(rule, "merged/")
        print(f"Merging outputs of rule {rule} from {len(customized_regions)} regions")
        merged_volumes = merge_nrrd_files(region_map, annotation.raw, region_volume_map, default_rule_output, merged_output_dir)
        print(f"{len(merged_volumes)} have been merged in {merged_output_dir}: {merged_volumes}")


def merge_nrrd_files(region_map: RegionMap, annotation: np.ndarray, region_volume_map: dict, default_rule_output:
                     str, merged_output_dir: str) -> list:
    """
    Merge nrrd volumes for various brain regions.

    Args:
        region_map: voxcell.RegionMap of the regions hierarchy
        annotation: annotation volume, where each voxel contains a region id
        region_volume_map: mapping between brain region and its corresponding nrrd file to merge
        default_rule_output: output path of the nrrd file of original default rule.
            The areas of the brain regions in region_volume_map will be superseded.
        merged_output_dir: directory where to save merged volumes

    Returns:
        The list of volume files with updated values from the volumes in region_volume_map.
    """

    extension = ".nrrd"
    default_output_files = []
    if not os.path.exists(default_rule_output):
        raise Exception("The output of the default rule does not exist at", default_rule_output)
    if os.path.isdir(default_rule_output):
        default_output_files.extend([str(path) for path in Path(default_rule_output).rglob("*" + extension)])
    elif default_rule_output.endswith(extension):
        if os.path.isfile(default_rule_output):
            default_output_files.append(default_rule_output)

    result = []
    os.makedirs(merged_output_dir, exist_ok=True)
    for default_output in default_output_files:
        filename = os.path.basename(default_output)
        # Get the default volume
        default_volume = VoxelData.load_nrrd(default_output)
        result_volume = np.copy(default_volume.raw)
        # Update the result regions with values from the input map
        for (region_id, volume_path) in region_volume_map.items():
            ids_reg = region_map.find(region_id, "id", with_descendants=True)
            if not ids_reg:
                print(f"Warning: region {region_id} is not found in the hierarchy provided")
                continue
            volume_file = os.path.join(volume_path, filename)
            volume = VoxelData.load_nrrd(volume_file).raw
            # Get region mask
            region_mask = np.isin(annotation, list(ids_reg))
            # Supersede region {region_id} in result with values from volume
            result_volume[region_mask] = volume[region_mask]

        merged_file = os.path.join(merged_output_dir, filename)
        default_volume.with_data(result_volume).save_nrrd(merged_file)
        result.append(merged_file)

    return result


def get_region_id(full_id):
    parts = full_id.split("/")
    return int(parts[-1])
