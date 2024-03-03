import os
import json
from pathlib import Path
from copy import deepcopy
import numpy as np

from voxcell import RegionMap, VoxelData


def main(hierarchy, annotation_volume, user_rule, default_rule_output,
         merged_output_dir, default_rule_file=None, metadata_path=None):
    region_map = RegionMap.load_json(hierarchy)
    annotation = VoxelData.load_nrrd(annotation_volume)

    rule_name = user_rule["rule"]

    region_volume_map = {}
    customized_regions = user_rule["execute"]
    for custom_region in customized_regions:
        region_id = get_region_id(custom_region["brainRegion"])
        region_volume_map[region_id] = custom_region["output_dir"]

    print(f"Merging outputs of rule {rule_name} from {len(customized_regions)} regions")
    merged_volumes = merge_nrrd_files(region_map, annotation.raw, region_volume_map,
        default_rule_output, merged_output_dir, default_rule_file, metadata_path)
    print(f"{len(merged_volumes)} files have been merged in {merged_output_dir}: {merged_volumes}")


def merge_nrrd_files(region_map: RegionMap, annotation: np.ndarray,
    region_volume_map: dict, default_rule_output: str, merged_output_dir: str,
    default_rule_file=None, metadata_path=None) -> list:
    """
    Merge nrrd volumes for various brain regions.

    Args:
        region_map: voxcell.RegionMap of the regions hierarchy
        annotation: annotation volume, where each voxel contains a region id
        region_volume_map: mapping between brain region and its corresponding nrrd file to merge
        default_rule_output: output path of the nrrd file of original default rule.
            The areas of the brain regions in region_volume_map will be superseded.
        merged_output_dir: directory where to save merged volumes
        metadata_path: optional path to the metadata file

    Returns:
        The list of volume files with updated values from the volumes in region_volume_map.
    """

    extension = ".nrrd"
    default_output_files = []
    if not os.path.exists(default_rule_output):
        raise Exception("The output of the default rule does not exist at", default_rule_output)
    if os.path.isdir(default_rule_output):
        if default_rule_file:  # TODO account for list of default_rule_files
            print(f"A default output filepath is provided: {default_rule_file}, "
                  "only such a file will be merged from each region-specific output dir.")
            glob_str = os.path.basename(default_rule_file)
        else:
            glob_str = "*" + extension
        default_output_files.extend([str(path) for path in Path(default_rule_output).glob(glob_str)])
    elif default_rule_output.endswith(extension):
        if os.path.isfile(default_rule_output):
            default_output_files = [default_rule_output]

    if metadata_path:
        metadata_file = open(metadata_path, "r+")
        metadata_json = json.load(metadata_file)

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
            if not os.path.isfile(volume_file):
                print(f"Warning: no file {filename} found in {volume_path}, skipping it.")
                continue
            volume = VoxelData.load_nrrd(volume_file).raw

            # Get region mask
            region_mask = np.isin(annotation, list(ids_reg))
            # Supersede region {region_id} in result with values from volume
            if result_volume.shape[0:len(region_mask.shape)] == region_mask.shape:
                result_volume[region_mask] = volume[region_mask]
            else:
                result_volume[:region_mask] = volume[:region_mask]

            if metadata_path:
                metadata_json[filename].append(region_map.get(region_id, "name"))

        merged_file = os.path.join(merged_output_dir, filename)
        default_volume.with_data(result_volume).save_nrrd(merged_file)
        result.append(merged_file)

    if metadata_path:
        metadata_file.seek(0)
        json.dump(metadata_json, metadata_file)
        metadata_file.truncate()
        metadata_file.close()

    return result


def get_region_id(full_id):
    parts = full_id.split("/")
    return int(parts[-1])


def check_rule_existence(rule, rule_name):
    if not rule:
        raise Exception(f"Rule '{rule_name}' does not exist in the default pipeline. \
            The existing rules can be listed with the command:\nsnakemake --list")


def get_merge_rule_name(rule_name):
    return "merge_" + rule_name


def get_var_path_map(available_vars, pipeline_dataset_config):
    var_path_map = {}
    for (var, value) in available_vars.items():
        steps = value.split(":")
        path = deepcopy(pipeline_dataset_config)
        for step in steps:
            path = path[step]
        var_path_map[var] = path

    return var_path_map
