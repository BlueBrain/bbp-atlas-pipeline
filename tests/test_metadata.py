import os
import logging
from pathlib import Path

from kgforge.core import KnowledgeGraphForge

logging.basicConfig(level=logging.INFO)
L = logging.getLogger(__name__)

forge_config = "forge-config.yml" 
nexus_env = "https://staging.nise.bbp.epfl.ch/nexus/v1"
nexus_org = "bbp"
nexus_proj = "atlas"
nexus_token = os.environ["NEXUS_STAGING_TOKEN"]

prob_maps_dir = "metadata"


def test_metadata():
    prob_maps = [str(path) for path in Path(prob_maps_dir).rglob("probability_map_*.csv")]
    prob_maps_n = len(prob_maps)
    if prob_maps_n < 1:
        return

    L.info(f"Testing labels from {prob_maps_n} probability maps in {prob_maps_dir}/: {', '.join(prob_maps)}")
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

    L.info(f"All M and E type labels in {prob_maps_dir} can be resolved from {nexus_endpoint}")
