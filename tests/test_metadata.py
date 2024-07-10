import os
import logging
import json
from pathlib import Path

from voxcell import RegionMap
from kgforge.core import KnowledgeGraphForge

logging.basicConfig(level=logging.INFO)
L = logging.getLogger(__name__)

forge_config = "forge-config.yml" 
nexus_env = "https://staging.nise.bbp.epfl.ch/nexus/v1"
nexus_org = "bbp"
nexus_proj = "atlas"
nexus_token = os.environ["NEXUS_STAGING_TOKEN"]
test_folder = os.environ["TEST_FOLDER"]

metadata_dir = "metadata"


def test_metadata():
    prob_maps = [str(path) for path in Path(metadata_dir).rglob("probability_map_*.csv")]
    prob_maps_n = len(prob_maps)
    if prob_maps_n < 1:
        return

    L.info(f"Testing labels from {prob_maps_n} probability maps in {metadata_dir}/: {', '.join(prob_maps)}")
    forge = KnowledgeGraphForge(forge_config, bucket="/".join([nexus_org, nexus_proj]),
                                endpoint=nexus_env, token=nexus_token)
    nexus_endpoint = f"Nexus endpoint: '{nexus_env}"

    me_separator = "|"
    types_to_resolve = set()
    for prob_map_file in prob_maps:
        with open(prob_map_file) as prob_map:
            header = prob_map.readline().strip('\n')
            columns = header.split(",")
            me_types = [column for column in columns if me_separator in column]
            for me_type in me_types:
                types_to_resolve.update(me_type.split(me_separator))

    for type_to_resolve in types_to_resolve:
        res = forge.resolve(type_to_resolve, scope="ontology", target="CellType", strategy="EXACT_MATCH")
        assert res, f"Label '{type_to_resolve}' is not resolved from {nexus_endpoint}"

    L.info(f"All M and E type labels in {metadata_dir} can be resolved from {nexus_endpoint}")


def test_regions_to_layers_map_and_PH_map():
    forge = KnowledgeGraphForge(forge_config, bucket="/".join(["neurosciencegraph", "datamodels"]),
                                endpoint=nexus_env, token=nexus_token)

    layers_regions_map_path = os.path.join(metadata_dir, "PH_layers_regions_map.json")
    L.info(f"Testing the layer labels in the layers to regions map from {layers_regions_map_path}")
    with open(layers_regions_map_path) as layers_regions_map_file:
        layers_regions_map = json.load(layers_regions_map_file)
    for filename in layers_regions_map:
        for region, layer in layers_regions_map[filename].items():
            check_region(region)
            check_label(layer, forge, region, layers_regions_map_path)

    regions_layers_map_path = os.path.join(metadata_dir, "regions_layers_map.json")
    L.info(f"Testing the layer labels in the layers to regions map from {regions_layers_map_path}")
    with open(regions_layers_map_path) as regions_layers_map_file:
        regions_layers_map = json.load(regions_layers_map_file)
    for region in regions_layers_map:
        for layer in regions_layers_map[region]["layers"]:
            check_label(layer, forge, region, regions_layers_map_path)


def check_region(region_acronym):
    test_data = os.path.join(test_folder, "data")
    hierarchy_file = os.path.join(test_data, "hierarchy_leaves_only.json")
    region_map = RegionMap.load_json(hierarchy_file)

    id_reg = region_map.find(region_acronym, "acronym")
    if not id_reg:
        raise Exception(f"Region acronym '{region_acronym}' is not found in the hierarchy.")


forge_retrieve_cache = {}

def check_label(layer, forge, region, file_path):
    layer_id = layer["layer_ID"]
    layer_label = layer["layer_label"]
    if layer_label not in forge_retrieve_cache:
        layer_res = forge.retrieve(layer_id)
        if not layer_res:
            raise Exception(f"Resource ID {layer_id} can not be retrieved from bucket '{forge._store.bucket}'")
        forge_retrieve_cache[layer_label] = layer_res
    else:
        layer_res = forge_retrieve_cache[layer_label]

    layer_res_label = layer_res.label
    assert layer_res_label == layer_label, (f"The label '{layer_label}' of layer_ID '{layer_id}'"
        f" for region {region} in {file_path} does not correspond to the resolved label '{layer_res_label}'")
