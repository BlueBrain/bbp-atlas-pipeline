import os
import pytest
import numpy as np

from voxcell import RegionMap, VoxelData
from customize_pipeline.customize_pipeline import (merge_nrrd_files, get_region_id,
    check_rule_existence, get_var_path_map)


def test_merge_nrrd_files():
    test_folder = os.environ["TEST_FOLDER"]
    test_data = os.path.join(test_folder, "data")

    hierarchy_file = os.path.join(test_data, "hierarchy_leaves_only.json")
    annotation_file = os.path.join(test_data, "annotation_leaves_only.nrrd")
    default_output = os.path.join(test_data, "output.nrrd")
    merged_output_dir = os.path.join(test_data, "merged")
    region_volume_map = {
        315: os.path.join(test_data, "output_315"),
        549: os.path.join(test_data, "output_549"),
    }

    region_map = RegionMap.load_json(hierarchy_file)
    annotation = VoxelData.load_nrrd(annotation_file).raw
    results = merge_nrrd_files(region_map, annotation, region_volume_map,
                               default_output, merged_output_dir)

    assert len(results) == 1
    result = VoxelData.load_nrrd(results[0]).raw

    filename = os.path.basename(default_output)
    default_volume = VoxelData.load_nrrd(default_output)
    expected_volume = np.copy(default_volume.raw)
    for (region_id, volume_dir) in region_volume_map.items():
        ids_reg = region_map.find(region_id, "id", with_descendants=True)
        volume_file = os.path.join(volume_dir, filename)
        volume = VoxelData.load_nrrd(volume_file).raw
        # Get region mask
        region_mask = np.isin(annotation, list(ids_reg))
        # Supersede region {region_id} in result with values from volume
        expected_volume[region_mask] = volume[region_mask]

    assert result.shape == default_volume.shape
    assert np.array_equal(result, expected_volume)


def test_get_region_id():
    root_region = "http://api.brain-map.org/api/v2/data/Structure/997"
    region_id = get_region_id(root_region)
    assert region_id == 997


def test_check_rule_existence():
    rule_name = "test_rule_name"
    rule = None

    check_rule_existence(not rule, rule_name)
    with pytest.raises(Exception):
        check_rule_existence(rule, rule_name)


def test_get_var_path_map():
    available_vars = {
        "hierarchy": "HierarchyJson:hierarchy_ccfv3_l23split_barrelsplit",
        "annotation": "GeneratedDatasetPath:VolumetricFile:annotation_ccfv3_l23split_barrelsplit"}
    pipeline_dataset_config = {
        "HierarchyJson": {
            "hierarchy_ccfv3_l23split_barrelsplit": "hierarchy_path"},
        "GeneratedDatasetPath": {"VolumetricFile": {
            "annotation_ccfv3_l23split_barrelsplit": "annotation_path"}},
    }
    var_path_map_expected = {
        "hierarchy": "hierarchy_path",
        "annotation": "annotation_path"}

    var_path_map = get_var_path_map(available_vars, pipeline_dataset_config)
    assert var_path_map == var_path_map_expected
